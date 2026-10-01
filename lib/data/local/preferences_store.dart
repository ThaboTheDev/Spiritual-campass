import 'package:shared_preferences/shared_preferences.dart';

import '../../core/geo/coordinates.dart';

/// Small typed wrapper around `SharedPreferences`.
///
/// Persisted: the manual location, the locked msamo direction, the last tab,
/// the app language, the "Simple mode" switch, the last confirmed membership
/// entitlement (for offline use) and the per-account "trial page already
/// seen" flag. Everything else is derived.
///
/// Nothing secret lives here: tokens go to `flutter_secure_storage`
/// (`session_store.dart`) and the centres list to the private cache
/// (`centres_cache.dart`).
class PreferencesStore {
  PreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _keyManualLatitude = 'manual.latitude';
  static const String _keyManualLongitude = 'manual.longitude';
  static const String _keyManualLabel = 'manual.label';
  static const String _keyManualAltitude = 'manual.altitude';
  static const String _keyManualAccuracy = 'manual.accuracy';
  static const String _keyLockedBearing = 'msamo.lockedBearing';
  static const String _keyLastTab = 'shell.lastTab';
  // Historical name, kept so an upgrade keeps the language already chosen.
  static const String _keyLanguage = 'l10n.secondaryLanguage';
  static const String _keySimpleMode = 'perf.simpleMode';
  static const String _keyEntitlement = 'membership.entitlement';
  static const String _keyTrialIntroPrefix = 'membership.trialIntro.';

  /// The saved manual location, or `null` when none has been saved.
  GeoPoint? get manualLocation {
    final double? latitude = _preferences.getDouble(_keyManualLatitude);
    final double? longitude = _preferences.getDouble(_keyManualLongitude);
    if (latitude == null || longitude == null) {
      return null;
    }
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      altitudeMetres: _preferences.getDouble(_keyManualAltitude),
      label: _preferences.getString(_keyManualLabel),
      accuracyMetres: _preferences.getDouble(_keyManualAccuracy),
      isApproximate: true,
    );
  }

  /// Persists a manually chosen location.
  Future<void> saveManualLocation(GeoPoint point) async {
    await Future.wait(<Future<void>>[
      _preferences.setDouble(_keyManualLatitude, point.latitude),
      _preferences.setDouble(_keyManualLongitude, point.longitude),
      if (point.accuracyMetres != null)
        _preferences.setDouble(_keyManualAccuracy, point.accuracyMetres!)
      else
        _preferences.remove(_keyManualAccuracy),
      if (point.altitudeMetres != null)
        _preferences.setDouble(_keyManualAltitude, point.altitudeMetres!)
      else
        _preferences.remove(_keyManualAltitude),
      _preferences.remove(_keyManualAccuracy),
      if (point.label != null && point.label!.isNotEmpty)
        _preferences.setString(_keyManualLabel, point.label!)
      else
        _preferences.remove(_keyManualLabel),
    ]);
  }

  /// Forgets the manual location so live GPS is used again.
  Future<void> clearManualLocation() async {
    await Future.wait(<Future<void>>[
      _preferences.remove(_keyManualLatitude),
      _preferences.remove(_keyManualLongitude),
      _preferences.remove(_keyManualAltitude),
      _preferences.remove(_keyManualAccuracy),
      _preferences.remove(_keyManualLabel),
    ]);
  }

  /// The locked msamo bearing in degrees, or `null` when nothing is locked.
  double? get lockedBearing => _preferences.getDouble(_keyLockedBearing);

  /// Persists the locked msamo bearing.
  Future<void> saveLockedBearing(double? bearing) async {
    if (bearing == null) {
      await _preferences.remove(_keyLockedBearing);
      return;
    }
    await _preferences.setDouble(_keyLockedBearing, bearing);
  }

  /// The tab the app was last on, so it reopens where the user left off.
  int get lastTab => _preferences.getInt(_keyLastTab) ?? 0;

  /// Persists the current tab index.
  Future<void> saveLastTab(int index) =>
      _preferences.setInt(_keyLastTab, index);

  /// Persisted app language code (`en`, `zu`, `pt`, `ny`, `bem`), or `null`
  /// when the user has never chosen (the device locale is then suggested).
  String? get languageCode => _preferences.getString(_keyLanguage);

  /// Persists the app language code.
  Future<void> saveLanguageCode(String code) =>
      _preferences.setString(_keyLanguage, code);

  /// Whether the user forced "Battery saver / Simple mode".
  bool get simpleMode => _preferences.getBool(_keySimpleMode) ?? false;

  /// Persists the Simple mode switch.
  Future<void> saveSimpleMode(bool value) =>
      _preferences.setBool(_keySimpleMode, value);

  /// The last confirmed membership entitlement as JSON, for offline use.
  String? get cachedEntitlementJson => _preferences.getString(_keyEntitlement);

  /// Persists (or clears, with `null`) the cached entitlement JSON.
  Future<void> saveCachedEntitlementJson(String? json) async {
    if (json == null) {
      await _preferences.remove(_keyEntitlement);
      return;
    }
    await _preferences.setString(_keyEntitlement, json);
  }

  /// Whether this account has already been shown the trial page.
  ///
  /// Keyed by the Supabase user id so the page appears once per account, not
  /// once per device. An empty id (a session stored before the id was kept)
  /// counts as "not seen".
  bool trialIntroSeen(String userId) {
    if (userId.isEmpty) {
      return false;
    }
    return _preferences.getBool('$_keyTrialIntroPrefix$userId') ?? false;
  }

  /// Remembers that this account has seen the trial page.
  Future<void> markTrialIntroSeen(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await _preferences.setBool('$_keyTrialIntroPrefix$userId', true);
  }

  /// Forgets the flag for one account (so the trial page shows again).
  Future<void> clearTrialIntroSeen(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await _preferences.remove('$_keyTrialIntroPrefix$userId');
  }
}
