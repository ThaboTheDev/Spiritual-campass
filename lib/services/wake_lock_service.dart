import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while the user is aligning with the compass.
///
/// Behind an interface so the controller can be tested without the plugin,
/// and so that a plugin failure (old Android, missing activity) never reaches
/// the compass: every call swallows and logs its error.
abstract class WakeLockService {
  /// Requests the screen to stay awake.
  Future<void> acquire();

  /// Lets the screen sleep again.
  Future<void> release();
}

/// wakelock_plus implementation.
class WakelockPlusService implements WakeLockService {
  const WakelockPlusService();

  @override
  Future<void> acquire() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      debugPrint('Wake lock could not be acquired: $error');
    }
  }

  @override
  Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (error) {
      debugPrint('Wake lock could not be released: $error');
    }
  }
}

/// No-op implementation for tests and unsupported platforms.
class NoopWakeLockService implements WakeLockService {
  const NoopWakeLockService();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}
