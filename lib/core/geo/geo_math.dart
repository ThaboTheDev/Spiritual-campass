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
    final double x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final double theta = math.atan2(y, x);
    return Angles.normalize360(Angles.toDegrees(theta));
  }

  /// Convenience overload taking [GeoPoint]s.
  static double bearingBetween(GeoPoint from, GeoPoint to) => initialBearingDeg(
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

    final double a =
        math.pow(math.sin(dPhi / 2), 2).toDouble() +
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
  static TargetReading readingTo(
    GeoPoint from,
    GeoPoint target, {
    DateTime? at,
  }) {
    final DateTime now = at ?? DateTime.now();
    final double distance = distanceBetweenKm(from, target);
    final double? radius = from.accuracyMetres;
    final bool knownRadius = radius != null && radius.isFinite && radius > 0;
    final double? speed = from.speedMps;
    final double? speedError = from.speedAccuracyMps;
    final bool knownMotion =
        speed != null &&
        speed.isFinite &&
        speed >= 0 &&
        speedError != null &&
        speedError.isFinite &&
        speedError >= 0;
    final double? speedUpper = knownMotion ? speed + speedError : null;
    final double ageSeconds = from.timestamp == null
        ? 0
        : math.max(0, now.difference(from.timestamp!).inMicroseconds / 1e6);
    // An OS radius describes the position at its timestamp, not the user's
    // current position. Propagate reported velocity error instead of treating
    // a moving / old fix as a stationary origin. Unknown motion is not precise.
    final double effectiveRadius = knownRadius
        ? radius + (speedUpper ?? 0) * ageSeconds
        : 0;
    final bool near = distance * 1000 <= math.max(10, effectiveRadius);
    final double? angularError = knownRadius && !near
        ? Angles.toDegrees(
            math.asin((effectiveRadius / (distance * 1000)).clamp(0, 1)),
          )
        : null;
    return TargetReading(
      bearingDeg: bearingBetween(from, target),
      distanceKm: distance,
      bearingUncertaintyDeg: angularError,
      isNearTarget: near,
      isApproximate: from.isApproximate || !knownRadius,
      locationReliable:
          from.isValid &&
          !from.isApproximate &&
          knownRadius &&
          knownMotion &&
          from.isFreshAt(now, maxAge: const Duration(seconds: 3)),
      locationAt: from.timestamp,
      originAccuracyMetres: knownRadius ? radius : null,
      originSpeedUpperMps: speedUpper,
    );
  }

  /// Converts a true bearing to a magnetic bearing for a hand compass:
  /// `magnetic = true − declination`.
  static double trueToMagnetic(double trueBearingDeg, double declinationDeg) =>
      Angles.normalize360(trueBearingDeg - declinationDeg);

  /// Converts a magnetic (compass) bearing to a true bearing:
  /// `true = magnetic + declination`.
  static double magneticToTrue(
    double magneticBearingDeg,
    double declinationDeg,
  ) => Angles.normalize360(magneticBearingDeg + declinationDeg);
}

/// Bearing and distance to a target, as shown on the compass screen.
class TargetReading {
  const TargetReading({
    required this.bearingDeg,
    required this.distanceKm,
    this.bearingUncertaintyDeg,
    this.isNearTarget = false,
    this.isApproximate = true,
    this.locationReliable = false,
    this.locationAt,
    this.originAccuracyMetres,
    this.originSpeedUpperMps,
  });

  final double? bearingUncertaintyDeg;
  final bool isNearTarget;
  final bool isApproximate;
  final bool locationReliable;
  final DateTime? locationAt;
  final double? originAccuracyMetres;
  final double? originSpeedUpperMps;

  /// Refresh the error circle at confirmation time, even between GPS fixes
  /// and the slower context ticker. OS uncertainty remains an estimate.
  double? bearingUncertaintyAt(DateTime now) {
    final DateTime? sampledAt = locationAt;
    final double? radius = originAccuracyMetres;
    final double? rate = originSpeedUpperMps;
    if (sampledAt == null || radius == null || rate == null) {
      return bearingUncertaintyDeg;
    }
    if (!radius.isFinite || radius <= 0 || !rate.isFinite || rate < 0) {
      return null;
    }
    final double age = math.max(
      0,
      now.difference(sampledAt).inMicroseconds / 1e6,
    );
    final double grown = radius + rate * age;
    final double metres = distanceKm * 1000;
    if (!grown.isFinite ||
        !metres.isFinite ||
        grown < 0 ||
        metres <= grown ||
        metres <= 10) {
      return null;
    }
    return Angles.toDegrees(math.asin((grown / metres).clamp(0, 1)));
  }

  /// True bearing to the target, 0 .. 360.
  final double bearingDeg;

  /// Great-circle distance to the target in kilometres.
  final double distanceKm;
}
