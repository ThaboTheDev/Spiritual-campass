import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the last good `/api/centres` body is kept for offline use.
///
/// The list is the thing the server is protecting, so it must not land in a
/// world-readable place: `flutter_secure_storage` keeps it in the Android
/// keystore-backed `EncryptedSharedPreferences` and in the iOS keychain,
/// both app-private. (A file under the application support directory would
/// need `path_provider`, a package the project does not have.)
abstract class CentresCache {
  /// The cached JSON body, or `null` when nothing has been cached.
  Future<String?> read();

  /// Replaces the cached body.
  Future<void> write(String json);

  /// Drops the cache (log out, 401 or 402).
  Future<void> clear();
}

/// [CentresCache] on flutter_secure_storage.
class SecureCentresCache implements CentresCache {
  const SecureCentresCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'centres.cache.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      final String? raw = await _storage.read(key: _key);
      return (raw == null || raw.isEmpty) ? null : raw;
    } catch (_) {
      // An unreadable keystore entry is the same as an empty cache.
      return null;
    }
  }

  @override
  Future<void> write(String json) async {
    try {
      await _storage.write(key: _key, value: json);
    } catch (_) {
      // Failing to cache must never break the screen.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Ignore.
    }
  }
}

/// In-memory cache for tests.
class MemoryCentresCache implements CentresCache {
  MemoryCentresCache([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;

  @override
  Future<void> clear() async => value = null;
}
