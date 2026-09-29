import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/sun/facing_sun.dart';
import 'package:tshk_compass/core/sun/sun_position.dart';

void main() {
  group('solar declination', () {
    test('June solstice is +23.44 degrees', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2025, 6, 21, 12),
        latitudeDeg: 0,
        longitudeDeg: 0,
      );
      expect(sun.declinationDeg, closeTo(23.438, 0.05));
    });

    test('December solstice is -23.44 degrees', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2025, 12, 21, 12),
        latitudeDeg: 0,
        longitudeDeg: 0,
      );
      expect(sun.declinationDeg, closeTo(-23.438, 0.05));
    });

    test('the equinoxes are near zero', () {
      final SunPosition march = SunCalculator.calculate(
        at: DateTime.utc(2025, 3, 20, 12),
        latitudeDeg: 0,
        longitudeDeg: 0,
      );
      final SunPosition september = SunCalculator.calculate(
        at: DateTime.utc(2025, 9, 23, 12),
        latitudeDeg: 0,
        longitudeDeg: 0,
      );
      expect(march.declinationDeg, closeTo(0, 0.5));
      expect(september.declinationDeg, closeTo(0, 0.5));
    });
  });

  group('equation of time', () {
    double equationOfTime(int month, int day) {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2025, month, day, 12),
        latitudeDeg: 0,
        longitudeDeg: 0,
      );
      return sun.equationOfTimeMinutes;
    }

    test('matches the published annual curve', () {
      // Standard published values, in minutes.
      expect(equationOfTime(2, 11), closeTo(-14.2, 0.5));
      expect(equationOfTime(5, 14), closeTo(3.7, 0.5));
      expect(equationOfTime(7, 26), closeTo(-6.4, 0.5));
      expect(equationOfTime(11, 3), closeTo(16.4, 0.5));
      expect(equationOfTime(4, 15), closeTo(0, 0.5));
      expect(equationOfTime(12, 25), closeTo(0, 0.5));
    });
  });

  group('solar noon', () {
    test('the highest point of the day is 90 - |latitude - declination|', () {
      // Walking the whole day and taking the maximum avoids having to know the
      // exact time of solar noon (which the equation of time shifts by up to
      // a quarter of an hour).
      const List<List<double>> places = <List<double>>[
        <double>[-33.9249, 18.4241], // Cape Town
        <double>[-26.2041, 28.0473], // Johannesburg
        <double>[0.0, 0.0], // equator
        <double>[40.0, 0.0],
        <double>[52.5, 13.4], // Berlin
      ];
      for (final List<double> place in places) {
        final double lat = place[0];
        final double lon = place[1];

        SunPosition? highest;
        for (int minute = 0; minute < 24 * 60; minute++) {
          final SunPosition sun = SunCalculator.calculate(
            at: DateTime.utc(2025, 3, 20).add(Duration(minutes: minute)),
            latitudeDeg: lat,
            longitudeDeg: lon,
          );
          if (highest == null || sun.elevationDeg > highest.elevationDeg) {
            highest = sun;
          }
        }

        final double expected = 90 - (lat - highest!.declinationDeg).abs();
        expect(highest.elevationDeg, closeTo(expected, 0.15),
            reason: 'peak elevation at $lat, $lon');
      }
    });

    test('the noon sun is north of a southern observer and south of a northern one',
        () {
      // Solar noon in Johannesburg (28.05 deg east) is about 10:08 UTC.
      final SunPosition southNoon = SunCalculator.calculate(
        at: DateTime.utc(2025, 6, 21, 10, 8),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      final SunPosition northNoon = SunCalculator.calculate(
        at: DateTime.utc(2025, 6, 21, 12, 0),
        latitudeDeg: 40.0,
        longitudeDeg: 0,
      );
      // The same instant, 12:00 UTC, is well past noon in Johannesburg.
      final SunPosition southAfternoon = SunCalculator.calculate(
        at: DateTime.utc(2025, 6, 21, 12, 0),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );

      expect(Angles.difference(southNoon.azimuthDeg, 0), lessThan(3),
          reason: 'southern observer: the noon sun lies to the north');
      expect(Angles.difference(northNoon.azimuthDeg, 180), lessThan(3),
          reason: 'northern observer: the noon sun lies to the south');
      expect(southNoon.hourAngleDeg.abs(), lessThan(1));
      expect(northNoon.hourAngleDeg.abs(), lessThan(1));
      expect(southAfternoon.hourAngleDeg, greaterThan(20));
    });
  });

  group('day and night', () {
    test('the sun never rises at 70N on 21 December', () {
      for (int hour = 0; hour < 24; hour++) {
        final SunPosition sun = SunCalculator.calculate(
          at: DateTime.utc(2025, 12, 21, hour),
          latitudeDeg: 70,
          longitudeDeg: 0,
        );
        expect(sun.isAboveHorizon, isFalse, reason: 'hour $hour');
      }
    });

    test('the sun never sets at 70S on 21 December', () {
      for (int hour = 0; hour < 24; hour++) {
        final SunPosition sun = SunCalculator.calculate(
          at: DateTime.utc(2025, 12, 21, hour),
          latitudeDeg: -70,
          longitudeDeg: 0,
        );
        expect(sun.isAboveHorizon, isTrue, reason: 'hour $hour');
      }
    });

    test('Johannesburg gets about 12 hours of daylight at the equinox', () {
      int hoursAbove = 0;
      for (int minute = 0; minute < 24 * 60; minute += 10) {
        final SunPosition sun = SunCalculator.calculate(
          at: DateTime.utc(2026, 3, 20).add(Duration(minutes: minute)),
          latitudeDeg: -26.2041,
          longitudeDeg: 28.0473,
        );
        if (sun.isAboveHorizon) {
          hoursAbove++;
        }
      }
      final double hours = hoursAbove * 10 / 60.0;
      expect(hours, closeTo(12, 0.5));
    });
  });

  group('azimuth and shadow', () {
    test('morning sun is in the east and afternoon sun in the west', () {
      const double latitude = -26.2041;
      const double longitude = 28.0473;

      final SunPosition morning = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 6),
        latitudeDeg: latitude,
        longitudeDeg: longitude,
      );
      final SunPosition afternoon = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 14),
        latitudeDeg: latitude,
        longitudeDeg: longitude,
      );

      expect(morning.azimuthDeg > 45.0 && morning.azimuthDeg < 110.0, isTrue,
          reason: 'morning azimuth was ${morning.azimuthDeg}');
      expect(afternoon.azimuthDeg > 250.0 && afternoon.azimuthDeg < 330.0,
          isTrue,
          reason: 'afternoon azimuth was ${afternoon.azimuthDeg}');
    });

    test('a shadow points directly away from the sun', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 7),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      expect(sun.shadowBearingDeg,
          closeTo(Angles.normalize360(sun.azimuthDeg + 180), 1e-9));
      expect(Angles.difference(sun.shadowBearingDeg, sun.azimuthDeg),
          closeTo(180, 1e-9));
    });

    test('no shadow reading when the sun is below the horizon', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 20),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      expect(sun.isAboveHorizon, isFalse);
      expect(sun.castsShadow, isFalse);
    });
  });

  group('facing the sun', () {
    test('ahead when the heading is within 20 degrees', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 7),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      final FacingSunResult result = FacingSun.evaluate(
        headingDeg: sun.azimuthDeg + 10,
        sun: sun,
      );
      expect(result.facing, SunFacing.ahead);
      expect(result.turnDeg, closeTo(10, 1e-6));
    });

    test('behind when the sun is more than 160 degrees away', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 7),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      final FacingSunResult result = FacingSun.evaluate(
        headingDeg: sun.azimuthDeg + 175,
        sun: sun,
      );
      expect(result.facing, SunFacing.behind);
    });

    test('left and right are reported with the correct sign', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 7),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      final FacingSunResult right = FacingSun.evaluate(
        headingDeg: Angles.normalize360(sun.azimuthDeg - 60),
        sun: sun,
      );
      final FacingSunResult left = FacingSun.evaluate(
        headingDeg: Angles.normalize360(sun.azimuthDeg + 60),
        sun: sun,
      );
      expect(right.facing, SunFacing.right);
      expect(right.deltaDeg, greaterThan(0));
      expect(left.facing, SunFacing.left);
      expect(left.deltaDeg, lessThan(0));
    });

    test('unknown without a heading', () {
      final SunPosition sun = SunCalculator.calculate(
        at: DateTime.utc(2026, 9, 29, 7),
        latitudeDeg: -26.2041,
        longitudeDeg: 28.0473,
      );
      final FacingSunResult result =
          FacingSun.evaluate(headingDeg: null, sun: sun);
      expect(result.facing, SunFacing.unknown);
      expect(result.hasHeading, isFalse);
    });
  });
}
