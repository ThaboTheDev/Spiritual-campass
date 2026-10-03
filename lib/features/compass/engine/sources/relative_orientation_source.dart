import 'dart:async';

import '../../../../core/geo/coordinates.dart';
import '../../../../core/geo/heading_math.dart';
import '../../../../services/motion_sensors.dart';
import '../heading_source.dart';

/// How the relative heading was anchored to the world.
enum CalibrationAnchor {
  /// The user pointed the phone at the sun: the offset yields *true* headings.
  sun,

  /// The user pointed the phone at (magnetic) north with a hand compass: the
  /// offset yields *magnetic* headings and declination still applies.
  north,
}

/// The one-tap calibration of the relative source. Shared between the source
/// (which applies it) and the controller (which sets it).
class RelativeCalibration {
  double? _offsetDeg;
  CalibrationAnchor? _anchor;
  double? _latestRelativeDeg;

  /// The current offset in degrees, or `null` while uncalibrated.
  double? get offsetDeg => _offsetDeg;

  /// What the offset was anchored to.
  CalibrationAnchor? get anchor => _anchor;

  /// Whether a "Set" has been done.
  bool get isCalibrated => _offsetDeg != null;

  /// Whether calibrated headings are true north (sun) or magnetic (north).
  bool get isTrueNorth => _anchor == CalibrationAnchor.sun;

  /// The most recent raw relative heading, needed to compute an offset.
  double? get latestRelativeDeg => _latestRelativeDeg;

  /// Anchors the current relative heading to [targetHeadingDeg].
  ///
  /// Returns `false` when no relative heading has been seen yet (the gyro has
  /// not produced anything), in which case nothing changes.
  bool set(double targetHeadingDeg, CalibrationAnchor anchor) {
    final double? relative = _latestRelativeDeg;
    if (relative == null) {
      return false;
    }
    _offsetDeg = HeadingMath.calibrationOffset(
      targetHeadingDeg: targetHeadingDeg,
      relativeHeadingDeg: relative,
    );
    _anchor = anchor;
    return true;
  }

  /// Forgets the calibration (e.g. after the sensors restart).
  void clear() {
    _offsetDeg = null;
    _anchor = null;
  }

  /// Records the latest raw relative heading (called by the source on every
  /// gyroscope integration step; public so tests can drive it).
  void observe(double relativeDeg) => _latestRelativeDeg = relativeDeg;
}

/// Rung 3: turn tracking from the gyroscope, made absolute by a one-tap
/// calibration.
///
/// The gyroscope only knows *how much* the phone has turned, not where north
/// is. Until the user taps "Set" the source emits *provisional* samples (so
/// the ladder keeps it and the UI shows the two Set buttons); after that it
/// emits absolute headings, true or magnetic depending on the anchor.
///
/// Gravity comes from the accelerometer (so yaw is measured about the real
/// vertical whatever the tilt); without an accelerometer the phone is assumed
/// flat.
class RelativeOrientationSource implements HeadingSource {
  RelativeOrientationSource(
    this._sensors,
    this.calibration, {
    this.gravityAlpha = 0.25,
    this.maxStepSeconds = 0.25,
  });

  final MotionSensors _sensors;

  /// The shared calibration.
  final RelativeCalibration calibration;

  /// Low-pass factor for the gravity estimate.
  final double gravityAlpha;

  /// Longest time step integrated in one go; larger gaps (app paused) are
  /// dropped instead of producing a wild jump.
  final double maxStepSeconds;

  /// A gyroscope-only heading is good to a few degrees for a minute or two
  /// after calibration, then drifts.
  static const double calibratedAccuracyDeg = 10.0;

  @override
  HeadingSourceKind get kind => HeadingSourceKind.relativeCalibrated;

  @override
  Duration? get acquireTimeout => null;

  @override
  Duration? get staleTimeout => null;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<HeadingSample> start() {
    late final StreamController<HeadingSample> controller;
    StreamSubscription<MotionSample>? accSub;
    StreamSubscription<MotionSample>? gyroSub;
    Vector3? gravity;
    DateTime? last;
    double relative = 0;

    void onGyroscope(MotionSample sample) {
      final DateTime? previous = last;
      last = sample.timestamp;
      if (previous == null) {
        // First sample: establish the time base and announce ourselves.
        calibration.observe(relative);
        controller.add(_sample(relative, sample.timestamp));
        return;
      }
      final double dt =
          sample.timestamp.difference(previous).inMicroseconds / 1e6;
      if (dt <= 0 || dt > maxStepSeconds) {
        return;
      }
      final Vector3 g = gravity ?? const Vector3(0, 0, 9.81);
      final double rate = HeadingMath.yawRateDegPerSec(sample.vector, g);
      relative = Angles.normalize360(relative + rate * dt);
      calibration.observe(relative);
      controller.add(_sample(relative, sample.timestamp));
    }

    controller = StreamController<HeadingSample>(
      onListen: () {
        accSub = _sensors.accelerometer().listen(
          (MotionSample sample) {
            final Vector3? current = gravity;
            if (!sample.vector.isUsable) {
              return;
            }
            gravity = current == null
                ? sample.vector
                : current + (sample.vector - current) * gravityAlpha;
          },
          onError: (Object _, StackTrace __) => gravity = null,
          cancelOnError: true,
        );
        gyroSub = _sensors.gyroscope().listen(
          onGyroscope,
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: true,
        );
      },
      onCancel: () async {
        await accSub?.cancel();
        await gyroSub?.cancel();
      },
    );
    return controller.stream;
  }

  HeadingSample _sample(double relativeDeg, DateTime at) {
    final double? offset = calibration.offsetDeg;
    if (offset == null) {
      return HeadingSample(
        headingDeg: relativeDeg,
        isTrueNorth: false,
        timestamp: at,
        isProvisional: true,
      );
    }
    return HeadingSample(
      headingDeg: HeadingMath.applyOffset(relativeDeg, offset),
      isTrueNorth: calibration.isTrueNorth,
      timestamp: at,
      accuracyDeg: calibratedAccuracyDeg,
    );
  }
}
