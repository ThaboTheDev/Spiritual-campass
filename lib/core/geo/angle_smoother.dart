import 'dart:math' as math;

import 'coordinates.dart';

/// Shortest-arc, time-based smoothing. The same time constant behaves alike
/// at 15, 25 and 50 Hz. Large genuine turns use a faster time constant.
class AngleSmoother {
  AngleSmoother({
    this.timeConstant = const Duration(milliseconds: 140),
    this.turnTimeConstant = const Duration(milliseconds: 60),
    this.fastTurnThresholdDeg = 45,
    this.resetAfter = const Duration(seconds: 1),
  });

  final Duration timeConstant;
  final Duration turnTimeConstant;
  final double fastTurnThresholdDeg;
  final Duration resetAfter;

  double? _value;
  DateTime? _lastSample;

  double? get value => _value;
  bool get hasValue => _value != null;

  double push(double sample, {DateTime? timestamp}) {
    if (!sample.isFinite) {
      return _value ?? double.nan;
    }
    final DateTime at = timestamp ?? DateTime.now();
    final double? current = _value;
    final DateTime? last = _lastSample;
    if (current == null || last == null || at.difference(last) > resetAfter) {
      _lastSample = at;
      return _value = Angles.normalize360(sample);
    }
    final int elapsed = at.difference(last).inMicroseconds;
    if (elapsed <= 0) {
      return current; // duplicate / out-of-order samples do not move the filter
    }
    _lastSample = at;
    final double delta = Angles.normalize180(sample - current);
    final Duration tau = delta.abs() > fastTurnThresholdDeg
        ? turnTimeConstant
        : timeConstant;
    final double alpha = tau.inMicroseconds <= 0
        ? 1
        : 1 - math.exp(-elapsed / tau.inMicroseconds);
    return _value = Angles.normalize360(current + alpha * delta);
  }

  void reset() {
    _value = null;
    _lastSample = null;
  }
}

/// A strict repaint budget. Fast turns must not bypass the low-end FPS cap.
/// Sensor fusion and quality evaluation run BEFORE this presentation throttle.
class HeadingThrottle {
  HeadingThrottle({this.minInterval = const Duration(milliseconds: 33)});

  final Duration minInterval;
  DateTime? _lastEmit;

  bool shouldEmit(double value, {DateTime? now}) {
    if (!value.isFinite) {
      return false;
    }
    final DateTime timestamp = now ?? DateTime.now();
    final DateTime? last = _lastEmit;
    if (last != null && timestamp.difference(last) < minInterval) {
      return false;
    }
    _lastEmit = timestamp;
    return true;
  }

  void reset() => _lastEmit = null;
}
