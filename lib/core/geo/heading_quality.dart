import 'dart:math' as math;

import '../wmm/wmm.dart';
import 'coordinates.dart';
import 'heading_math.dart';

/// A north reference is part of a reading, not an assumption about a plugin.
enum NorthReference { magnetic, trueNorth, relative }

/// Calibration status, NOT an error expressed in degrees.
enum SensorReliability { unknown, unreliable, low, medium, high }

enum HeadingConfidence { unreliable, uncertain, reliable }

/// The most actionable reason a direction cannot be trusted.
enum HeadingIssue {
  none,
  accuracyUnknown,
  calibrationRequired,
  magneticInterference,
  excessiveMotion,
  holdLevel,
  stale,
  gyroDrift,
  weakMagneticField,
  modelExpired,
  waitingForMovement,
}

class HeadingAssessment {
  const HeadingAssessment(this.confidence, this.issue);

  static const HeadingAssessment unknown = HeadingAssessment(
    HeadingConfidence.uncertain,
    HeadingIssue.accuracyUnknown,
  );
  static const HeadingAssessment reliable = HeadingAssessment(
    HeadingConfidence.reliable,
    HeadingIssue.none,
  );

  final HeadingConfidence confidence;
  final HeadingIssue issue;

  bool get isUsable => confidence != HeadingConfidence.unreliable;
}

/// Conservative magnetic diagnostics. These detect some disturbances, not all
/// systematic biases: even a plausible field magnitude can point the wrong way.
/// Raw and fused headings from the same magnetometer are not independent fixes.
class MagneticQualityMonitor {
  DateTime? _lastTime;
  double? _lastStrength;
  double? _lastHeading;

  HeadingAssessment assess({
    required DateTime timestamp,
    required double? headingDeg,
    required SensorReliability reliability,
    double? accuracyDeg,
    Vector3? magneticMicrotesla,
    Vector3? gravity,
    Vector3? linearAcceleration,
    Vector3? gyroscope,
    MagneticField? expectedField,
    bool modelValid = true,
    bool assumedFlat = false,
  }) {
    if (headingDeg == null || !headingDeg.isFinite) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.holdLevel,
      );
    }

    if (modelValid && (expectedField?.inBlackoutZone ?? false)) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.weakMagneticField,
      );
    }
    final DateTime? last = _lastTime;
    final double dt = last == null
        ? 0
        : timestamp.difference(last).inMicroseconds / 1e6;
    final double? previousStrength = _lastStrength;
    final double? previousHeading = _lastHeading;
    final double? strength = magneticMicrotesla?.length;
    _lastTime = timestamp;
    _lastHeading = headingDeg;
    _lastStrength = strength;

    if (magneticMicrotesla != null) {
      if (!magneticMicrotesla.isUsable ||
          strength == null ||
          strength < 10 ||
          strength > 100) {
        return const HeadingAssessment(
          HeadingConfidence.unreliable,
          HeadingIssue.magneticInterference,
        );
      }
      if (expectedField != null && modelValid) {
        final double expected = expectedField.totalIntensityNT / 1000;
        if ((strength - expected).abs() > math.max(12, expected * 0.30)) {
          return const HeadingAssessment(
            HeadingConfidence.unreliable,
            HeadingIssue.magneticInterference,
          );
        }
      }
      if (gravity != null && gravity.isUsable) {
        final double horizontal = magneticMicrotesla
            .cross(gravity.normalized())
            .length;
        if (horizontal < 2 || (expectedField?.inBlackoutZone ?? false)) {
          return const HeadingAssessment(
            HeadingConfidence.unreliable,
            HeadingIssue.weakMagneticField,
          );
        }
      }
      if (dt > 0 &&
          dt < 0.5 &&
          previousStrength != null &&
          (strength - previousStrength).abs() > 12) {
        return const HeadingAssessment(
          HeadingConfidence.unreliable,
          HeadingIssue.magneticInterference,
        );
      }
    }

    // Only compare heading changes when the phone's measured rotation is
    // small. A genuine quick turn must not be mistaken for interference.
    if (dt > 0 &&
        dt < 0.25 &&
        previousHeading != null &&
        gyroscope != null &&
        gyroscope.x.isFinite &&
        gyroscope.y.isFinite &&
        gyroscope.z.isFinite &&
        gyroscope.length < 0.15 &&
        Angles.difference(headingDeg, previousHeading) > 25) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.magneticInterference,
      );
    }

    if ((gravity != null && !gravity.isUsable) ||
        (gyroscope != null &&
            (!gyroscope.x.isFinite ||
                !gyroscope.y.isFinite ||
                !gyroscope.z.isFinite)) ||
        (linearAcceleration != null &&
            (!linearAcceleration.x.isFinite ||
                !linearAcceleration.y.isFinite ||
                !linearAcceleration.z.isFinite ||
                linearAcceleration.length > 3))) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.excessiveMotion,
      );
    }
    if (reliability == SensorReliability.unreliable ||
        (accuracyDeg != null && (!accuracyDeg.isFinite || accuracyDeg < 0))) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.calibrationRequired,
      );
    }
    if (accuracyDeg != null && accuracyDeg > 30) {
      return const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.calibrationRequired,
      );
    }
    if (!modelValid) {
      return const HeadingAssessment(
        HeadingConfidence.uncertain,
        HeadingIssue.modelExpired,
      );
    }
    if (expectedField?.inCautionZone ?? false) {
      return const HeadingAssessment(
        HeadingConfidence.uncertain,
        HeadingIssue.weakMagneticField,
      );
    }
    if (assumedFlat) {
      return const HeadingAssessment(
        HeadingConfidence.uncertain,
        HeadingIssue.holdLevel,
      );
    }
    if (reliability == SensorReliability.low ||
        reliability == SensorReliability.medium ||
        (accuracyDeg != null && accuracyDeg > 10)) {
      return const HeadingAssessment(
        HeadingConfidence.uncertain,
        HeadingIssue.calibrationRequired,
      );
    }
    // A vendor's HIGH status alone is not a measured angular error bound.
    // A zero-error vendor value is not evidence of a physically perfect sensor.
    if (accuracyDeg == null ||
        accuracyDeg == 0 ||
        reliability == SensorReliability.unknown) {
      return HeadingAssessment.unknown;
    }
    return HeadingAssessment.reliable;
  }

  void reset() {
    _lastTime = null;
    _lastStrength = null;
    _lastHeading = null;
  }
}
