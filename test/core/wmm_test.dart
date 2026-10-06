import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/time/decimal_year.dart';
import 'package:tshk_compass/core/wmm/wmm.dart';

/// A row from NOAA's published WMM2025 test values
/// (`WMM2025_TEST_VALUES.txt`, 100 vectors, epoch 2025.0).
class _TestVector {
  const _TestVector(
    this.year,
    this.altitudeKm,
    this.latitude,
    this.longitude,
    this.declination,
    this.inclination,
    this.h,
    this.x,
    this.y,
    this.z,
    this.f,
  );

  final double year;
  final double altitudeKm;
  final double latitude;
  final double longitude;
  final double declination;
  final double inclination;
  final double h;
  final double x;
  final double y;
  final double z;
  final double f;
}

/// Fields: decimal year, altitude (km), lat, lon, D, I, H, X, Y, Z, F.
const List<_TestVector> _noaaTestVectors = <_TestVector>[
  _TestVector(2025.0, 28, 89, -121, -99.77, 88.47, 1504.298146, -255.388723,
      -1482.460628, 56194.288771, 56214.419888),
  _TestVector(2025.0, 65, 43, 93, 0.50, 64.10, 24300.764692, 24299.852822,
      210.517066, 50037.923998, 55626.621348),
  _TestVector(2025.0, 51, -33, 109, -5.49, -67.50, 21838.046477, 21737.778822,
      -2090.274098, -52710.00392, 57054.752538),
  _TestVector(2025.5, 6, -36, -137, 20.28, -52.11, 25353.230658, 23781.930678,
      8786.698927, -32577.518648, 41280.516301),
  _TestVector(2025.5, 8, -66, 17, -33.14, -59.55, 18154.870136, 15201.438652,
      -9925.501123, -30881.123197, 35822.382382),
  _TestVector(2026.0, 74, -57, 3, -22.51, -58.65, 14362.206593, 13268.119649,
      -5498.179626, -23576.062921, 27606.226129),
  _TestVector(2026.0, 62, -14, 99, -1.43, -44.70, 33448.275663, 33437.82863,
      -835.919473, -33100.922253, 47058.03012),
  _TestVector(2026.5, 14, 0, 80, -3.10, -17.15, 39489.089663, 39431.415992,
      -2133.456168, -12188.838466, 41327.424134),
  _TestVector(2027.0, 37, -66, -5, -17.22, -59.04, 17159.8365, 16390.771268,
      -5079.626554, -28608.243575, 33360.029814),
  _TestVector(2027.5, 73, -72, 95, -102.64, -76.49, 13306.747292, -2912.418045,
      -12984.118939, -55399.217725, 56974.931751),
];

void main() {
  group('WMM2025 against NOAA test values', () {
    for (final _TestVector vector in _noaaTestVectors) {
      test('lat ${vector.latitude}, lon ${vector.longitude} @ ${vector.year}',
          () {
        final MagneticField field = Wmm2025.fieldAtDecimalYear(
          latitudeDeg: vector.latitude,
          longitudeDeg: vector.longitude,
          altitudeKm: vector.altitudeKm,
          decimalYear: vector.year,
        );

        // The published values are rounded to 2 decimals / 6 significant
        // figures, so these tolerances are as tight as the data allows.
        expect(field.declinationDeg, closeTo(vector.declination, 0.006),
            reason: 'declination');
        expect(field.inclinationDeg, closeTo(vector.inclination, 0.006),
            reason: 'inclination');
        expect(field.horizontalIntensityNT, closeTo(vector.h, 0.05),
            reason: 'horizontal intensity');
        expect(field.northComponentNT, closeTo(vector.x, 0.05), reason: 'X');
        expect(field.eastComponentNT, closeTo(vector.y, 0.05), reason: 'Y');
        expect(field.verticalComponentNT, closeTo(vector.z, 0.05), reason: 'Z');
        expect(field.totalIntensityNT, closeTo(vector.f, 0.05), reason: 'F');
      });
    }
  });

  group('Southern Africa declination', () {
    test('Johannesburg is about 20 degrees west', () {
      // WMM2025: -20.35 deg at 2025.0, -20.61 deg at 2026.0, -21.64 deg at
      // 2029.9. (Older models and older tables quote -17 to -19 deg, which was
      // the value around 2010-2015; the field has drifted west since.)
      final double at2025 = Wmm2025.declinationDeg(
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
        altitudeKm: 1.75,
        when: DateTime.utc(2025, 1, 1),
      );
      final double at2026 = Wmm2025.declinationDeg(
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
        altitudeKm: 1.75,
        when: DateTime.utc(2026, 1, 1),
      );

      expect(at2025, closeTo(-20.346, 0.05));
      expect(at2026, closeTo(-20.612, 0.05));
      expect(at2026, lessThan(at2025)); // drifting further west
    });

    test('is negative (west) and inside the 17 - 28 degree guide range', () {
      const List<List<double>> southernAfrica = <List<double>>[
        <double>[-26.2041, 28.0473], // Johannesburg
        <double>[-25.7479, 28.2293], // Pretoria
        <double>[-29.07547, 27.62453], // Ekuphumuleni
        <double>[-29.0852, 26.1596], // Bloemfontein
        <double>[-26.3216, 28.1462], // Katlehong
        <double>[-25.51, 28.06], // Mabopane
        <double>[-33.9249, 18.4241], // Cape Town
        <double>[-29.8579, 31.0292], // Durban
      ];

      for (final List<double> point in southernAfrica) {
        final double declination = Wmm2025.declinationDeg(
          latitudeDeg: point[0],
          longitudeDeg: point[1],
          altitudeKm: 1.5,
          when: DateTime.utc(2026, 6, 1),
        );
        expect(declination, lessThan(0),
            reason: 'magnetic north is west of true north at $point');
        expect(
          declination.abs() >= 17.0 && declination.abs() <= 28.0,
          isTrue,
          reason: 'declination (${declination.toStringAsFixed(2)}) at $point '
              'should sit inside the 17 - 28 degree guide range',
        );
      }
    });

    test('the model is valid for 2025.0 - 2030.0', () {
      expect(Wmm2025.epoch, 2025.0);
      expect(Wmm2025.validUntil, 2030.0);
      expect(Wmm2025.maxOrder, 12);
    });
  });

  group('field sanity', () {
    test('Ekuphumuleni readings are plausible', () {
      // The expected values below are the 2026.0 figures quoted in the README
      // (Ekuphumuleni -24.9 degrees), so the field is evaluated at 1 January
      // 2026. Declination drifts about 0.25 degrees west per year, which is
      // more than the tolerances here.
      final MagneticField field = Wmm2025.field(
        latitudeDeg: -29.07547,
        longitudeDeg: 27.62453,
        altitudeKm: 1.6,
        when: DateTime.utc(2026, 1, 1),
      );

      expect(field.declinationDeg, closeTo(-24.89, 0.1));
      expect(field.inclinationDeg, closeTo(-62.65, 0.2));
      expect(field.horizontalIntensityNT, closeTo(12662, 5));
      expect(field.totalIntensityNT, closeTo(27563, 5));
      expect(field.inBlackoutZone, isFalse);
      expect(field.isWest, isTrue);
      expect(field.declinationUncertaintyDeg, closeTo(0.46, 0.05));
    });

    test('horizontal intensity is sqrt(X^2 + Y^2)', () {
      final MagneticField field = Wmm2025.field(
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
        altitudeKm: 1.75,
        when: DateTime.utc(2027, 3, 15),
      );
      final double h = math.sqrt(
        field.northComponentNT * field.northComponentNT +
            field.eastComponentNT * field.eastComponentNT,
      );
      expect(field.horizontalIntensityNT, closeTo(h, 1e-6));
    });
  });

  group('decimal years', () {
    test('1 Jan 2025 is 2025.0', () {
      expect(DecimalYear.fromDateTime(DateTime.utc(2025, 1, 1)),
          closeTo(2025.0, 1e-9));
    });

    test('mid-year is about .5', () {
      expect(DecimalYear.fromDateTime(DateTime.utc(2025, 7, 2, 12)),
          closeTo(2025.5, 0.01));
    });

    test('the end of a year approaches the next integer', () {
      final double value =
          DecimalYear.fromDateTime(DateTime.utc(2026, 12, 31, 23, 59));
      expect(value, closeTo(2027, 0.001));
    });

    test('round trips through toDateTime', () {
      const double year = 2027.25;
      final DateTime back = DecimalYear.toDateTime(year);
      expect(DecimalYear.fromDateTime(back), closeTo(year, 1e-6));
    });
  });
}
