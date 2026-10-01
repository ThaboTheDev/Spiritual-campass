import 'dart:math' as math;

import '../geo/coordinates.dart';

/// Where the sun is, as seen from one place at one moment.
class SunPosition {
  const SunPosition({
    required this.azimuthDeg,
    required this.elevationDeg,
    required this.declinationDeg,
    required this.equationOfTimeMinutes,
    required this.hourAngleDeg,
    required this.at,
  });

  /// Compass bearing of the sun in degrees, 0 = north, 90 = east.
  ///
  /// Geometric horizontal azimuth. Atmospheric refraction is applied to
  /// elevation only; it must not distort the horizontal heading anchor.
  final double azimuthDeg;

  /// Height of the sun above the horizon in degrees. Negative means the sun has
  /// set; the value includes the refraction correction.
  final double elevationDeg;

  /// Solar declination: the sun's latitude on the celestial sphere, in degrees.
  /// +23.44° at the June solstice, -23.44° at the December solstice.
  final double declinationDeg;

  /// Equation of time in minutes: how far the real sun is ahead of (positive) or
  /// behind (negative) the mean sun. Ranges roughly -14 to +16 minutes.
  final double equationOfTimeMinutes;

  /// Hour angle in degrees: 0 at solar noon, negative in the morning,
  /// positive in the afternoon, 15° per hour.
  final double hourAngleDeg;

  /// The moment (UTC) this position was computed for.
  final DateTime at;

  /// Whether the sun is up.
  bool get isAboveHorizon => elevationDeg > 0;

  /// Whether the sun is usefully high for a shadow: above the horizon by more
  /// than a couple of degrees, so a stick casts a readable shadow.
  bool get castsShadow => elevationDeg > 2.0 && elevationDeg < 80.0;

  /// Avoid uncertain horizon and overhead azimuths for a manual heading anchor.
  bool get canAnchorHeading =>
      azimuthDeg.isFinite && elevationDeg >= 5 && elevationDeg < 80;

  /// The bearing a shadow points: directly away from the sun.
  ///
  /// Stand with your back to the sun and this is the direction in front of you.
  double get shadowBearingDeg => Angles.normalize360(azimuthDeg + 180.0);

  @override
  String toString() =>
      'SunPosition(az: ${azimuthDeg.toStringAsFixed(1)}°, '
      'elev: ${elevationDeg.toStringAsFixed(1)}°, '
      'dec: ${declinationDeg.toStringAsFixed(2)}°)';
}

/// NOAA-style solar position algorithm.
///
/// Computes the sun's azimuth and elevation from a latitude, a longitude and a
/// UTC instant. The implementation follows the NOAA Solar Calculator /
/// Solar Position Calculator (Reda & Andreas) formulation, including the
/// equation of time and the standard atmospheric refraction correction.
///
/// Accuracy is better than 0.05° for the 2020 - 2050 window, which is far more
/// than a compass app needs. See `test/core/sun_position_test.dart` for the
/// checks run against known solstice / equinox / equation-of-time values.
abstract final class SunCalculator {
  /// Computes the sun position for [at] (UTC) as seen from
  /// [latitudeDeg] / [longitudeDeg].
  static SunPosition calculate({
    required DateTime at,
    required double latitudeDeg,
    required double longitudeDeg,
  }) {
    final DateTime utc = at.toUtc();

    // 1. Julian day and Julian century.
    final double julianDay = _julianDay(utc);
    final double t = (julianDay - 2451545.0) / 36525.0;

    // 2. Geometric mean longitude and mean anomaly of the sun (degrees).
    final double l0 = _mod360(280.46646 + t * (36000.76983 + t * 0.0003032));
    final double m = 357.52911 + t * (35999.05029 - 0.0001537 * t);

    // 3. Eccentricity of the earth's orbit.
    final double e = 0.016708634 - t * (0.000042037 + t * 0.0000001267);

    // 4. Equation of the centre.
    final double mr = Angles.toRadians(m);
    final double centre =
        math.sin(mr) * (1.914602 - t * (0.004817 + t * 0.000014)) +
        math.sin(2 * mr) * (0.019993 - 0.000101 * t) +
        math.sin(3 * mr) * 0.000289;

    // 5. True longitude, then apparent longitude (aberration + nutation).
    final double trueLongitude = l0 + centre;
    final double omega = 125.04 - 1934.136 * t;
    final double apparentLongitude =
        trueLongitude - 0.00569 - 0.00478 * math.sin(Angles.toRadians(omega));

    // 6. Obliquity of the ecliptic (mean, then corrected).
    final double seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813));
    final double meanObliquity = 23 + (26 + seconds / 60.0) / 60.0;
    final double obliquity =
        meanObliquity + 0.00256 * math.cos(Angles.toRadians(omega));

    // 7. Solar declination.
    final double declination = Angles.toDegrees(
      math.asin(
        math.sin(Angles.toRadians(obliquity)) *
            math.sin(Angles.toRadians(apparentLongitude)),
      ),
    );

    // 8. Equation of time, in minutes (1 degree = 4 minutes of time).
    final double y = math
        .pow(math.tan(Angles.toRadians(obliquity) / 2), 2)
        .toDouble();
    final double l0r = Angles.toRadians(l0);
    final double equationOfTime =
        4 *
        Angles.toDegrees(
          y * math.sin(2 * l0r) -
              2 * e * math.sin(mr) +
              4 * e * y * math.sin(mr) * math.cos(2 * l0r) -
              0.5 * y * y * math.sin(4 * l0r) -
              1.25 * e * e * math.sin(2 * mr),
        );

    // 9. Hour angle. Times are UTC, so the timezone offset is zero and only the
    //    longitude (4 minutes per degree) shifts local solar time.
    final double minutesUtc =
        utc.hour * 60.0 + utc.minute + utc.second + utc.millisecond / 1000.0;
    final double trueSolarTime = _mod(
      minutesUtc + equationOfTime + 4 * longitudeDeg,
      1440.0,
    );
    double hourAngle = trueSolarTime / 4.0 - 180.0;
    if (hourAngle < -180.0) {
      hourAngle += 360.0;
    } else if (hourAngle > 180.0) {
      hourAngle -= 360.0;
    }

    // 10. Zenith angle and elevation, then refraction.
    final double latR = Angles.toRadians(latitudeDeg);
    final double decR = Angles.toRadians(declination);
    final double haR = Angles.toRadians(hourAngle);
    final double cosZenith = _clamp(
      math.sin(latR) * math.sin(decR) +
          math.cos(latR) * math.cos(decR) * math.cos(haR),
      -1.0,
      1.0,
    );
    final double zenith = Angles.toDegrees(math.acos(cosZenith));
    double elevation = 90.0 - zenith;
    elevation += _refractionDeg(elevation);
    // Refraction changes elevation, not azimuth. Use geometric zenith below.

    // 11. Azimuth, measured clockwise from north.
    final double denom = math.cos(latR) * math.sin(Angles.toRadians(zenith));
    double azimuth;
    if (denom.abs() > 1e-9) {
      final double value = _clamp(
        (math.sin(latR) * math.cos(Angles.toRadians(zenith)) - math.sin(decR)) /
            denom,
        -1.0,
        1.0,
      );
      final double angle = Angles.toDegrees(math.acos(value));
      azimuth = hourAngle > 0 ? _mod360(angle + 180.0) : _mod360(540.0 - angle);
    } else {
      // Directly overhead (or the sun is exactly at the nadir): the bearing is
      // undefined, so fall back to the hemisphere the sun is on.
      azimuth = latitudeDeg > 0 ? 180.0 : 0.0;
    }

    return SunPosition(
      azimuthDeg: azimuth,
      elevationDeg: elevation,
      declinationDeg: declination,
      equationOfTimeMinutes: equationOfTime,
      hourAngleDeg: hourAngle,
      at: utc,
    );
  }

  /// Julian day number (with fraction of day) for a UTC instant.
  static double _julianDay(DateTime utc) {
    int year = utc.year;
    int month = utc.month;
    final double day =
        utc.day +
        (utc.hour +
                utc.minute / 60.0 +
                (utc.second + utc.millisecond / 1000.0) / 60.0) /
            24.0;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final int a = (year / 100.0).floor();
    final int b = 2 - a + (a / 4.0).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  /// Sæmundsson's refraction formula, converted to degrees.
  static double _refractionDeg(double elevationDeg) {
    if (elevationDeg > 85.0) {
      return 0.0;
    }
    final double te = math.tan(Angles.toRadians(elevationDeg));
    double refractionArcSeconds;
    if (elevationDeg > 5.0) {
      refractionArcSeconds =
          58.1 / te -
          0.07 / math.pow(te, 3).toDouble() +
          0.000086 / math.pow(te, 5).toDouble();
    } else if (elevationDeg > -0.575) {
      refractionArcSeconds =
          1735.0 +
          elevationDeg *
              (-518.2 +
                  elevationDeg *
                      (103.4 + elevationDeg * (-12.79 + elevationDeg * 0.711)));
    } else {
      refractionArcSeconds = -20.774 / te;
    }
    return refractionArcSeconds / 3600.0;
  }

  static double _mod360(double value) =>
      value % 360.0 < 0 ? (value % 360.0) + 360.0 : value % 360.0;

  static double _mod(double value, double modulus) {
    final double result = value % modulus;
    return result < 0 ? result + modulus : result;
  }

  static double _clamp(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);
}
