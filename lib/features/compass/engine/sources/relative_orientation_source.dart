import 'dart:async';
import 'dart:math' as math;

import '../../../../core/geo/heading_math.dart';
import '../../../../core/geo/heading_quality.dart';
import '../../../../services/motion_sensors.dart';
import '../heading_source.dart';

enum CalibrationAnchor { sun, north }

/// An anchor belongs to ONE continuous tracking session. It is not persisted.
class RelativeCalibration {
  RelativeCalibration({
    DateTime Function()? now,
    this.validFor = const Duration(seconds: 60),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration validFor;
  double? _offsetDeg;
  CalibrationAnchor? _anchor;
  double? _latestRelativeDeg;
  DateTime? _observedAt;
  DateTime? _calibratedAt;
  bool _anchorable = false;

  double? get offsetDeg {
    _expire();
    return _offsetDeg;
  }

  CalibrationAnchor? get anchor {
    _expire();
    return _anchor;
  }

  bool get isCalibrated => offsetDeg != null;
  bool get isTrueNorth => anchor == CalibrationAnchor.sun;
  double? get latestRelativeDeg => _latestRelativeDeg;
  Duration? get age =>
      _calibratedAt == null ? null : _now().difference(_calibratedAt!);

  bool get canCalibrate =>
      _anchorable &&
      _latestRelativeDeg != null &&
      _observedAt != null &&
      _now().difference(_observedAt!).abs() <=
          const Duration(milliseconds: 500);

  bool set(double targetHeadingDeg, CalibrationAnchor anchor) {
    if (!canCalibrate || !targetHeadingDeg.isFinite) {
      return false;
    }
    _offsetDeg = HeadingMath.calibrationOffset(
      targetHeadingDeg: targetHeadingDeg,
      relativeHeadingDeg: _latestRelativeDeg!,
    );
    _anchor = anchor;
    _calibratedAt = _now();
    return true;
  }

  void clear() {
    _offsetDeg = null;
    _anchor = null;
    _calibratedAt = null;
  }

  /// Restart / pause / gap: the old relative origin no longer exists.
  void resetTracking() {
    clear();
    _latestRelativeDeg = null;
    _observedAt = null;
    _anchorable = false;
  }

  void observe(
    double relativeDeg, {
    DateTime? timestamp,
    bool anchorable = true,
  }) {
    if (!relativeDeg.isFinite) {
      _anchorable = false;
      return;
    }
    _latestRelativeDeg = relativeDeg;
    _observedAt = timestamp ?? _now();
    _anchorable = anchorable;
  }

  void _expire() {
    final Duration? elapsed = age;
    if (elapsed != null && (elapsed.isNegative || elapsed > validFor)) {
      clear();
    }
  }
}

/// Quaternion turn tracking with slow gravity correction and heuristic rest-based
/// gyro bias estimation. No north is inferred without a user anchor, and no
/// fixed ±10° accuracy is invented for it. Drift requires frequent re-anchoring.
class RelativeOrientationSource implements HeadingSource {
  RelativeOrientationSource(
    this._sensors,
    this.calibration, {
    this.samplingPeriod = const Duration(milliseconds: 40),
    this.screenAngleDeg = 0,
    this.maxStepSeconds = 0.25,
  });

  final MotionSensors _sensors;
  final RelativeCalibration calibration;
  final Duration samplingPeriod;
  final double screenAngleDeg;
  final double maxStepSeconds;

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
    calibration.resetTracking();
    late final StreamController<HeadingSample> controller;
    StreamSubscription<MotionSample>? accSub;
    StreamSubscription<MotionSample>? gyroSub;
    Vector3? gravity;
    Vector3? acceleration;
    Vector3? previousAcceleration;
    DateTime? gravityAt;
    DateTime? restSince;
    DateTime? last;
    Quaternion? orientation;
    Vector3 bias = const Vector3(0, 0, 0);
    bool accelerometerMissing = false;
    bool cancelled = false;

    void onGyroscope(MotionSample sample) {
      if (cancelled) {
        return;
      }
      if (!sample.vector.x.isFinite ||
          !sample.vector.y.isFinite ||
          !sample.vector.z.isFinite) {
        calibration.resetTracking();
        orientation = null;
        last = null;
        controller.add(
          HeadingSample(
            headingDeg: double.nan,
            isTrueNorth: false,
            timestamp: sample.timestamp,
            assessment: const HeadingAssessment(
              HeadingConfidence.unreliable,
              HeadingIssue.excessiveMotion,
            ),
          ),
        );
        return;
      }
      final DateTime? previous = last;
      if (previous != null && !sample.timestamp.isAfter(previous)) {
        return;
      }
      final double dt = previous == null
          ? 0
          : sample.timestamp.difference(previous).inMicroseconds / 1e6;
      last = sample.timestamp;
      final bool freshGravity =
          gravityAt != null &&
          sample.timestamp.difference(gravityAt!).abs() <
              const Duration(milliseconds: 500);
      if (!accelerometerMissing && !freshGravity) {
        calibration.resetTracking();
        orientation = null;
        controller.add(
          HeadingSample(
            headingDeg: 0,
            isTrueNorth: false,
            timestamp: sample.timestamp,
            isProvisional: true,
            assessment: const HeadingAssessment(
              HeadingConfidence.unreliable,
              HeadingIssue.stale,
            ),
          ),
        );
        return;
      }
      final Vector3 g = gravity ?? const Vector3(0, 0, 9.80665);
      if (dt > maxStepSeconds) {
        calibration.resetTracking();
        orientation = null;
        bias = const Vector3(0, 0, 0);
        restSince = null;
      }
      orientation ??= Quaternion.fromUp(g);
      final bool calm =
          freshGravity &&
          acceleration != null &&
          (acceleration!.length - 9.80665).abs() < 0.25 &&
          previousAcceleration != null &&
          (acceleration! - previousAcceleration!).length < 0.05 &&
          sample.vector.length < 0.01;
      if (calm) {
        restSince ??= sample.timestamp;
        if (sample.timestamp.difference(restSince!) >
                const Duration(seconds: 2) &&
            dt > 0 &&
            dt <= maxStepSeconds) {
          // Slow adaptation limits bias changes. Gravity alone cannot distinguish
          // extremely slow yaw from bias; this remains temporary, uncertain tracking.
          bias = bias + (sample.vector - bias) * (1 - math.exp(-dt / 20));
        }
      } else {
        restSince = null;
      }
      previousAcceleration = acceleration;

      if (dt > 0 && dt <= maxStepSeconds) {
        orientation =
            (orientation! * Quaternion.rotation((sample.vector - bias) * dt))
                .normalized();
        if (freshGravity &&
            acceleration != null &&
            (acceleration!.length - 9.80665).abs() < 0.6) {
          final Vector3 predictedUp = orientation!.conjugate.rotate(
            const Vector3(0, 0, 1),
          );
          final Vector3 error = g.normalized().cross(predictedUp);
          orientation =
              (orientation! *
                      Quaternion.rotation(error * (1 - math.exp(-dt / 2))))
                  .normalized();
        }
      }
      final Quaternion q = orientation!;
      final double relative = HeadingMath.headingFromQuat(
        q.x,
        q.y,
        q.z,
        q.w,
        screenAngleDeg: screenAngleDeg,
      );
      final Attitude attitude = Attitude.fromAccelerometer(g);
      final bool level = attitude.isFlat;
      calibration.observe(
        relative,
        timestamp: sample.timestamp,
        anchorable:
            relative.isFinite &&
            sample.vector.length < 0.1 &&
            level &&
            (accelerometerMissing ||
                (freshGravity &&
                    acceleration != null &&
                    (acceleration!.length - 9.80665).abs() < 0.6)),
      );
      final double? offset = calibration.offsetDeg;
      final bool movingHard =
          freshGravity &&
          acceleration != null &&
          (acceleration!.length - 9.80665).abs() > 2;
      controller.add(
        HeadingSample(
          headingDeg: offset == null
              ? relative
              : HeadingMath.applyOffset(relative, offset),
          isTrueNorth: calibration.isTrueNorth,
          timestamp: sample.timestamp,
          isProvisional: offset == null,
          assessment: movingHard
              ? const HeadingAssessment(
                  HeadingConfidence.unreliable,
                  HeadingIssue.excessiveMotion,
                )
              : HeadingAssessment(
                  HeadingConfidence.uncertain,
                  accelerometerMissing
                      ? HeadingIssue.holdLevel
                      : (offset == null
                            ? HeadingIssue.calibrationRequired
                            : HeadingIssue.gyroDrift),
                ),
        ),
      );
    }

    controller = StreamController<HeadingSample>(
      onListen: () {
        accSub = _sensors
            .accelerometer(samplingPeriod: samplingPeriod)
            .listen(
              (MotionSample sample) {
                if (cancelled) {
                  return;
                }
                if (!sample.vector.isUsable) {
                  acceleration = sample.vector;
                  gravity = null;
                  gravityAt = null;
                  calibration.resetTracking();
                  return;
                }
                final DateTime? previous = gravityAt;
                if (previous != null && !sample.timestamp.isAfter(previous)) {
                  return;
                }
                final double alpha = previous == null
                    ? 1
                    : 1 -
                          math.exp(
                            -sample.timestamp
                                    .difference(previous)
                                    .inMicroseconds /
                                160000,
                          );
                acceleration = sample.vector;
                gravity = gravity == null
                    ? sample.vector
                    : gravity! + (sample.vector - gravity!) * alpha;
                gravityAt = sample.timestamp;
              },
              onError: (Object _, StackTrace __) {
                accelerometerMissing = true;
                gravity = null;
              },
              onDone: () {
                accelerometerMissing = true;
                gravity = null;
              },
              cancelOnError: true,
            );
        gyroSub = _sensors
            .gyroscope(samplingPeriod: samplingPeriod)
            .listen(
              onGyroscope,
              onError: controller.addError,
              onDone: controller.close,
              cancelOnError: true,
            );
      },
      onCancel: () async {
        cancelled = true;
        calibration.resetTracking();
        await Future.wait<void>(<Future<void>>[
          if (accSub != null) accSub!.cancel(),
          if (gyroSub != null) gyroSub!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}
