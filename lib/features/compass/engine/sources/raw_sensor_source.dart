import 'dart:async';
import 'dart:math' as math;

import '../../../../core/geo/heading_math.dart';
import '../../../../core/geo/heading_quality.dart';
import '../../../../core/wmm/wmm.dart';
import '../../../../services/motion_sensors.dart';
import '../heading_source.dart';

/// Tilt-compensated fallback. Wait for real, fresh gravity; assume flat ONLY
/// when absence is reported. Raw sensors do not provide an angular error bound.
class RawSensorSource implements HeadingSource {
  RawSensorSource(
    this._sensors, {
    this.samplingPeriod = const Duration(milliseconds: 40),
    this.screenAngleDeg = 0,
    this.expectedField,
    this.modelValid,
    this.gravityTimeConstant = const Duration(milliseconds: 160),
  });

  final MotionSensors _sensors;
  final Duration samplingPeriod;
  final double screenAngleDeg;
  final MagneticField? Function()? expectedField;
  final bool Function()? modelValid;
  final Duration gravityTimeConstant;
  static const Duration maxSensorSkew = Duration(milliseconds: 500);

  @override
  HeadingSourceKind get kind => HeadingSourceKind.rawSensors;
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
    StreamSubscription<MotionSample>? magSub;
    Vector3? gravity;
    Vector3? acceleration;
    DateTime? gravityAt;
    bool accelerometerMissing = false;
    bool cancelled = false;
    final MagneticQualityMonitor monitor = MagneticQualityMonitor();

    void onMagnetometer(MotionSample sample) {
      if (cancelled) {
        return;
      }
      final Vector3? measuredGravity = gravity;
      if (!accelerometerMissing &&
          (measuredGravity == null || gravityAt == null)) {
        return; // sensor startup is not evidence that the phone is level
      }
      final bool fresh =
          gravityAt != null &&
          sample.timestamp.difference(gravityAt!).abs() <= maxSensorSkew;
      final Vector3 g = measuredGravity ?? const Vector3(0, 0, 9.80665);
      final double? heading = HeadingMath.tiltCompensatedHeading(
        g,
        sample.vector,
        screenAngleDeg: screenAngleDeg,
      );
      HeadingAssessment assessment = monitor.assess(
        timestamp: sample.timestamp,
        headingDeg: heading,
        reliability: SensorReliability.unknown,
        magneticMicrotesla: sample.vector,
        gravity: g,
        linearAcceleration: fresh && acceleration != null
            ? acceleration! - g
            : null,
        expectedField: expectedField?.call(),
        modelValid: modelValid?.call() ?? true,
        assumedFlat: accelerometerMissing,
      );
      if (!accelerometerMissing && !fresh) {
        assessment = const HeadingAssessment(
          HeadingConfidence.unreliable,
          HeadingIssue.stale,
        );
      }
      controller.add(
        HeadingSample(
          headingDeg: heading ?? double.nan,
          isTrueNorth: false,
          timestamp: sample.timestamp,
          assessment: assessment,
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
                  gravity = null;
                  acceleration = null;
                  gravityAt = null;
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
                final DateTime? previous = gravityAt;
                if (previous != null && !sample.timestamp.isAfter(previous)) {
                  return;
                }
                acceleration = sample.vector;
                final double alpha = previous == null
                    ? 1
                    : 1 -
                          math.exp(
                            -sample.timestamp
                                    .difference(previous)
                                    .inMicroseconds /
                                gravityTimeConstant.inMicroseconds,
                          );
                gravity = gravity == null
                    ? sample.vector
                    : gravity! + (sample.vector - gravity!) * alpha;
                gravityAt = sample.timestamp;
              },
              onError: (Object _, StackTrace __) {
                accelerometerMissing = true;
                gravity = null;
                gravityAt = null;
              },
              onDone: () {
                accelerometerMissing = true;
                gravity = null;
                gravityAt = null;
              },
              cancelOnError: true,
            );
        magSub = _sensors
            .magnetometer(samplingPeriod: samplingPeriod)
            .listen(
              onMagnetometer,
              onError: controller.addError,
              onDone: controller.close,
              cancelOnError: true,
            );
      },
      onCancel: () async {
        cancelled = true;
        await Future.wait<void>(<Future<void>>[
          if (accSub != null) accSub!.cancel(),
          if (magSub != null) magSub!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }
}
