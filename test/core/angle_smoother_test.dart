import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/angle_smoother.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 1, 1);
  group('time-based angle smoothing', () {
    test('first value is immediate', () {
      final AngleSmoother s = AngleSmoother();
      expect(s.push(123, timestamp: t0), 123);
    });
    test('uses elapsed time and takes the shortest arc across north', () {
      final AngleSmoother s = AngleSmoother();
      s.push(359, timestamp: t0);
      final double alpha = 1 - math.exp(-40 / 140);
      expect(
        s.push(1, timestamp: t0.add(const Duration(milliseconds: 40))),
        closeTo(Angles.normalize360(359 + 2 * alpha), 1e-9),
      );
    });
    test('15, 25 and 50 Hz have the same settling behavior', () {
      double run(int periodMs) {
        final AngleSmoother s = AngleSmoother();
        s.push(0, timestamp: t0);
        for (int ms = periodMs; ms <= 1000; ms += periodMs) {
          s.push(10, timestamp: t0.add(Duration(milliseconds: ms)));
        }
        return s.value!;
      }

      expect(run(40), closeTo(run(20), 1e-9));
      expect(run(66), closeTo(10 * (1 - math.exp(-990 / 140)), 1e-9));
    });
    test(
      'big turns follow faster, but a single gap does not spin catch-up',
      () {
        final AngleSmoother fast = AngleSmoother();
        final AngleSmoother slow = AngleSmoother(
          turnTimeConstant: const Duration(milliseconds: 140),
        );
        fast.push(0, timestamp: t0);
        slow.push(0, timestamp: t0);
        final DateTime next = t0.add(const Duration(milliseconds: 40));
        expect(
          fast.push(90, timestamp: next),
          greaterThan(slow.push(90, timestamp: next)),
        );
        expect(
          fast.push(270, timestamp: t0.add(const Duration(seconds: 2))),
          270,
        );
      },
    );
    test('ignores invalid, duplicate and out-of-order samples', () {
      final AngleSmoother s = AngleSmoother();
      s.push(42, timestamp: t0);
      expect(s.push(double.nan, timestamp: t0), 42);
      expect(s.push(180, timestamp: t0), 42);
      expect(
        s.push(270, timestamp: t0.subtract(const Duration(seconds: 1))),
        42,
      );
      s.reset();
      expect(s.hasValue, isFalse);
      expect(s.push(7, timestamp: t0), 7);
    });
  });
  group('strict rendering budget', () {
    test('even a fast turn cannot bypass the low-end FPS cap', () {
      final HeadingThrottle t = HeadingThrottle(
        minInterval: const Duration(milliseconds: 66),
      );
      expect(t.shouldEmit(0, now: t0), isTrue);
      expect(
        t.shouldEmit(90, now: t0.add(const Duration(milliseconds: 5))),
        isFalse,
      );
      expect(
        t.shouldEmit(90, now: t0.add(const Duration(milliseconds: 66))),
        isTrue,
      );
    });
    test('stationary updates pass at the budget and invalid values do not', () {
      final HeadingThrottle t = HeadingThrottle();
      expect(t.shouldEmit(10, now: t0), isTrue);
      expect(
        t.shouldEmit(10, now: t0.add(const Duration(milliseconds: 33))),
        isTrue,
      );
      expect(
        t.shouldEmit(double.nan, now: t0.add(const Duration(seconds: 1))),
        isFalse,
      );
      t.reset();
      expect(t.shouldEmit(10, now: t0), isTrue);
    });
  });
}
