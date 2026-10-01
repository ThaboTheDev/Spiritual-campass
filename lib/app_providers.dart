import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/net/connectivity_probe.dart';
import 'core/perf/performance_profile.dart';
import 'core/wmm/wmm_context.dart';
import 'data/local/centres_cache.dart';
import 'data/local/preferences_store.dart';
import 'data/repositories/location_repository.dart';
import 'services/compass_service.dart';
import 'services/motion_sensors.dart';
import 'services/wake_lock_service.dart';

/// The `SharedPreferences` instance created in `main()`.
///
/// Overridden at startup with the value already loaded, so no provider has to
/// await it.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (ref) => throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in main().',
      ),
    );

/// Typed access to the few things we persist.
final Provider<PreferencesStore> preferencesStoreProvider =
    Provider<PreferencesStore>(
      (ref) => PreferencesStore(ref.watch(sharedPreferencesProvider)),
    );

/// The app-private cache of the last good `/api/centres` body.
///
/// Declared here (not with the other centre providers) so signing out can
/// empty it without the membership gate having to know about the Centres
/// feature.
final Provider<CentresCache> centresCacheProvider = Provider<CentresCache>(
  (ref) => const SecureCentresCache(),
);

/// The platform location stack (geolocator).
final Provider<LocationRepository> locationRepositoryProvider =
    Provider<LocationRepository>((ref) => GeolocatorLocationRepository());

/// OS-fused orientation with explicit north reference and diagnostics.
final Provider<CompassService> compassServiceProvider =
    Provider<CompassService>(
      (ref) => NativeCompassService(
        samplingPeriod: ref.watch(perfSettingsProvider).sensorInterval,
      ),
    );

/// Raw accelerometer / magnetometer / gyroscope (sensors_plus): rungs 2 – 3
/// of the ladder and the level bubble.
final Provider<MotionSensors> motionSensorsProvider = Provider<MotionSensors>(
  (ref) => const SensorsPlusMotionSensors(),
);

/// Screen wake lock while the compass runs.
final Provider<WakeLockService> wakeLockServiceProvider =
    Provider<WakeLockService>((ref) => const WakelockPlusService());

/// What `device_info_plus` found out about the hardware. Overridden in
/// `main()` with the detected value; defaults to "unknown" (normal profile).
final Provider<DeviceClass> deviceClassProvider = Provider<DeviceClass>(
  (ref) => DeviceClass.unknown,
);

/// The persisted "Battery saver / Simple mode" switch.
class SimpleModeController extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesStoreProvider).simpleMode;

  /// Turns Simple mode on or off and persists it.
  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesStoreProvider).saveSimpleMode(value);
  }
}

/// Whether the user forced the low profile.
final NotifierProvider<SimpleModeController, bool> simpleModeProvider =
    NotifierProvider<SimpleModeController, bool>(SimpleModeController.new);

/// The effective performance profile: hardware detection, or low when the
/// user forced Simple mode.
final Provider<PerformanceProfile> performanceProfileProvider =
    Provider<PerformanceProfile>((ref) {
      return resolveProfile(
        device: ref.watch(deviceClassProvider),
        simpleModeForced: ref.watch(simpleModeProvider),
      );
    });

/// Concrete rendering / sensor knobs for the effective profile.
final Provider<PerfSettings> perfSettingsProvider = Provider<PerfSettings>(
  (ref) => PerfSettings.of(ref.watch(performanceProfileProvider)),
);

/// A small internet reachability probe, used by the Centres map.
final Provider<ConnectivityProbe> connectivityProbeProvider =
    Provider<ConnectivityProbe>((ref) {
      final ConnectivityProbe probe = ConnectivityProbe();
      ref.onDispose(probe.dispose);
      return probe;
    });

/// A clock that ticks every 10 minutes.
///
/// Declination only needs to be recomputed when the position or the date moves,
/// so a coarse clock keeps the WMM out of the per-frame path while still
/// picking up the slow annual drift.
final StreamProvider<DateTime> coarseClockProvider = StreamProvider<DateTime>((
  ref,
) async* {
  yield DateTime.now().toUtc();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 10),
    (_) => DateTime.now().toUtc(),
  );
});

/// Injectable wall clock for acquisition freshness, calibration and model age.
final Provider<DateTime Function()> compassClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

final Provider<WmmContextCache> wmmContextCacheProvider =
    Provider<WmmContextCache>((ref) => WmmContextCache());

/// A single shared presentation clock for location freshness and settling.
final StreamProvider<DateTime> navigationClockProvider =
    StreamProvider<DateTime>((ref) async* {
      final DateTime Function() now = ref.watch(compassClockProvider);
      yield now();
      yield* Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => now(),
      );
    });
