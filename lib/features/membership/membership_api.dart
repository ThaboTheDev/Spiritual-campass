import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'membership_models.dart';

/// Thrown for a non-2xx response from *our* API. [code] is the server's
/// `error` string when present (`subscription_required`,
/// `password_change_required`, `admin_required`, …).
class MembershipApiException implements Exception {
  const MembershipApiException(
    this.statusCode, {
    this.code,
    this.message,
    this.fields = const <String>[],
  });

  final int statusCode;
  final String? code;
  final String? message;

  /// Field names the server flagged, e.g. `400 invalid_centre {fields:[…]}`.
  final List<String> fields;

  /// 401: the session is no longer valid → sign out locally.
  bool get isUnauthorised => statusCode == 401;

  /// 403 `password_change_required`: go to the change-password screen. This
  /// is **never** a reason to sign out.
  bool get isPasswordChangeRequired =>
      statusCode == 403 && code == 'password_change_required';

  /// 403 `admin_required`: this account is not an administrator.
  bool get isAdminRequired => statusCode == 403 && code == 'admin_required';

  /// 402 `subscription_required`: the paywall decides what happens next.
  bool get isSubscriptionRequired => statusCode == 402;

  @override
  String toString() =>
      'MembershipApiException($statusCode${code == null ? '' : ', $code'})';
}

/// Thrown when the device is offline / the host is unreachable.
class MembershipOffline implements Exception {
  const MembershipOffline();
}

/// Why an authentication call failed, in terms the UI can explain.
enum AuthErrorKind {
  /// Wrong e-mail / password combination.
  invalidCredentials,

  /// The account exists but the confirmation link has not been opened.
  emailNotConfirmed,

  /// Sign-up for an address that already has an account.
  alreadyRegistered,

  /// Supabase refused the password (too short / breached).
  weakPassword,

  /// Supabase is rate-limiting the e-mails or the attempts.
  rateLimited,

  /// The device could not reach Supabase.
  offline,

  /// Supabase answered 5xx.
  server,

  /// Anything else.
  unknown,
}

/// A failed Supabase Auth call, already mapped to [AuthErrorKind].
class AuthException implements Exception {
  const AuthException(this.kind, {this.statusCode});

  final AuthErrorKind kind;
  final int? statusCode;

  @override
  String toString() => 'AuthException(${kind.name}, $statusCode)';
}

/// Maps a Supabase Auth error body onto an [AuthErrorKind].
///
/// Pure and exported so the mapping can be unit tested without HTTP. GoTrue
/// has changed its error shape a few times, so both the modern
/// `error_code` / `code` fields and the older `error` / `msg` /
/// `error_description` texts are inspected.
AuthErrorKind mapSupabaseAuthError(int statusCode, Map<String, dynamic> body) {
  final String code = (body['error_code'] ?? body['code'] ?? body['error'] ?? '')
      .toString()
      .toLowerCase();
  final String message =
      (body['msg'] ?? body['message'] ?? body['error_description'] ?? '')
          .toString()
          .toLowerCase();

  bool says(String needle) => code.contains(needle) || message.contains(needle);

  // "Email not confirmed" arrives as a 400 invalid_grant too, so it has to be
  // checked before the credentials case.
  if (code == 'email_not_confirmed' || message.contains('not confirmed')) {
    return AuthErrorKind.emailNotConfirmed;
  }
  if (code == 'invalid_credentials' ||
      code == 'invalid_grant' ||
      message.contains('invalid login credentials') ||
      message.contains('invalid email or password')) {
    return AuthErrorKind.invalidCredentials;
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      says('already registered') ||
      says('already been registered')) {
    return AuthErrorKind.alreadyRegistered;
  }
  if (code == 'weak_password' ||
      says('weak password') ||
      message.contains('password should be') ||
      message.contains('password is too short')) {
    return AuthErrorKind.weakPassword;
  }
  if (statusCode == 429 || says('rate limit') || says('rate_limit')) {
    return AuthErrorKind.rateLimited;
  }
  if (statusCode >= 500) {
    return AuthErrorKind.server;
  }
  return AuthErrorKind.unknown;
}

/// Supabase Auth REST (no SDK), exactly as in the contract.
///
/// Passwords are only ever put in a request body; nothing in this class logs
/// a password, a token or a response body.
class SupabaseAuthClient {
  SupabaseAuthClient({
    http.Client? client,
    this.baseUrl = kSupabaseUrl,
    this.anonKey = kSupabaseAnonKey,
    this.siteUrl = kSiteUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String anonKey;

  /// Where the recovery e-mail should send the member (`{siteUrl}/reset`).
  final String siteUrl;
  final Duration timeout;

  Map<String, String> get _headers => <String, String>{
        'apikey': anonKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// `POST /auth/v1/signup {email, password}`.
  ///
  /// With e-mail confirmation ON the answer carries no session: the caller
  /// shows "check your e-mail".
  Future<SignUpResult> signUp(String email, String password) async {
    final Map<String, dynamic> body = await _post('/auth/v1/signup', <String, Object>{
      'email': email,
      'password': password,
    });
    return SignUpResult.fromJson(body, email: email);
  }

  /// `POST /auth/v1/resend {type:"signup", email}`.
  Future<void> resendConfirmation(String email) async {
    await _post('/auth/v1/resend', <String, Object>{
      'type': 'signup',
      'email': email,
    });
  }

  /// `POST /auth/v1/token?grant_type=password {email, password}`.
  Future<AuthSession> signInWithPassword(String email, String password) async {
    final Map<String, dynamic> body = await _post(
      '/auth/v1/token?grant_type=password',
      <String, Object>{'email': email, 'password': password},
    );
    return AuthSession.fromTokenResponse(body, fallbackEmail: email);
  }

  /// `POST /auth/v1/recover?redirect_to={siteUrl}/reset {email}`.
  ///
  /// The e-mail link opens the web reset page in the phone's browser, so the
  /// app needs no deep links.
  Future<void> recover(String email) async {
    final String redirect = Uri.encodeComponent('$siteUrl/reset');
    await _post(
      '/auth/v1/recover?redirect_to=$redirect',
      <String, Object>{'email': email},
    );
  }

  /// `POST /auth/v1/token?grant_type=refresh_token {refresh_token}`.
  ///
  /// Throws [MembershipApiException] with a 4xx status when the refresh token
  /// is no longer valid: the caller signs out locally. A network failure
  /// throws [MembershipOffline] and must never sign anyone out.
  Future<AuthSession> refresh(AuthSession session) async {
    final Map<String, dynamic> body;
    try {
      body = await _post(
        '/auth/v1/token?grant_type=refresh_token',
        <String, Object>{'refresh_token': session.refreshToken},
      );
    } on AuthException catch (error) {
      // The refresh grant is the one place the caller wants the status code
      // rather than a friendly message.
      throw MembershipApiException(error.statusCode ?? 400);
    }
    return AuthSession.fromTokenResponse(
      body,
      fallbackEmail: session.email,
      fallbackUserId: session.userId,
    );
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object> body) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } catch (_) {
      throw const MembershipOffline();
    }
    final Map<String, dynamic> decoded = decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        mapSupabaseAuthError(response.statusCode, decoded),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}

/// The app's own API (`/api/me`, `/api/centres`, `/api/account/password`,
/// `/api/payfast/*`, `/api/admin/*`).
class MembershipApiClient {
  MembershipApiClient({
    http.Client? client,
    this.baseUrl = kMembershipApiBaseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Map<String, String> _headers(String accessToken) => <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// `GET /api/me` → the raw body (kept for the offline cache) and its parse.
  Future<(Entitlement, Map<String, dynamic>)> me(String accessToken) async {
    final Map<String, dynamic> body = await _get('/api/me', accessToken);
    return (Entitlement.fromJson(body), body);
  }

  /// `GET /api/centres`. 402 `subscription_required` surfaces as a
  /// [MembershipApiException] with that code.
  Future<Map<String, dynamic>> centres(String accessToken) =>
      _get('/api/centres', accessToken);

  /// `POST /api/account/password {new_password}` → 200 `{ok:true}`.
  ///
  /// 400 `weak_password` is thrown. The caller logs in again afterwards with
  /// the new password to get a fresh session.
  Future<void> changePassword(String accessToken, String newPassword) async {
    await _post(
      '/api/account/password',
      accessToken,
      body: <String, Object>{'new_password': newPassword},
    );
  }

  /// `POST /api/payfast/checkout`. 409 `already_subscribed` is thrown.
  Future<PayfastCheckout> checkout(String accessToken) async {
    final Map<String, dynamic> body =
        await _post('/api/payfast/checkout', accessToken);
    return PayfastCheckout.fromJson(body);
  }

  /// `POST /api/payfast/cancel`. 400 `no_active_subscription` and 502
  /// `payfast_cancel_failed` are thrown.
  Future<(Entitlement, Map<String, dynamic>)> cancel(String accessToken) async {
    final Map<String, dynamic> body =
        await _post('/api/payfast/cancel', accessToken);
    return (Entitlement.fromJson(body), body);
  }

  // ------------------------------------------------------------------ admin

  /// `GET /api/admin/users?q=<text>`. 403 `admin_required` is thrown.
  Future<List<AdminUser>> adminUsers(String accessToken, String query) async {
    final Map<String, dynamic> body = await _get(
      '/api/admin/users?q=${Uri.encodeQueryComponent(query)}',
      accessToken,
    );
    final Object? users = body['users'];
    if (users is! List<Object?>) {
      return const <AdminUser>[];
    }
    return <AdminUser>[
      for (final Object? entry in users)
        if (entry is Map<String, dynamic>) AdminUser.fromJson(entry),
    ];
  }

  /// `POST /api/admin/centres` → 201 `{centre}`. 400 `invalid_centre`
  /// (with `fields`) and 409 `duplicate_centre` are thrown.
  Future<Map<String, dynamic>> adminAddCentre(
    String accessToken, {
    required String region,
    required String name,
    required String address,
    required String phone,
    required double lat,
    required double lng,
  }) async {
    final Map<String, dynamic> body = await _post(
      '/api/admin/centres',
      accessToken,
      body: <String, Object>{
        'region': region,
        'name': name,
        'address': address,
        'phone': phone,
        'lat': lat,
        'lng': lng,
      },
    );
    final Object? centre = body['centre'];
    return centre is Map<String, dynamic> ? centre : body;
  }

  /// `POST /api/admin/users/reset-password {user_id}` → the generated
  /// password. The value is handed straight back to the caller and never
  /// stored or logged here.
  Future<TemporaryPassword> adminResetPassword(
    String accessToken,
    String userId,
  ) async {
    final Map<String, dynamic> body = await _post(
      '/api/admin/users/reset-password',
      accessToken,
      body: <String, Object>{'user_id': userId},
    );
    return TemporaryPassword.fromJson(body);
  }

  /// `POST /api/admin/users/delete {user_id}`. 409 `cannot_delete_self` and
  /// 502 `payfast_cancel_failed` are thrown.
  Future<DeleteUserResult> adminDeleteUser(
    String accessToken,
    String userId,
  ) async {
    final Map<String, dynamic> body = await _post(
      '/api/admin/users/delete',
      accessToken,
      body: <String, Object>{'user_id': userId},
    );
    return DeleteUserResult.fromJson(body);
  }

  // -------------------------------------------------------------- internals

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(timeout);
    } catch (_) {
      throw const MembershipOffline();
    }
    return decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    String token, {
    Map<String, Object>? body,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);
    } catch (_) {
      throw const MembershipOffline();
    }
    return decodeJsonResponse(response);
  }
}

/// Decodes a JSON object body, ignoring anything that is not an object.
Map<String, dynamic> decodeJsonBody(http.Response response) {
  if (response.body.isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Non-JSON body: the status code still tells the story.
  }
  return <String, dynamic>{};
}

/// Decodes a JSON object body; throws [MembershipApiException] on non-2xx.
Map<String, dynamic> decodeJsonResponse(http.Response response) {
  final Map<String, dynamic> body = decodeJsonBody(response);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final Object? rawFields = body['fields'];
    throw MembershipApiException(
      response.statusCode,
      code: body['error']?.toString(),
      message: (body['message'] ?? body['msg'] ?? body['error_description'])
          ?.toString(),
      fields: rawFields is List<Object?>
          ? <String>[
              for (final Object? field in rawFields)
                if (field != null) field.toString(),
            ]
          : const <String>[],
    );
  }
  return body;
}
