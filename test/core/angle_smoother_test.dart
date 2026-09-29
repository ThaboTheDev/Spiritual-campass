import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/angle_smoother.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';

void main() {
  group('AngleSmoother', () {
    test('the first sample is taken as-is', () {
      final AngleSmoother smoother = AngleSmoother(alpha: 0.2);
      expect(smoother.push(123), closeTo(123, 1e-9));
      expect(smoother.hasValue, isTrue);
    });

    test('moves towards the sample by alpha', () {
      final AngleSmoother smoother = AngleSmoother(alpha: 0.25);
      smoother.push(0);
      expect(smoother.push(100), closeTo(25, 1e-9));
      expect(smoother.push(100), closeTo(43.75, 1e-9));
    });

    test('crossing north takes the short way round', () {
      final AngleSmoother smoother = AngleSmoother(alpha: 0.5);
      smoother.push(359);
      // 359 -> 1 is +2 degrees, not -358.
      expect(smoother.push(1), closeTo(0, 1e-9));
      smoother.push(1);
      expect(smoother.value, closeTo(0.5, 1e-9));
    });

    test('never leaves the 0 - 360 range', () {
      final AngleSmoother smoother = AngleSmoother(alpha: 0.3);
      double value = 350;
      for (int i = 0; i < 200; i++) {
        value = smoother.push(value + 7);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(360));
      }
    });

    test('snaps to a sample that is further away than the threshold', () {
      final AngleSmoother smoother =
          AngleSmoother(alpha: 0.1, resetThresholdDeg: 90);
      smoother.push(0);
      expect(smoother.push(200), closeTo(200, 1e-9));
    });

    test('reset forgets the value', () {
      final AngleSmoother smoother = AngleSmoother();
      smoother.push(42);
      smoother.reset();
      expect(smoother.hasValue, isFalse);
      expect(smoother.push(7), closeTo(7, 1e-9));
    });
  });

  group('HeadingThrottle', () {
    test('emits the first value immediately', () {
      final HeadingThrottle throttle = HeadingThrottle();
      expect(throttle.shouldEmit(10, now: DateTime.utc(2026, 1, 1)), isTrue);
    });

    test('drops updates that arrive too soon and are tiny', () {
      final HeadingThrottle throttle = HeadingThrottle(
        minInterval: const Duration(milliseconds: 100),
        minDeltaDeg: 1,
      );
      final DateTime t0 = DateTime.utc(2026, 1, 1);
      expect(throttle.shouldEmit(10, now: t0), isTrue);
      expect(
        throttle.shouldEmit(10.1, now: t0.add(const Duration(milliseconds: 10))),
        isFalse,
      );
      // Enough time has passed, so the update goes through.
      expect(
        throttle.shouldEmit(10.1, now: t0.add(const Duration(milliseconds: 120))),
        isTrue,
      );
    });

    test('lets a large movement through straight away', () {
      final HeadingThrottle throttle = HeadingThrottle(
        minInterval: const Duration(milliseconds: 500),
        minDeltaDeg: 0.2,
      );
      final DateTime t0 = DateTime.utc(2026, 1, 1);
      throttle.shouldEmit(10, now: t0);
      expect(
        throttle.shouldEmit(40, now: t0.add(const Duration(milliseconds: 5))),
        isTrue,
      );
    });

    test('reset clears the history', () {
      final HeadingThrottle throttle = HeadingThrottle();
      final DateTime t0 = DateTime.utc(2026, 1, 1);
      throttle.shouldEmit(10, now: t0);
      throttle.reset();
      expect(throttle.shouldEmit(10, now: t0), isTrue);
    });
  });

  group('Angles helpers used by the throttle', () {
    test('difference across north is small', () {
      expect(Angles.difference(359, 1), closeTo(2, 1e-9));
    });
  });
}
