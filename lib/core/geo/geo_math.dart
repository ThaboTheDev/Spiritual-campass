import 'dart:math' as math;

import 'coordinates.dart';

/// Pure great-circle geometry used by the compass, the msamo screen and the
/// centres list. No Flutter or platform imports — this is unit tested directly.
abstract final class GeoMath {
  /// Mean radius of the WGS84 sphere in kilometres (IUGG mean radius).
  static const double earthRadiusKm = 6371.0088;

  /// Initial great-circle bearing (forward azimuth) from one point to another,
  /// normalised to 0 .. 360 degrees, where 0 is true north.
  ///
  /// Uses the standard spherical formula:
  /// `θ = atan2(sin Δλ · cos φ2, cos φ1 · sin φ2 − sin φ1 · cos φ2 · cos Δλ)`
  static double initialBearingDeg({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double phi1 = Angles.toRadians(lat1);
    final double phi2 = Angles.toRadians(lat2);
    final double deltaLambda = Angles.toRadians(lon2 - lon1);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final double theta = math.atan2(y, x);
    return Angles.normalize360(Angles.toDegrees(theta));
  }

  /// Convenience overload taking [GeoPoint]s.
  static double bearingBetween(GeoPoint from, GeoPoint to) =>
      initialBearingDeg(
        lat1: from.latitude,
        lon1: from.longitude,
        lat2: to.latitude,
        lon2: to.longitude,
      );

  /// Great-circle (haversine) distance in kilometres.
  static double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double phi1 = Angles.toRadians(lat1);
    final double phi2 = Angles.toRadians(lat2);
    final double dPhi = Angles.toRadians(lat2 - lat1);
    final double dLambda = Angles.toRadians(lon2 - lon1);

    final double a = math.pow(math.sin(dPhi / 2), 2).toDouble() +
        math.cos(phi1) *
            math.cos(phi2) *
            math.pow(math.sin(dLambda / 2), 2).toDouble();

    final double c =
        2 * math.atan2(math.sqrt(a), math.sqrt((1 - a).clamp(0.0, 1.0)));
    return earthRadiusKm * c;
  }

  /// Convenience overload taking [GeoPoint]s.
  static double distanceBetweenKm(GeoPoint from, GeoPoint to) => distanceKm(
        lat1: from.latitude,
        lon1: from.longitude,
        lat2: to.latitude,
        lon2: to.longitude,
      );

  /// True bearing and distance to Ekuphumuleni in one call.
  static TargetReading readingTo(GeoPoint from, GeoPoint target) {
    return TargetReading(
      bearingDeg: bearingBetween(from, target),
      distanceKm: distanceBetweenKm(from, target),
    );
  }

  /// Converts a true bearing to a magnetic bearing for a hand compass:
  /// `magnetic = true − declination`.
  static double trueToMagnetic(double trueBearingDeg, double declinationDeg) =>
      Angles.normalize360(trueBearingDeg - declinationDeg);

  /// Converts a magnetic (compass) bearing to a true bearing:
  /// `true = magnetic + declination`.
  static double magneticToTrue(double magneticBearingDeg, double declinationDeg) =>
      Angles.normalize360(magneticBearingDeg + declinationDeg);
}

/// Bearing and distance to a target, as shown on the compass screen.
class TargetReading {
  const TargetReading({required this.bearingDeg, required this.distanceKm});

  /// True bearing to the target, 0 .. 360.
  final double bearingDeg;

  /// Great-circle distance to the target in kilometres.
  final double distanceKm;
}
