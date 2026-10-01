import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';

void main() {
  test('integrates all axes and normalizes quaternions', () {
    final Quaternion yaw = Quaternion.rotation(
      const Vector3(0, 0, -math.pi / 2),
    );
    final Quaternion pitch = Quaternion.rotation(
      const Vector3(math.pi / 3, 0, 0),
    );
    final Quaternion q = (yaw * pitch).normalized();
    expect(HeadingMath.headingFromQuat(q.x, q.y, q.z, q.w), closeTo(90, 1e-8));
    expect(
      HeadingMath.headingFromQuat(q.x * 2, q.y * 2, q.z * 2, q.w * 2),
      closeTo(90, 1e-8),
    );
    final Vector3 roundTrip = q.conjugate.rotate(
      q.rotate(const Vector3(1, 2, 3)),
    );
    expect(roundTrip.x, closeTo(1, 1e-8));
    expect(roundTrip.y, closeTo(2, 1e-8));
    expect(roundTrip.z, closeTo(3, 1e-8));
  });
  test('device-to-Earth basis survives arbitrary tilt and remains level', () {
    const Vector3 gravity = Vector3(0, 4.903325, 8.49281);
    final Quaternion q = Quaternion.fromUp(gravity);
    final Vector3 up = q.rotate(gravity.normalized());
    expect(up.x, closeTo(0, 1e-6));
    expect(up.y, closeTo(0, 1e-6));
    expect(up.z, closeTo(1, 1e-6));
  });
  test('zero quaternion and ambiguous facing are unavailable, never north', () {
    expect(HeadingMath.headingFromQuat(0, 0, 0, 0).isFinite, isFalse);
    expect(HeadingMath.facing(0, 0, 0, 0, 0, 0, 0, 0, 0, 0).isFinite, isFalse);
  });
  test(
    'Core Motion north-west-up is converted to the shared east-north-up frame',
    () {
      // A flat phone with its screen top pointing north has right = east.
      // Core Motion (north,west,up)→device rows: [0,-1,0;1,0,0;0,0,1].
      const List<double> cm = [0, -1, 0, 1, 0, 0, 0, 0, 1];
      final List<double> enu = [
        -cm[1],
        -cm[4],
        -cm[7],
        cm[0],
        cm[3],
        cm[6],
        cm[2],
        cm[5],
        cm[8],
      ];
      final Quaternion q = Quaternion.fromMatrix(enu);
      expect(HeadingMath.headingFromQuat(q.x, q.y, q.z, q.w), closeTo(0, 1e-8));
    },
  );
}
