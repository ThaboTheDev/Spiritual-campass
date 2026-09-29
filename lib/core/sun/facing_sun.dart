import '../geo/coordinates.dart';
import 'sun_position.dart';

/// Which way the sun is relative to the direction the phone is pointing.
enum SunFacing {
  /// The phone is pointing at the sun (within [FacingSun.aheadThresholdDeg]).
  ahead,

  /// The sun is behind the phone.
  behind,

  /// The sun is to the right of the direction the phone points.
  right,

  /// The sun is to the left of the direction the phone points.
  left,

  /// No heading, so we cannot say.
  unknown,
}

/// The result of comparing the device heading with the sun's azimuth.
class FacingSunResult {
  const FacingSunResult({
    required this.facing,
    required this.deltaDeg,
    required this.hasHeading,
  });

  /// Which way the sun is.
  final SunFacing facing;

  /// Signed rotation from the direction the phone points to the sun:
  /// positive means "the sun is to your right".
  final double deltaDeg;

  /// Whether a heading was available.
  final bool hasHeading;

  /// Absolute angle you would turn to face the sun.
  double get turnDeg => deltaDeg.abs();
}

/// Decides whether the phone is facing the sun.
abstract final class FacingSun {
  /// How close the heading has to be to the sun's azimuth to count as "facing
  /// the sun".
  static const double aheadThresholdDeg = 20.0;

  /// Beyond this the sun counts as behind you.
  static const double behindThresholdDeg = 160.0;

  /// Compares the [headingDeg] (a true heading) with [sun].
  static FacingSunResult evaluate({
    required double? headingDeg,
    required SunPosition sun,
  }) {
    if (headingDeg == null || headingDeg.isNaN) {
      return const FacingSunResult(
        facing: SunFacing.unknown,
        deltaDeg: 0.0,
        hasHeading: false,
      );
    }
    final double delta = Angles.shortestDelta(headingDeg, sun.azimuthDeg);
    final SunFacing facing;
    if (delta.abs() <= aheadThresholdDeg) {
      facing = SunFacing.ahead;
    } else if (delta.abs() >= behindThresholdDeg) {
      facing = SunFacing.behind;
    } else if (delta > 0) {
      facing = SunFacing.right;
    } else {
      facing = SunFacing.left;
    }
    return FacingSunResult(
      facing: facing,
      deltaDeg: delta,
      hasHeading: true,
    );
  }
}
