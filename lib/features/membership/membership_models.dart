import 'dart:developer' as developer;

/// A Supabase session as stored locally (see membership-api-contract.md).
///
/// Never logged and never written anywhere but the platform keystore /
/// keychain (see `session_store.dart`).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.email,
    this.userId = '',
  });

  /// Parses the body of `POST /auth/v1/token` (password or refresh grant).
  factory AuthSession.fromTokenResponse(
    Map<String, dynamic> json, {
    required String fallbackEmail,
    String fallbackUserId = '',
    DateTime? now,
  }) {
    final Object? user = json['user'];
    final String email = (user is Map<String, dynamic> && user['email'] is String)
        ? user['email'] as String
        : fallbackEmail;
    final String userId = (user is Map<String, dynamic> && user['id'] is String)
        ? user['id'] as String
        : fallbackUserId;
    final int expiresIn = _asInt(json['expires_in']) ?? 3600;
    final DateTime at = (now ?? DateTime.now()).toUtc();
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: at.add(Duration(seconds: expiresIn)),
      email: email,
      userId: userId,
    );
  }

  factory AuthSession.fromStoredJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          _asInt(json['expires_at']) ?? 0,
          isUtc: true,
        ),
        email: json['email'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
      );

  final String accessToken;
  final String refreshToken;

  /// `now + expires_in * 1000`, stored as epoch milliseconds.
  final DateTime expiresAt;
  final String email;

  /// Supabase user id. Used only as the key of the per-account
  /// "trial page already seen" flag.
  final String userId;

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  /// Whether the access token expires within [margin].
  bool isExpiring({DateTime? now, Duration margin = const Duration(minutes: 1)}) =>
      (now ?? DateTime.now()).toUtc().add(margin).isAfter(expiresAt);

  Map<String, dynamic> toStoredJson() => <String, dynamic>{
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'email': email,
        'user_id': userId,
      };

  /// Never print the tokens.
  @override
  String toString() => 'AuthSession($email)';
}

/// The outcome of `POST /auth/v1/signup`.
///
/// With e-mail confirmation ON Supabase answers 200 with a user but **no**
/// session: [session] is then `null` and [needsConfirmation] is `true`.
class SignUpResult {
  const SignUpResult({required this.email, this.session});

  factory SignUpResult.fromJson(
    Map<String, dynamic> json, {
    required String email,
    DateTime? now,
  }) {
    final String? token = json['access_token'] as String?;
    if (token == null || token.isEmpty) {
      return SignUpResult(email: email);
    }
    return SignUpResult(
      email: email,
      session: AuthSession.fromTokenResponse(
        json,
        fallbackEmail: email,
        now: now,
      ),
    );
  }

  final String email;

  /// The session, when the project has e-mail confirmation switched off.
  final AuthSession? session;

  /// Whether the member must open the confirmation link before logging in.
  bool get needsConfirmation => session == null;
}

/// Entitlement states the server may report. Unknown values map to [other]
/// and are shown as text, never crash.
enum EntitlementState { trial, active, grace, expired, cancelled, other }

/// The body of `GET /api/me`, read defensively.
class Entitlement {
  const Entitlement({
    required this.email,
    required this.status,
    required this.state,
    required this.access,
    required this.canCancel,
    required this.priceMinor,
    required this.currency,
    required this.trialDays,
    required this.endsAt,
    required this.fetchedAt,
    this.isAdmin = false,
    this.mustChangePassword = false,
    this.rawState,
  });

  /// Parses `/api/me`. Unknown fields are logged, missing ones defaulted.
  factory Entitlement.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    for (final String key in json.keys) {
      if (!_knownKeys.contains(key)) {
        developer.log('Unknown /api/me field: $key', name: 'membership');
      }
    }
    final String rawState =
        (json['state'] ?? json['status'] ?? '').toString().toLowerCase();
    final EntitlementState state = switch (rawState) {
      'trial' || 'trialing' => EntitlementState.trial,
      'active' => EntitlementState.active,
      'grace' || 'past_due' => EntitlementState.grace,
      'expired' => EntitlementState.expired,
      'cancelled' || 'canceled' => EntitlementState.cancelled,
      _ => EntitlementState.other,
    };
    final Object? accessRaw = json['access'];
    final bool access = accessRaw is bool
        ? accessRaw
        : (state == EntitlementState.trial ||
            state == EntitlementState.active ||
            state == EntitlementState.grace);
    return Entitlement(
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? rawState,
      state: state,
      rawState: rawState,
      access: access,
      canCancel: json['can_cancel'] == true,
      // Both flags are read defensively: anything that is not literally
      // `true` counts as `false`, and a missing field is simply `false`.
      isAdmin: json['is_admin'] == true,
      mustChangePassword: json['must_change_password'] == true,
      priceMinor: _asNum(json['price']),
      currency: json['currency']?.toString() ?? 'ZAR',
      trialDays: _asInt(json['trial_days']) ?? 7,
      endsAt: _firstDate(json, const <String>[
        'ends_at',
        'paid_through',
        'access_until',
        'current_period_end',
        'trial_ends_at',
        'grace_until',
        'expires_at',
      ]),
      fetchedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  factory Entitlement.fromCacheJson(Map<String, dynamic> json) {
    final Entitlement base = Entitlement.fromJson(
      Map<String, dynamic>.from(json['me'] as Map),
      now: DateTime.fromMillisecondsSinceEpoch(
        _asInt(json['fetched_at']) ?? 0,
        isUtc: true,
      ),
    );
    return base;
  }

  static const Set<String> _knownKeys = <String>{
    'email', 'status', 'state', 'access', 'can_cancel', 'price', 'currency',
    'trial_days', 'ends_at', 'paid_through', 'access_until',
    'current_period_end', 'trial_ends_at', 'grace_until', 'expires_at',
    'cancelled_at', 'ok', 'is_admin', 'must_change_password',
  };

  final String email;
  final String status;
  final EntitlementState state;
  final String? rawState;
  final bool access;
  final bool canCancel;

  /// Whether this account may open the admin area. The server enforces it as
  /// well (`403 admin_required`); this only hides the entry.
  final bool isAdmin;

  /// Set by the server after an administrator used "Auto-generate password".
  /// While it is `true` every other `/api/*` call answers
  /// `403 {"error":"password_change_required"}`.
  final bool mustChangePassword;

  /// Price as sent by the server (usually rands, e.g. 100).
  final num? priceMinor;
  final String currency;
  final int trialDays;

  /// Whichever end date the server sent for the current state.
  final DateTime? endsAt;

  /// When this body was received (for the offline cache).
  final DateTime fetchedAt;

  /// "R100" style label; falls back to "R100" when the server omits it.
  String get priceLabel {
    final num price = priceMinor ?? 100;
    final String amount =
        price == price.roundToDouble() ? price.toInt().toString() : price.toString();
    return currency == 'ZAR' ? 'R$amount' : '$amount $currency';
  }

  /// Whole days until [endsAt], never negative.
  int daysLeft({DateTime? now}) {
    final DateTime? end = endsAt;
    if (end == null) {
      return 0;
    }
    final int days = end.difference((now ?? DateTime.now()).toUtc()).inHours ~/ 24;
    return days < 0 ? 0 : days;
  }

  /// Whether a *cached* copy may still grant access: only until the paid-
  /// through date (or, during a trial, the trial end date) the server last
  /// confirmed. Without an end date the cache is trusted for at most 24 h.
  bool cachedAccessValid({DateTime? now}) {
    if (!access) {
      return false;
    }
    final DateTime at = (now ?? DateTime.now()).toUtc();
    final DateTime? end = endsAt;
    if (end != null) {
      return at.isBefore(end);
    }
    return at.difference(fetchedAt) < const Duration(hours: 24);
  }

  Map<String, dynamic> toCacheJson(Map<String, dynamic> original) =>
      <String, dynamic>{
        'me': original,
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
      };
}

/// One row of `GET /api/admin/users`.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.email,
    required this.status,
    required this.state,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        userId: json['user_id']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        createdAt: _parseDate(json['created_at']),
      );

  final String userId;
  final String email;
  final String status;
  final String state;
  final DateTime? createdAt;

  /// "trial" / "active" / … as one short line for the list.
  String get stateLabel => state.isNotEmpty ? state : status;

  @override
  bool operator ==(Object other) =>
      other is AdminUser && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}

/// `POST /api/admin/users/reset-password` → the generated password.
///
/// Deliberately *not* persisted anywhere: it lives in widget state for as
/// long as the dialog is open and is never logged.
class TemporaryPassword {
  const TemporaryPassword({required this.email, required this.password});

  factory TemporaryPassword.fromJson(Map<String, dynamic> json) =>
      TemporaryPassword(
        email: json['email']?.toString() ?? '',
        password: json['temporary_password']?.toString() ?? '',
      );

  final String email;
  final String password;

  /// Never print the password.
  @override
  String toString() => 'TemporaryPassword($email)';
}

/// `POST /api/admin/users/delete` → whether PayFast was also cancelled.
class DeleteUserResult {
  const DeleteUserResult({required this.ok, required this.subscriptionCancelled});

  factory DeleteUserResult.fromJson(Map<String, dynamic> json) =>
      DeleteUserResult(
        ok: json['ok'] == true,
        subscriptionCancelled: json['subscription_cancelled'] == true,
      );

  final bool ok;
  final bool subscriptionCancelled;
}

/// A signed PayFast form: open [actionUrl] with [fields] in the external
/// browser.
class PayfastCheckout {
  const PayfastCheckout({required this.actionUrl, required this.fields});

  factory PayfastCheckout.fromJson(Map<String, dynamic> json) {
    final String action = (json['action'] ??
            json['action_url'] ??
            json['url'] ??
            json['actionUrl'] ??
            '')
        .toString();
    final Object? raw = json['fields'] ?? json['data'];
    final Map<String, String> fields = <String, String>{};
    if (raw is Map) {
      raw.forEach((Object? k, Object? v) {
        if (k != null && v != null) {
          fields[k.toString()] = v.toString();
        }
      });
    }
    return PayfastCheckout(actionUrl: action, fields: fields);
  }

  final String actionUrl;
  final Map<String, String> fields;

  /// PayFast accepts the signed fields as a GET query as well, which is the
  /// only way to open a form in an external browser from Flutter.
  Uri get launchUri => Uri.parse(actionUrl).replace(
        queryParameters: <String, String>{
          ...Uri.parse(actionUrl).queryParameters,
          ...fields,
        },
      );
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  if (value is num) {
    final int v = value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(
      v > 100000000000 ? v : v * 1000,
      isUtc: true,
    );
  }
  return null;
}

DateTime? _firstDate(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final DateTime? parsed = _parseDate(json[key]);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
