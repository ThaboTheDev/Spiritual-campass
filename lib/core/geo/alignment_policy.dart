import 'coordinates.dart';
import 'geo_math.dart';
import 'heading_quality.dart';

/// Shared by Compass and Msamo. A nominal on-screen coincidence is not proof
/// of ±3° accuracy. Require reported uncertainty, fresh location, stable sensor
/// data and a consistent true-north frame. GPS course / user-anchored gyro
/// headings can never confirm where the phone is pointing.
abstract final class AlignmentPolicy {
  static const double toleranceDeg = 3;
  static const Duration settleTime = Duration(seconds: 1);

  static bool confirms({
    required double? trueHeadingDeg,
    required double? headingUncertaintyDeg,
    required HeadingConfidence confidence,
    required DateTime? headingAt,
    required DateTime? stableSince,
    required DateTime now,
    required TargetReading? target,
    bool travelDirection = false,
    bool relativeHeading = false,
    bool paused = false,
    bool stale = false,
    double? bearingOverride,
  }) {
    final double? targetError = target?.bearingUncertaintyAt(now);
    if (trueHeadingDeg == null ||
        !trueHeadingDeg.isFinite ||
        headingUncertaintyDeg == null ||
        !headingUncertaintyDeg.isFinite ||
        headingUncertaintyDeg <= 0 ||
        confidence != HeadingConfidence.reliable ||
        headingAt == null ||
        stableSince == null ||
        target == null ||
        !target.locationReliable ||
        target.isNearTarget ||
        targetError == null ||
        !targetError.isFinite ||
        targetError < 0 ||
        target.isApproximate ||
        travelDirection ||
        relativeHeading ||
        paused ||
        stale) {
      return false;
    }
    final DateTime? locationAt = target.locationAt;
    if (locationAt != null &&
        (now.difference(locationAt) > const Duration(seconds: 3) ||
            now.difference(locationAt) < const Duration(milliseconds: -250))) {
      return false;
    }
    final Duration age = now.difference(headingAt);
    if (age.isNegative ||
        age > const Duration(milliseconds: 250) ||
        now.difference(stableSince) < settleTime) {
      return false;
    }
    final double bearing = bearingOverride ?? target.bearingDeg;
    // A frozen direction must still agree with the current target bearing.
    if (!target.bearingDeg.isFinite ||
        !bearing.isFinite ||
        Angles.difference(bearing, target.bearingDeg) > toleranceDeg) {
      return false;
    }
    final double budget = headingUncertaintyDeg + targetError;
    // The saved mark must not consume an unaccounted part of the error budget.
    // Confirm both the displayed mark and the actual live destination.
    return Angles.difference(trueHeadingDeg, bearing) + budget <=
            toleranceDeg &&
        Angles.difference(trueHeadingDeg, target.bearingDeg) + budget <=
            toleranceDeg;
  }
}
