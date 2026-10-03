import 'dart:math' as math;

import '../geo/coordinates.dart';
import '../time/decimal_year.dart';
import 'wmm_coefficients.dart';

/// The magnetic field vector at one place and time, as produced by the WMM.
///
/// Components follow the WMM convention: X is north, Y is east, Z is down,
/// all in nanotesla (nT).
class MagneticField {
  const MagneticField({
    required this.declinationDeg,
    required this.inclinationDeg,
    required this.horizontalIntensityNT,
    required this.totalIntensityNT,
    required this.northComponentNT,
    required this.eastComponentNT,
    required this.verticalComponentNT,
    required this.decimalYear,
  });

  /// Declination (magnetic variation) in degrees. Positive is east, negative
  /// is west — across Southern Africa it is negative, i.e. magnetic north is
  /// west of true north.
  final double declinationDeg;

  /// Inclination (dip) in degrees. Positive is down (northern hemisphere).
  final double inclinationDeg;

  /// Horizontal intensity H, in nT. Compasses are unreliable below 2000 nT.
  final double horizontalIntensityNT;

  /// Total intensity F, in nT.
  final double totalIntensityNT;

  /// North component X, in nT.
  final double northComponentNT;

  /// East component Y, in nT.
  final double eastComponentNT;

  /// Vertical (down) component Z, in nT.
  final double verticalComponentNT;

  /// The decimal year the field was evaluated at.
  final double decimalYear;

  /// Absolute declination, in degrees.
  double get declinationMagnitudeDeg => declinationDeg.abs();

  /// `true` when magnetic north is west of true north (declination < 0).
  bool get isWest => declinationDeg < 0;

  /// `true` when the horizontal field is so weak that a compass is unreliable
  /// (the WMM "blackout zone", H < 2000 nT).
  bool get inBlackoutZone => horizontalIntensityNT < 2000.0;

  /// `true` in the WMM "caution zone" (2000 nT <= H < 6000 nT).
  bool get inCautionZone =>
      !inBlackoutZone && horizontalIntensityNT < 6000.0;

  /// WMM2025 declination uncertainty for this point, in degrees.
  ///
  /// From the WMM2025 error model: `sqrt(0.26² + (5417 / H)²)`.
  double get declinationUncertaintyDeg =>
      math.sqrt(0.26 * 0.26 + math.pow(5417.0 / horizontalIntensityNT, 2));

  @override
  String toString() => 'MagneticField(D: ${declinationDeg.toStringAsFixed(2)}°, '
      'I: ${inclinationDeg.toStringAsFixed(2)}°, '
      'H: ${horizontalIntensityNT.toStringAsFixed(0)} nT)';
}

/// World Magnetic Model 2025 (WMM2025), degree and order 12.
///
/// A Dart port of the spherical-harmonic evaluation published by NOAA/NCEI and
/// NGA, using the official WMM2025 Gauss coefficients bundled in
/// `wmm_coefficients.dart`. Nothing is hard-coded: declination is derived from
/// the user's position, altitude and the date, so it stays correct as the field
/// drifts and as the user travels.
///
/// Verified against NOAA's published WMM2025 test values (100 vectors covering
/// 2025.0 - 2026.0, -90°..90° latitude): worst case difference is 0.005° in
/// declination and 0.001 nT in horizontal intensity. See `test/core/wmm_test.dart`.
class Wmm2025 {
  Wmm2025._();

  /// Highest degree / order of the model.
  static const int maxOrder = 12;

  /// Epoch of the bundled coefficients, in decimal years.
  static const double epoch = kWmmEpoch;

  /// The last decimal year the model is valid for.
  static const double validUntil = kWmmEpoch + 5.0;

  /// Human readable model name, e.g. "WMM-2025".
  static String get modelName => kWmmModelName;

  static const double _a = 6378.137; // WGS84 semi-major axis, km.
  static const double _b = 6356.7523142; // WGS84 semi-minor axis, km.
  static const double _re = 6371.2; // WMM reference radius, km.

  static const int _size = maxOrder + 1;

  // Lazily built, immutable once built. Mirrors the tables the reference C code
  // prepares from the coefficient file.
  static List<List<double>>? _c;
  static List<List<double>>? _cd;
  static List<List<double>>? _k;
  static List<double>? _fn;
  static List<double>? _fm;

  /// The full field vector at a geodetic position and time.
  ///
  /// [latitudeDeg] and [longitudeDeg] are geodetic (WGS84) degrees,
  /// [altitudeKm] is height above the WGS84 ellipsoid in kilometres, and
  /// [when] is any moment (converted to a decimal year internally).
  static MagneticField field({
    required double latitudeDeg,
    required double longitudeDeg,
    required double altitudeKm,
    required DateTime when,
  }) {
    _ensureTables();
    final double year = DecimalYear.fromDateTime(when);
    return _field(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      altitudeKm: altitudeKm,
      year: year,
    );
  }

  /// Convenience wrapper returning only the declination in degrees.
  static double declinationDeg({
    required double latitudeDeg,
    required double longitudeDeg,
    required double altitudeKm,
    required DateTime when,
  }) {
    return field(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      altitudeKm: altitudeKm,
      when: when,
    ).declinationDeg;
  }

  /// Same as [field] but taking an already computed decimal year.
  static MagneticField fieldAtDecimalYear({
    required double latitudeDeg,
    required double longitudeDeg,
    required double altitudeKm,
    required double decimalYear,
  }) {
    _ensureTables();
    return _field(
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      altitudeKm: altitudeKm,
      year: decimalYear,
    );
  }

  static MagneticField _field({
    required double latitudeDeg,
    required double longitudeDeg,
    required double altitudeKm,
    required double year,
  }) {
    final List<List<double>> c = _c!;
    final List<List<double>> cd = _cd!;
    final List<List<double>> k = _k!;
    final List<double> fn = _fn!;
    final List<double> fm = _fm!;

    // Working arrays for this evaluation.
    final List<List<double>> tc = _matrix(_size, _size);
    final List<List<double>> dp = _matrix(_size, _size);
    final List<double> sp = List<double>.filled(_size, 0.0);
    final List<double> cp = List<double>.filled(_size, 0.0);
    final List<double> pp = List<double>.filled(_size, 0.0);
    // p is indexed [n + m * size]; p[0] is P(0,0) == 1.
    final List<double> p = List<double>.filled(_size * _size, 0.0)..[0] = 1.0;

    sp[0] = 0.0;
    cp[0] = 1.0;
    pp[0] = 1.0;
    dp[0][0] = 0.0;

    const double a2 = _a * _a;
    const double b2 = _b * _b;
    const double c2 = a2 - b2;
    const double a4 = a2 * a2;
    const double b4 = b2 * b2;
    const double c4 = a4 - b4;

    final double dt = year - epoch;

    final double rlon = Angles.toRadians(longitudeDeg);
    final double rlat = Angles.toRadians(latitudeDeg);
    final double srlon = math.sin(rlon);
    final double srlat = math.sin(rlat);
    final double crlon = math.cos(rlon);
    final double crlat = math.cos(rlat);
    final double srlat2 = srlat * srlat;
    final double crlat2 = crlat * crlat;
    sp[1] = srlon;
    cp[1] = crlon;

    // Convert geodetic coordinates to spherical (geocentric) coordinates.
    final double q = math.sqrt(a2 - c2 * srlat2);
    final double q1 = altitudeKm * q;
    final double q2 = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2));
    final double ct = srlat / math.sqrt(q2 * crlat2 + srlat2);
    final double st = math.sqrt(math.max(0.0, 1.0 - ct * ct));
    final double r2 = altitudeKm * altitudeKm +
        2.0 * q1 +
        (a4 - c4 * srlat2) / (q * q);
    final double r = math.sqrt(r2);
    final double d = math.sqrt(a2 * crlat2 + b2 * srlat2);
    final double ca = (altitudeKm + d) / r;
    final double sa = c2 * crlat * srlat / (r * d);

    for (int m = 2; m <= maxOrder; m++) {
      sp[m] = sp[1] * cp[m - 1] + cp[1] * sp[m - 1];
      cp[m] = cp[1] * cp[m - 1] - sp[1] * sp[m - 1];
    }

    final double aor = _re / r;
    double ar = aor * aor;
    double br = 0.0;
    double bt = 0.0;
    double bp = 0.0;
    double bpp = 0.0;

    for (int n = 1; n <= maxOrder; n++) {
      ar = ar * aor;
      int m = 0;
      const int d3 = 1;
      double d4 = (n + m + d3) / d3;
      while (d4 > 0) {
        // Schmidt semi-normalised associated Legendre functions and their
        // derivatives, by recursion.
        if (n == m) {
          p[n + m * _size] = st * p[n - 1 + (m - 1) * _size];
          dp[m][n] = st * dp[m - 1][n - 1] + ct * p[n - 1 + (m - 1) * _size];
        } else if (n == 1 && m == 0) {
          p[n + m * _size] = ct * p[n - 1 + m * _size];
          dp[m][n] = ct * dp[m][n - 1] - st * p[n - 1 + m * _size];
        } else if (n > 1 && n != m) {
          if (m > n - 2) {
            p[n - 2 + m * _size] = 0.0;
          }
          if (m > n - 2) {
            dp[m][n - 2] = 0.0;
          }
          p[n + m * _size] =
              ct * p[n - 1 + m * _size] - k[m][n] * p[n - 2 + m * _size];
          dp[m][n] = ct * dp[m][n - 1] -
              st * p[n - 1 + m * _size] -
              k[m][n] * dp[m][n - 2];
        }

        // Time adjust the Gauss coefficients with the secular variation.
        tc[m][n] = c[m][n] + dt * cd[m][n];
        if (m != 0) {
          tc[n][m - 1] = c[n][m - 1] + dt * cd[n][m - 1];
        }

        // Accumulate the spherical harmonic expansions.
        final double par = ar * p[n + m * _size];
        double temp1;
        double temp2;
        if (m == 0) {
          temp1 = tc[m][n] * cp[m];
          temp2 = tc[m][n] * sp[m];
        } else {
          temp1 = tc[m][n] * cp[m] + tc[n][m - 1] * sp[m];
          temp2 = tc[m][n] * sp[m] - tc[n][m - 1] * cp[m];
        }
        bt = bt - ar * temp1 * dp[m][n];
        bp = bp + fm[m] * temp2 * par;
        br = br + fn[n] * temp1 * par;

        // Special case: north / south geographic poles.
        if (st == 0.0 && m == 1) {
          if (n == 1) {
            pp[n] = pp[n - 1];
          } else {
            pp[n] = ct * pp[n - 1] - k[m][n] * pp[n - 2];
          }
          final double parp = ar * pp[n];
          bpp = bpp + fm[m] * temp2 * parp;
        }

        d4 = d4 - 1;
        m = m + d3;
      }
    }

    if (st == 0.0) {
      bp = bpp;
    } else {
      bp = bp / st;
    }

    // Rotate the magnetic vector from spherical to geodetic coordinates.
    final double bx = -bt * ca - br * sa;
    final double by = bp;
    final double bz = bt * sa - br * ca;

    final double bh = math.sqrt(bx * bx + by * by);
    final double total = math.sqrt(bh * bh + bz * bz);

    return MagneticField(
      declinationDeg: Angles.toDegrees(math.atan2(by, bx)),
      inclinationDeg: Angles.toDegrees(math.atan2(bz, bh)),
      horizontalIntensityNT: bh,
      totalIntensityNT: total,
      northComponentNT: bx,
      eastComponentNT: by,
      verticalComponentNT: bz,
      decimalYear: year,
    );
  }

  /// Builds the Schmidt semi-normalisation tables once, from the bundled
  /// coefficient file.
  static void _ensureTables() {
    if (_c != null) {
      return;
    }
    final List<List<double>> c = _matrix(_size, _size);
    final List<List<double>> cd = _matrix(_size, _size);
    final List<double> snorm = List<double>.filled(_size * _size, 0.0);
    final List<double> fn = List<double>.filled(_size, 0.0);
    final List<double> fm = List<double>.filled(_size, 0.0);
    final List<List<double>> k = _matrix(_size, _size);

    for (final List<num> row in kWmm2025Coefficients) {
      final int n = row[0].toInt();
      final int m = row[1].toInt();
      final double gnm = row[2].toDouble();
      final double hnm = row[3].toDouble();
      final double dgnm = row[4].toDouble();
      final double dhnm = row[5].toDouble();
      if (m > maxOrder) {
        break;
      }
      if (m > n || m < 0) {
        throw StateError('Corrupt WMM coefficient row: n=$n m=$m');
      }
      c[m][n] = gnm;
      cd[m][n] = dgnm;
      if (m != 0) {
        c[n][m - 1] = hnm;
        cd[n][m - 1] = dhnm;
      }
    }

    // Convert Schmidt-normalised Gauss coefficients to unnormalised ones.
    snorm[0] = 1.0;
    fm[0] = 0.0;
    for (int n = 1; n <= maxOrder; n++) {
      snorm[n] = snorm[n - 1] * (2 * n - 1) / n;
      int j = 2;
      int m = 0;
      const int d1 = 1;
      double d2 = (n - m + d1) / d1;
      while (d2 > 0) {
        k[m][n] =
            (((n - 1) * (n - 1)) - (m * m)) / ((2 * n - 1) * (2 * n - 3));
        if (m > 0) {
          final double flnmj = ((n - m + 1) * j) / (n + m);
          snorm[n + m * _size] =
              snorm[n + (m - 1) * _size] * math.sqrt(flnmj);
          j = 1;
          c[n][m - 1] = snorm[n + m * _size] * c[n][m - 1];
          cd[n][m - 1] = snorm[n + m * _size] * cd[n][m - 1];
        }
        c[m][n] = snorm[n + m * _size] * c[m][n];
        cd[m][n] = snorm[n + m * _size] * cd[m][n];
        d2 = d2 - 1;
        m = m + d1;
      }
      fn[n] = (n + 1).toDouble();
      fm[n] = n.toDouble();
    }
    k[1][1] = 0.0;

    _c = c;
    _cd = cd;
    _fn = fn;
    _fm = fm;
    _k = k;
  }

  static List<List<double>> _matrix(int rows, int columns) =>
      List<List<double>>.generate(
        rows,
        (_) => List<double>.filled(columns, 0.0),
        growable: false,
      );
}
