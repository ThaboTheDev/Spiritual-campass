import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/net/connectivity_probe.dart';
import 'data/local/preferences_store.dart';
import 'data/repositories/location_repository.dart';
import 'services/compass_service.dart';

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

/// The platform location stack (geolocator).
final Provider<LocationRepository> locationRepositoryProvider =
    Provider<LocationRepository>(
  (ref) => GeolocatorLocationRepository(),
);

/// The device compass (flutter_compass).
final Provider<CompassService> compassServiceProvider =
    Provider<CompassService>((ref) => FlutterCompassService());

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
final StreamProvider<DateTime> coarseClockProvider =
    StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 10),
    (_) => DateTime.now().toUtc(),
  );
});
