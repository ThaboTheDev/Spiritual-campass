import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/sun/sun_position.dart';

void main() {
  SunPosition sun(double elevation) => SunPosition(
    azimuthDeg: 90,
    elevationDeg: elevation,
    declinationDeg: 0,
    equationOfTimeMinutes: 0,
    hourAngleDeg: 0,
    at: DateTime.utc(2026, 1, 1),
  );
  test('night, horizon and overhead azimuth are not calibration anchors', () {
    expect(sun(-1).canAnchorHeading, isFalse);
    expect(sun(1).canAnchorHeading, isFalse);
    expect(sun(90).canAnchorHeading, isFalse);
    expect(sun(90).castsShadow, isFalse);
    expect(sun(40).canAnchorHeading, isTrue);
  });
}
