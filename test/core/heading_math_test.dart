import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';

/// Magnetic field in Johannesburg, roughly: horizontal component pointing
/// north and a steep downward vertical component (inclination about -63°).
/// Android device frame: x right, y top, z out of the screen; the
/// accelerometer reads +9.81 on the axis that points up.
Vector3 _fieldFor({required double headingDeg, required bool upright}) {
  const double h = 15, v = -30; // µT: north, up (negative = down)
  final double t = headingDeg * math.pi / 180;
  // Facing direction d = (sin t, cos t, 0) in (E, N, U); right = (cos t, -sin t, 0).
  final double fx = -h * math.sin(t); // F · right
  final double alongFacing = h * math.cos(t); // F · d
  if (!upright) {
    // Flat: y = d, z = up.
    return Vector3(fx, alongFacing, v);
  }
  // Upright, screen towards the user: y = up, z = -d.
  return Vector3(fx, v, -alongFacing);
}

void main() {
  group('tiltCompensatedHeading', () {
    const Vector3 flatGravity = Vector3(0, 0, 9.81);

    test('flat, top edge north → 0°', () {
      final double? heading = HeadingMath.tiltCompensatedHeading(
        flatGravity,
        _fieldFor(headingDeg: 0, upright: false),
      );
      expect(heading, isNotNull);
      expect(heading!, closeTo(0, 0.5));
    });

    test('flat, top edge east → 90°', () {
      final double? heading = HeadingMath.tiltCompensatedHeading(
        flatGravity,
        _fieldFor(headingDeg: 90, upright: false),
      );
      expect(heading!, closeTo(90, 0.5));
    });

    test('flat, top edge south-west → 225°', () {
      final double? heading = HeadingMath.tiltCompensatedHeading(
        flatGravity,
        _fieldFor(headingDeg: 225, upright: false),
      );
      expect(heading!, closeTo(225, 0.5));
    });

    test('upright, back of phone facing east → 90°', () {
      // Upright: gravity along +y (top of phone points up).
      const Vector3 uprightGravity = Vector3(0, 9.81, 0);
      final double? heading = HeadingMath.tiltCompensatedHeading(
        uprightGravity,
        _fieldFor(headingDeg: 90, upright: true),
      );
      expect(heading!, closeTo(90, 0.5));
    });

    test('rejects an unusable vector', () {
      expect(
        HeadingMath.tiltCompensatedHeading(
          const Vector3(0, 0, 0),
          _fieldFor(headingDeg: 0, upright: false),
        ),
        isNull,
      );
    });

    test('field parallel to gravity has no answer', () {
      expect(
        HeadingMath.tiltCompensatedHeading(
          flatGravity,
          const Vector3(0, 0, -40),
        ),
        isNull,
      );
    });
  });

  group('facing helpers', () {
    test('headingFromEuler flat north', () {
      expect(HeadingMath.headingFromEuler(0, 0, 0), closeTo(0, 1e-6));
    });

    test('headingFromQuat identity', () {
      expect(HeadingMath.headingFromQuat(0, 0, 0, 1), closeTo(0, 1e-6));
    });

    test('magneticToTrue adds declination (west negative)', () {
      expect(HeadingMath.magneticToTrue(10, -20), closeTo(350, 1e-9));
    });

    test('yaw rate sign: clockwise seen from above increases heading', () {
      // Gyro reports a rotation about +z (anticlockwise seen from above when
      // the screen faces up), which must *decrease* the heading.
      final double rate = HeadingMath.yawRateDegPerSec(
        const Vector3(0, 0, 1),
        const Vector3(0, 0, 9.81),
      );
      expect(rate, lessThan(0));
      expect(rate.abs(), closeTo(57.2958, 0.01));
    });
  });

  group('Attitude', () {
    test('flat within 8°', () {
      final Attitude a = Attitude.fromAccelerometer(const Vector3(0.5, 0.5, 9.7));
      expect(a.isFlat, isTrue);
    });

    test('tilted beyond 8°', () {
      final Attitude a = Attitude.fromAccelerometer(const Vector3(0, 4, 8.9));
      expect(a.isFlat, isFalse);
    });
  });
}
