import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'membership_models.dart';

/// Thrown for a non-2xx response. [code] is the server's `error` string when
/// present (`subscription_required`, `already_subscribed`, …).
class MembershipApiException implements Exception {
  const MembershipApiException(this.statusCode, {this.code, this.message});

  final int statusCode;
  final String? code;
  final String? message;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() =>
      'MembershipApiException($statusCode${code == null ? '' : ', $code'})';
}

/// Thrown when the device is offline / the host is unreachable.
class MembershipOffline implements Exception {
  const MembershipOffline();
}

/// Supabase Auth REST (no SDK), exactly as in the contract.
class SupabaseAuthClient {
  SupabaseAuthClient({
    http.Client? client,
    this.baseUrl = kSupabaseUrl,
    this.anonKey = kSupabaseAnonKey,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String anonKey;
  final Duration timeout;

  Map<String, String> get _headers => <String, String>{
        'apikey': anonKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// `POST /auth/v1/otp {"email": e, "create_user": true}`.
  Future<void> sendCode(String email) async {
    await _post('/auth/v1/otp', <String, Object>{
      'email': email,
      'create_user': true,
    });
  }

  /// `POST /auth/v1/verify {"type":"email","email": e,"token":"123456"}`.
  Future<AuthSession> verifyCode(String email, String token) async {
    final Map<String, dynamic> body = await _post('/auth/v1/verify', <String, Object>{
      'type': 'email',
      'email': email,
      'token': token,
    });
    return AuthSession.fromVerifyResponse(body, fallbackEmail: email);
  }

  /// `POST /auth/v1/token?grant_type=refresh_token {"refresh_token": r}`.
  ///
  /// Throws [MembershipApiException] with a 4xx status when the refresh token
  /// is no longer valid: the caller signs out locally.
  Future<AuthSession> refresh(AuthSession session) async {
    final Map<String, dynamic> body = await _post(
      '/auth/v1/token?grant_type=refresh_token',
      <String, Object>{'refresh_token': session.refreshToken},
    );
    return AuthSession.fromVerifyResponse(body, fallbackEmail: session.email);
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
    return decodeJsonResponse(response);
  }
}

/// The app's own API (`/api/me`, `/api/centres`, `/api/payfast/*`).
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

  Future<Map<String, dynamic>> _post(String path, String token) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(timeout);
    } catch (_) {
      throw const MembershipOffline();
    }
    return decodeJsonResponse(response);
  }
}

/// Decodes a JSON object body; throws [MembershipApiException] on non-2xx.
Map<String, dynamic> decodeJsonResponse(http.Response response) {
  Map<String, dynamic> body = <String, dynamic>{};
  if (response.body.isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      // Non-JSON body: keep it empty; the status code still tells the story.
    }
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw MembershipApiException(
      response.statusCode,
      code: body['error']?.toString(),
      message: (body['message'] ?? body['msg'] ?? body['error_description'])
          ?.toString(),
    );
  }
  return body;
}
