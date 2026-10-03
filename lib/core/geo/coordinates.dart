import 'dart:math' as math;

/// A point on the earth, with the optional extras a GPS fix gives us.
///
/// Immutable and comparable, so it can live in Riverpod state and be persisted
/// as two doubles.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.altitudeMetres,
    this.accuracyMetres,
    this.label,
    this.speedMps,
    this.courseDeg,
    this.courseAccuracyDeg,
  });

  /// Degrees, -90 (south) .. 90 (north).
  final double latitude;

  /// Degrees, -180 (west) .. 180 (east).
  final double longitude;

  /// Height above the WGS84 ellipsoid in metres, if known.
  final double? altitudeMetres;

  /// Horizontal accuracy of the fix in metres, if known.
  final double? accuracyMetres;

  /// Optional human label, e.g. the name of a centre the point was taken from.
  final String? label;

  /// Ground speed in metres per second, when the fix carries one.
  final double? speedMps;

  /// Course over ground in degrees from *true* north (0 .. 360), when the fix
  /// carries one. GPS course is already true north — never add declination.
  final double? courseDeg;

  /// Estimated error of [courseDeg] in degrees, when the platform reports it.
  final double? courseAccuracyDeg;

  /// Whether this fix carries a usable course: moving faster than
  /// [walkingSpeedMps] with a finite course and (if reported) a sane accuracy.
  bool get hasWalkingCourse {
    final double? speed = speedMps;
    final double? course = courseDeg;
    if (speed == null || course == null) {
      return false;
    }
    if (!speed.isFinite || !course.isFinite || speed < walkingSpeedMps) {
      return false;
    }
    if (course < 0 || course >= 360) {
      return false;
    }
    final double? accuracy = courseAccuracyDeg;
    // Android < 8 and some chipsets report 0 / NaN for "unknown": accept it,
    // the speed gate already filters the noise of a standing phone.
    if (accuracy != null && accuracy.isFinite && accuracy > 0) {
      return accuracy <= maxCourseAccuracyDeg;
    }
    return true;
  }

  /// Below this speed the GPS course is meaningless (about a slow walk).
  static const double walkingSpeedMps = 1.0;

  /// Course accuracies worse than this are ignored.
  static const double maxCourseAccuracyDeg = 45.0;

  /// Altitude in kilometres, defaulting to 0 when unknown (used by the WMM).
  double get altitudeKm => (altitudeMetres ?? 0.0) / 1000.0;

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    double? altitudeMetres,
    double? accuracyMetres,
    String? label,
    double? speedMps,
    double? courseDeg,
    double? courseAccuracyDeg,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMetres: altitudeMetres ?? this.altitudeMetres,
      accuracyMetres: accuracyMetres ?? this.accuracyMetres,
      label: label ?? this.label,
      speedMps: speedMps ?? this.speedMps,
      courseDeg: courseDeg ?? this.courseDeg,
      courseAccuracyDeg: courseAccuracyDeg ?? this.courseAccuracyDeg,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.altitudeMetres == altitudeMetres &&
      other.accuracyMetres == accuracyMetres &&
      other.label == label;

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        altitudeMetres,
        accuracyMetres,
        label,
      );

  @override
  String toString() =>
      'GeoPoint($latitude, $longitude, alt: $altitudeMetres, acc: $accuracyMetres)';
}

/// The fixed target of the whole app: Ekuphumuleni, the spiritual capital.
///
/// 29°04'31.7" S, 27°37'28.3" E = decimal -29.07547, 27.62453.
abstract final class Ekuphumuleni {
  /// Decimal latitude, negative because it is south of the equator.
  static const double latitude = -29.07547;

  /// Decimal longitude, positive because it is east of Greenwich.
  static const double longitude = 27.62453;

  /// The target as a [GeoPoint].
  static const GeoPoint point = GeoPoint(latitude: latitude, longitude: longitude);

  /// Coordinates in degrees / minutes / seconds (English letters; the UI uses
  /// `Formatters.dmsPair` so Portuguese shows `L` for east).
  static const String dms = '29° 04′ 31.7″ S   27° 37′ 28.3″ E';

  /// Coordinates in decimal degrees, as shown on the Guide screen.
  static const String decimal = '-29.07547, 27.62453';

  /// Latitude broken into degrees / minutes / seconds.
  static const List<double> latitudeDms = <double>[29, 4, 31.7];

  /// Longitude broken into degrees / minutes / seconds.
  static const List<double> longitudeDms = <double>[27, 37, 28.3];

  /// One line describing what Ekuphumuleni is (English; the UI shows the
  /// localised `S.ekuphumuleniDescription`).
  static const String description =
      'Ekuphumuleni is the designated spiritual capital for AIS spiritual '
      'mountain, temple and palace.';

  /// Mean height of the highveld around Ekuphumuleni, in metres. Only used as a
  /// fallback when the user's altitude is unknown.
  static const double fallbackAltitudeMetres = 1500.0;
}

/// Small angle helpers shared by the compass, the sun and the map code.
abstract final class Angles {
  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  /// Degrees to radians.
  static double toRadians(double degrees) => degrees * _degToRad;

  /// Radians to degrees.
  static double toDegrees(double radians) => radians * _radToDeg;

  /// Wraps an angle into 0 (inclusive) .. 360 (exclusive).
  static double normalize360(double degrees) {
    final double value = degrees % 360.0;
    return value.isNegative ? value + 360.0 : value;
  }

  /// Wraps an angle into -180 (exclusive) .. 180 (inclusive).
  static double normalize180(double degrees) {
    return normalize360(degrees + 180.0) - 180.0;
  }

  /// The shortest signed rotation from [from] to [to], in degrees.
  ///
  /// Positive means "turn clockwise / to your right".
  static double shortestDelta(double from, double to) =>
      normalize180(to - from);

  /// Absolute angular difference between two bearings, 0 .. 180.
  static double difference(double a, double b) => normalize180(a - b).abs();
}
