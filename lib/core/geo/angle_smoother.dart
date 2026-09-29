import 'coordinates.dart';

/// Exponential low-pass filter for angles that handles the 359° → 0° wrap.
///
/// A naive `smoothed += alpha * (raw - smoothed)` makes the needle spin the
/// long way round every time the heading crosses north. This filter rotates
/// towards the new sample along the *shortest* arc, using [Angles.normalize180],
/// which removes that artefact completely.
///
/// ```dart
/// final smoother = AngleSmoother(alpha: 0.2);
/// final smoothed = smoother.push(headingFromSensor);
/// ```
class AngleSmoother {
  AngleSmoother({this.alpha = 0.2, this.resetThresholdDeg = 90.0});

  /// How far to move towards each new sample, 0 .. 1.
  ///
  /// Small values are smoother but laggier; 0.15 - 0.25 feels right for a
  /// hand-held compass.
  final double alpha;

  /// When a sample is further away than this, the filter snaps to it instead of
  /// sweeping across. Stops the needle doing a slow full turn after the phone
  /// has been in a pocket or the screen has been off.
  final double resetThresholdDeg;

  double? _value;

  /// The current smoothed angle, or `null` before the first sample.
  double? get value => _value;

  /// Whether at least one sample has been accepted.
  bool get hasValue => _value != null;

  /// Feeds a new sample and returns the smoothed angle (0 .. 360).
  double push(double sample) {
    final double? current = _value;
    if (current == null) {
      _value = Angles.normalize360(sample);
      return _value!;
    }
    final double delta = Angles.normalize180(sample - current);
    if (delta.abs() > resetThresholdDeg) {
      _value = Angles.normalize360(sample);
    } else {
      _value = Angles.normalize360(current + alpha * delta);
    }
    return _value!;
  }

  /// Forgets the current value, e.g. when the compass is restarted.
  void reset() => _value = null;
}

/// Drops updates that arrive too close together, and updates that move the
/// needle by less than a threshold, so the UI is not rebuilt 60 times a second
/// for a tenth of a degree.
class HeadingThrottle {
  HeadingThrottle({
    this.minInterval = const Duration(milliseconds: 33),
    this.minDeltaDeg = 0.15,
  });

  /// Minimum time between accepted updates (~30 fps by default).
  final Duration minInterval;

  /// Minimum movement (degrees) that is accepted immediately, regardless of
  /// [minInterval], so fast turns still look smooth.
  final double minDeltaDeg;

  DateTime? _lastEmit;
  double? _lastValue;

  /// Returns `true` (and remembers the sample) when the UI should be updated.
  bool shouldEmit(double value, {DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    final DateTime? last = _lastEmit;
    final double? lastValue = _lastValue;
    if (last == null || lastValue == null) {
      _lastEmit = timestamp;
      _lastValue = value;
      return true;
    }
    final bool enoughTime =
        timestamp.difference(last).inMicroseconds >= minInterval.inMicroseconds;
    // A large jump is always let through so fast turns stay responsive.
    final bool bigMove = Angles.difference(lastValue, value) >= minDeltaDeg;
    if (bigMove || enoughTime) {
      _lastEmit = timestamp;
      _lastValue = value;
      return true;
    }
    return false;
  }

  /// Forgets the last emitted value.
  void reset() {
    _lastEmit = null;
    _lastValue = null;
  }
}
