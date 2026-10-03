import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../core/sun/sun_position.dart';
import '../../core/wmm/wmm.dart';
import '../location/location_controller.dart';
import 'compass_controller.dart';

/// Declination at the user's position, altitude and date, in degrees.
///
/// Positive is east, negative is west — across Southern Africa it is negative,
/// typically between about -19° and -28°. Recomputed when the position changes
/// or every 10 minutes ([coarseClockProvider]), never per frame.
final Provider<double?> declinationProvider = Provider<double?>((ref) {
  final GeoPoint? point = ref.watch(effectiveLocationProvider);
  ref.watch(coarseClockProvider); // refresh as the date creeps forward
  if (point == null) {
    return null;
  }
  return Wmm2025.declinationDeg(
    latitudeDeg: point.latitude,
    longitudeDeg: point.longitude,
    altitudeKm: point.altitudeKm,
    when: DateTime.now(),
  );
});

/// True bearing and distance to Ekuphumuleni from the user's position.
final Provider<TargetReading?> targetReadingProvider =
    Provider<TargetReading?>((ref) {
  final GeoPoint? point = ref.watch(effectiveLocationProvider);
  if (point == null) {
    return null;
  }
  return GeoMath.readingTo(point, Ekuphumuleni.point);
});

/// Magnetic bearing to Ekuphumuleni, for a hand compass that has not been
/// corrected: `magnetic = true − declination`.
final Provider<double?> magneticBearingProvider = Provider<double?>((ref) {
  final TargetReading? reading = ref.watch(targetReadingProvider);
  final double? declination = ref.watch(declinationProvider);
  if (reading == null || declination == null) {
    return null;
  }
  return GeoMath.trueToMagnetic(reading.bearingDeg, declination);
});

/// The sun position, refreshed once a second.
///
/// `null` until a location is known, because the sun's position depends on the
/// observer as much as on the time.
final StreamProvider<SunPosition?> sunPositionProvider =
    StreamProvider<SunPosition?>((ref) async* {
  final GeoPoint? point = ref.watch(effectiveLocationProvider);
  if (point == null) {
    yield null;
    return;
  }
  yield _sunAt(point);
  yield* Stream<SunPosition?>.periodic(
    const Duration(seconds: 1),
    (_) => _sunAt(ref.read(effectiveLocationProvider)),
  );
});

SunPosition? _sunAt(GeoPoint? point) {
  if (point == null) {
    return null;
  }
  return SunCalculator.calculate(
    at: DateTime.now().toUtc(),
    latitudeDeg: point.latitude,
    longitudeDeg: point.longitude,
  );
}

/// The heading the compass dial should rotate to.
///
/// This is the true heading when we have one (magnetic heading + declination)
/// and falls back to the raw magnetic heading when location is unavailable, so
/// the dial still turns.
final Provider<double?> dialHeadingProvider = Provider<double?>((ref) {
  final CompassState compass = ref.watch(compassControllerProvider);
  return compass.trueHeadingDeg ?? compass.magneticHeadingDeg;
});
