import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'membership_models.dart';

/// Keeps the Supabase session in the platform keystore / keychain.
abstract class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// [SessionStore] on flutter_secure_storage.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'membership.session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    try {
      final String? raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final AuthSession session = AuthSession.fromStoredJson(decoded);
      return session.isValid ? session : null;
    } catch (_) {
      // A corrupt or unreadable keystore entry is the same as "signed out".
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toStoredJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// In-memory store for tests.
class MemorySessionStore implements SessionStore {
  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}
