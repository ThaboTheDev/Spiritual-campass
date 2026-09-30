import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:sensors_plus/sensors_plus.dart';

import '../core/geo/heading_math.dart';

/// One raw motion sample in the device frame.
class MotionSample {
  const MotionSample(this.vector, this.timestamp);

  /// The reading (m/s², µT or rad/s depending on the sensor).
  final Vector3 vector;

  /// When the sample was taken.
  final DateTime timestamp;
}

/// The raw motion sensors, kept behind an interface so the heading sources can
/// be unit tested with scripted samples.
///
/// Every stream is *lazy* and *safe*: subscribing on a device without that
/// sensor delivers an error (never an uncaught exception), and the heading
/// ladder treats an error as "sensor absent".
abstract class MotionSensors {
  /// Gravity + linear acceleration, m/s².
  Stream<MotionSample> accelerometer({Duration? samplingPeriod});

  /// Geomagnetic field, µT.
  Stream<MotionSample> magnetometer({Duration? samplingPeriod});

  /// Angular velocity, rad/s.
  Stream<MotionSample> gyroscope({Duration? samplingPeriod});
}

/// sensors_plus implementation of [MotionSensors].
class SensorsPlusMotionSensors implements MotionSensors {
  const SensorsPlusMotionSensors();

  /// ~25 Hz: plenty for a compass, gentle on a 1 GB phone.
  static const Duration defaultPeriod = Duration(milliseconds: 40);

  @override
  Stream<MotionSample> accelerometer({Duration? samplingPeriod}) => _guard(
        () => accelerometerEventStream(
          samplingPeriod: samplingPeriod ?? defaultPeriod,
        ).map(
          (AccelerometerEvent e) => MotionSample(
            Vector3(e.x, e.y, e.z),
            e.timestamp,
          ),
        ),
      );

  @override
  Stream<MotionSample> magnetometer({Duration? samplingPeriod}) => _guard(
        () => magnetometerEventStream(
          samplingPeriod: samplingPeriod ?? defaultPeriod,
        ).map(
          (MagnetometerEvent e) => MotionSample(
            Vector3(e.x, e.y, e.z),
            e.timestamp,
          ),
        ),
      );

  @override
  Stream<MotionSample> gyroscope({Duration? samplingPeriod}) => _guard(
        () => gyroscopeEventStream(
          samplingPeriod: samplingPeriod ?? defaultPeriod,
        ).map(
          (GyroscopeEvent e) => MotionSample(
            Vector3(e.x, e.y, e.z),
            e.timestamp,
          ),
        ),
      );

  /// Wraps a plugin stream so that a missing sensor (which sensors_plus
  /// reports as a [PlatformException] on first listen) becomes a stream error
  /// instead of a synchronous throw.
  static Stream<MotionSample> _guard(Stream<MotionSample> Function() open) {
    late final StreamController<MotionSample> controller;
    StreamSubscription<MotionSample>? subscription;
    controller = StreamController<MotionSample>(
      onListen: () {
        try {
          subscription = open().listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        } on PlatformException catch (error, stack) {
          controller.addError(SensorUnavailable(error.message), stack);
        } on MissingPluginException catch (error, stack) {
          controller.addError(SensorUnavailable(error.message), stack);
        } catch (error, stack) {
          controller.addError(SensorUnavailable(error.toString()), stack);
        }
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

/// Raised on the stream when the device has no such sensor.
class SensorUnavailable implements Exception {
  const SensorUnavailable([this.message]);

  final String? message;

  @override
  String toString() => 'SensorUnavailable(${message ?? ''})';
}
