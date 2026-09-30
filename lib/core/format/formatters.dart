import '../geo/coordinates.dart';
import '../l10n/app_language.dart';

/// Presentation helpers for bearings, distances, coordinates and angles.
///
/// Kept separate from the UI so the formatting rules can be unit tested.
abstract final class Formatters {
  /// Thin space used as a thousands separator, matching the design
  /// ("1 234 km").
  static const String thinSpace = '\u2009';

  /// Formats a bearing as `318°`, rounded to whole degrees.
  static String bearing(double? degrees, {int decimals = 0}) {
    if (degrees == null) {
      return '—';
    }
    return '${Angles.normalize360(degrees).toStringAsFixed(decimals)}°';
  }

  /// Formats a bearing with its cardinal name, e.g. `318° NW`.
  static String bearingWithCardinal(double? degrees) {
    if (degrees == null) {
      return '—';
    }
    final double value = Angles.normalize360(degrees);
    return '${value.round()}° ${cardinal(value)}';
  }

  /// Sixteen-point compass abbreviations, starting at north, clockwise.
  static const List<String> _pointsEn = <String>[
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];

  /// Portuguese abbreviations: L = leste (east), O = oeste (west).
  static const List<String> _pointsPt = <String>[
    'N', 'NNE', 'NE', 'ENE', 'L', 'ESE', 'SE', 'SSE', //
    'S', 'SSO', 'SO', 'OSO', 'O', 'ONO', 'NO', 'NNO',
  ];

  /// The compass abbreviations for [language] (default: the app language).
  ///
  /// Only Portuguese has its own standard letters; isiZulu, Chichewa and
  /// Bemba use the international N / E / S / W found on printed compasses.
  static List<String> compassPoints([AppLanguage? language]) =>
      (language ?? L10n.language) == AppLanguage.pt ? _pointsPt : _pointsEn;

  /// Eight-point (or sixteen-point) compass name for a bearing, in the app
  /// language's abbreviations (see [compassPoints]).
  static String cardinal(
    double degrees, {
    bool sixteenPoint = true,
    AppLanguage? language,
  }) {
    final List<String> all = compassPoints(language);
    final List<String> points = sixteenPoint
        ? all
        : <String>[for (int i = 0; i < all.length; i += 2) all[i]];
    final double step = 360.0 / points.length;
    final int index =
        (Angles.normalize360(degrees + step / 2.0) / step).floor() %
            points.length;
    return points[index];
  }

  /// Formats a distance in kilometres: metres under 1 km, one decimal under
  /// 10 km, then grouped whole kilometres ("1 234 km").
  static String distanceKm(double? kilometres) {
    if (kilometres == null) {
      return '—';
    }
    if (kilometres.isNaN || kilometres.isInfinite) {
      return '—';
    }
    if (kilometres < 1.0) {
      return '${(kilometres * 1000).round()} m';
    }
    if (kilometres < 10.0) {
      return '${kilometres.toStringAsFixed(1)} km';
    }
    return '${groupDigits(kilometres.round())} km';
  }

  /// Groups an integer with thin spaces, e.g. `1234` → `1 234`.
  static String groupDigits(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int fromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (fromEnd > 1 && (fromEnd - 1) % 3 == 0) {
        buffer.write(thinSpace);
      }
    }
    final String result = buffer.toString();
    return value.isNegative ? '−$result' : result;
  }

  /// Formats a signed angle, e.g. `−20.6°` (using a real minus sign).
  static String signedDegrees(double? degrees, {int decimals = 1}) {
    if (degrees == null) {
      return '—';
    }
    final String value = degrees.abs().toStringAsFixed(decimals);
    final String sign = degrees < 0 ? '−' : '';
    return '$sign$value°';
  }

  /// Formats a declination, e.g. `20.6° W` / `3.1° E` (`O` / `L` in
  /// Portuguese).
  static String declination(double? degrees,
      {int decimals = 1, AppLanguage? language}) {
    if (degrees == null) {
      return '—';
    }
    final List<String> points = compassPoints(language);
    final String hemisphere = degrees < 0 ? points[12] : points[4];
    return '${degrees.abs().toStringAsFixed(decimals)}° $hemisphere';
  }

  /// Formats a latitude / longitude pair for the readouts, e.g.
  /// `26.2041° S, 28.0473° E` (`… L` in Portuguese).
  static String latLon(double? latitude, double? longitude,
      {int decimals = 4, AppLanguage? language}) {
    if (latitude == null || longitude == null) {
      return '—';
    }
    final List<String> points = compassPoints(language);
    return '${coordinate(latitude, points[8], points[0], decimals: decimals)}, '
        '${coordinate(longitude, points[12], points[4], decimals: decimals)}';
  }

  /// Formats one coordinate with its hemisphere letter.
  static String coordinate(double value, String negativeSuffix,
      String positiveSuffix,
      {int decimals = 4}) {
    final String suffix = value < 0 ? negativeSuffix : positiveSuffix;
    return '${value.abs().toStringAsFixed(decimals)}° $suffix';
  }

  /// Formats a [GeoPoint] as `26.2041° S, 28.0473° E`.
  static String geoPoint(GeoPoint? point,
      {int decimals = 4, AppLanguage? language}) {
    if (point == null) {
      return '—';
    }
    return latLon(point.latitude, point.longitude,
        decimals: decimals, language: language);
  }

  /// Formats an accuracy in metres, e.g. `± 5 m`.
  static String accuracyMetres(double? metres) {
    if (metres == null) {
      return '—';
    }
    if (metres < 1) {
      return '± ${metres.toStringAsFixed(1)} m';
    }
    return '± ${metres.round()} m';
  }

  /// Formats an altitude in metres, e.g. `1 753 m`.
  static String altitudeMetres(double? metres) {
    if (metres == null) {
      return '—';
    }
    return '${groupDigits(metres.round())} m';
  }

  /// Formats an elevation above the horizon, e.g. `32.4° above horizon`.
  static String elevation(double? degrees) {
    if (degrees == null) {
      return '—';
    }
    return '${degrees.toStringAsFixed(1)}°';
  }

  /// Formats a clock time in 24-hour form from a UTC instant, without pulling
  /// in `intl`.
  static String timeOfDay(DateTime when, {bool toLocal = true}) {
    final DateTime time = toLocal ? when.toLocal() : when.toUtc();
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// A latitude / longitude pair in degrees / minutes / seconds, e.g.
  /// `29° 04′ 31.7″ S   27° 37′ 28.3″ E` (`… L` in Portuguese).
  static String dmsPair(double latitude, double longitude,
      {AppLanguage? language}) {
    final List<String> points = compassPoints(language);
    return '${dms(latitude, points[8], points[0])}   '
        '${dms(longitude, points[12], points[4])}';
  }

  /// Converts decimal degrees to degrees / minutes / seconds text,
  /// e.g. `29° 04′ 31.7″ S`.
  static String dms(double value, String negativeSuffix, String positiveSuffix) {
    final String suffix = value < 0 ? negativeSuffix : positiveSuffix;
    final double absolute = value.abs();
    final int degrees = absolute.floor();
    final double minutesDecimal = (absolute - degrees) * 60.0;
    final int minutes = minutesDecimal.floor();
    final double seconds = (minutesDecimal - minutes) * 60.0;
    return '$degrees° ${minutes.toString().padLeft(2, '0')}′ '
        '${seconds.toStringAsFixed(1)}″ $suffix';
  }
}
