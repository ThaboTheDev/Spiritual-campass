/// Converts between `DateTime` and decimal years, the time unit the World
/// Magnetic Model uses (2025.0 is 1 January 2025, 2025.5 is roughly 2 July
/// 2025).
abstract final class DecimalYear {
  /// Milliseconds in a common year, used for the fraction of the year elapsed.
  static const int _commonYearMs = 365 * 24 * 60 * 60 * 1000;
  static const int _leapYearMs = 366 * 24 * 60 * 60 * 1000;

  /// Converts a UTC [dateTime] to a decimal year.
  ///
  /// The fraction is `elapsed / length of this year in milliseconds`, which is
  /// the convention used for geomagnetic models. Values before 1970 are not
  /// supported (the WMM does not need them).
  static double fromDateTime(DateTime dateTime) {
    final DateTime utc = dateTime.toUtc();
    final int year = utc.year;
    final DateTime start = DateTime.utc(year, 1, 1);
    final DateTime end = DateTime.utc(year + 1, 1, 1);
    final double yearLengthMs = (end.difference(start).inMilliseconds).toDouble();
    final double elapsedMs = utc.difference(start).inMilliseconds.toDouble();
    return year + (elapsedMs / yearLengthMs);
  }

  /// Approximate inverse of [fromDateTime], good to the second.
  static DateTime toDateTime(double decimalYear) {
    final int year = decimalYear.floor();
    final double fraction = decimalYear - year;
    final bool leap = _isLeapYear(year);
    final int yearLengthMs = leap ? _leapYearMs : _commonYearMs;
    return DateTime.fromMillisecondsSinceEpoch(
      DateTime.utc(year, 1, 1).millisecondsSinceEpoch +
          (fraction * yearLengthMs).round(),
      isUtc: true,
    );
  }

  /// Whether [year] is a Gregorian leap year.
  static bool _isLeapYear(int year) =>
      (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
}
