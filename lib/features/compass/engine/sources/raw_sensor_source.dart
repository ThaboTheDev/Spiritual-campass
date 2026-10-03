import 'dart:async';

import '../../../../core/geo/coordinates.dart';
import '../../../../core/geo/heading_math.dart';
import '../../../../services/motion_sensors.dart';
import '../heading_source.dart';

/// Rung 2: magnetometer + accelerometer, tilt compensated in Dart.
///
/// Used on phones where the platform compass is missing or silent but the raw
/// sensors still report (common on cheap Android handsets whose vendor never
/// wired up `TYPE_ORIENTATION` / rotation vector). The accelerometer is low
/// passed to approximate gravity; if it is *absent* the phone is assumed flat
/// (gravity = +z) and the heading is still correct as long as the user holds
/// the phone level — that is called out through a lower accuracy.
class RawSensorSource implements HeadingSource {
  RawSensorSource(
    this._sensors, {
    this.gravityAlpha = 0.25,
    this.screenAngleDeg = 0,
  });

  final MotionSensors _sensors;

  /// Low-pass factor for the gravity estimate (0 .. 1, higher = faster).
  final double gravityAlpha;

  /// Rotation of the UI relative to the device's natural orientation. The
  /// app is portrait locked, so 0.
  final double screenAngleDeg;

  /// Accuracy reported when a real accelerometer is used.
  static const double nominalAccuracyDeg = 15.0;

  /// Accuracy reported when gravity had to be assumed (no accelerometer).
  static const double assumedFlatAccuracyDeg = 45.0;

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
    bool accelerometerMissing = false;

    void onMagnetometer(MotionSample sample) {
      final Vector3 g = gravity ?? const Vector3(0, 0, 9.81);
      final double? heading = HeadingMath.tiltCompensatedHeading(
        g,
        sample.vector,
        screenAngleDeg: screenAngleDeg,
      );
      if (heading == null) {
        return;
      }
      controller.add(
        HeadingSample(
          headingDeg: Angles.normalize360(heading),
          isTrueNorth: false,
          timestamp: sample.timestamp,
          accuracyDeg: accelerometerMissing
              ? assumedFlatAccuracyDeg
              : nominalAccuracyDeg,
        ),
      );
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
          onError: (Object _, StackTrace __) {
            // No accelerometer: assume the phone is held flat.
            accelerometerMissing = true;
            gravity = null;
          },
          cancelOnError: true,
        );
        magSub = _sensors.magnetometer().listen(
          onMagnetometer,
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: true,
        );
      },
      onCancel: () async {
        await accSub?.cancel();
        await magSub?.cancel();
      },
    );
    return controller.stream;
  }
}
