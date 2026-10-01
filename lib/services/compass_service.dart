import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/geo/coordinates.dart';
import '../core/geo/heading_math.dart';
import '../core/geo/heading_quality.dart';

class SensorCapabilities {
  const SensorCapabilities({
    this.absoluteOrientation = false,
    this.magnetometer = false,
    this.accelerometer = false,
    this.gyroscope = false,
  });

  final bool absoluteOrientation;
  final bool magnetometer;
  final bool accelerometer;
  final bool gyroscope;
}

/// A native reading with an explicit frame, actual acquisition time and
/// calibration status. A vendor status is never translated to invented ±°.
class CompassReading {
  const CompassReading({
    required this.reference,
    required this.timestamp,
    this.headingDeg,
    this.rotationMatrix,
    this.screenAngleDeg = 0,
    this.accuracyDeg,
    this.reliability = SensorReliability.unknown,
    this.magneticMicrotesla,
    this.gravity,
    this.linearAcceleration,
    this.gyroscope,
  });

  final NorthReference reference;
  final DateTime timestamp;
  final double? headingDeg;

  /// Row-major device → Earth (east, north, up). Magnetic or true per reference.
  final List<double>? rotationMatrix;
  final double screenAngleDeg;
  final double? accuracyDeg;
  final SensorReliability reliability;
  final Vector3? magneticMicrotesla;
  final Vector3? gravity;
  final Vector3? linearAcceleration;
  final Vector3? gyroscope;

  double? get facingHeadingDeg {
    final List<double>? m = rotationMatrix;
    if (m != null) {
      if (!_isRotationMatrix(m)) {
        return null;
      }
      final double heading = HeadingMath.facing(
        m[0],
        m[3],
        m[6],
        m[1],
        m[4],
        m[7],
        m[2],
        m[5],
        m[8],
        Angles.toRadians(screenAngleDeg),
      );
      return heading.isFinite ? heading : null;
    }
    final double? heading = headingDeg;
    if (heading == null ||
        !heading.isFinite ||
        reference == NorthReference.relative) {
      return null;
    }
    // Core Location's -1 sentinel is not 359°. Android signed magnetic
    // azimuths, in contrast, are legitimate and may be normalized.
    if (reference == NorthReference.trueNorth &&
        (heading < 0 || heading >= 360)) {
      return null;
    }
    return Angles.normalize360(heading + screenAngleDeg);
  }

  static bool _isRotationMatrix(List<double> m) {
    if (m.length != 9 || m.any((double v) => !v.isFinite)) {
      return false;
    }
    final Vector3 e = Vector3(m[0], m[1], m[2]);
    final Vector3 n = Vector3(m[3], m[4], m[5]);
    final Vector3 u = Vector3(m[6], m[7], m[8]);
    return (e.length - 1).abs() < 0.05 &&
        (n.length - 1).abs() < 0.05 &&
        (u.length - 1).abs() < 0.05 &&
        e.dot(n).abs() < 0.05 &&
        e.dot(u).abs() < 0.05 &&
        n.dot(u).abs() < 0.05 &&
        e.cross(n).dot(u) > 0.95;
  }

  factory CompassReading.fromNative(Map<Object?, Object?> data) {
    double? number(String key) => (data[key] as num?)?.toDouble();
    List<double>? numbers(String key) => (data[key] as List<Object?>?)
        ?.map((Object? value) => (value as num).toDouble())
        .toList();
    Vector3? vector(String key) {
      final List<double>? values = numbers(key);
      return values?.length == 3
          ? Vector3(values![0], values[1], values[2])
          : null;
    }

    final int status = (data['reliability'] as num?)?.toInt() ?? -1;
    final double? accuracy = number('accuracy');
    return CompassReading(
      reference: switch (data['reference']) {
        'magnetic' => NorthReference.magnetic,
        'true' => NorthReference.trueNorth,
        _ => NorthReference.relative,
      },
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestampMs'] as num).toInt(),
        isUtc: true,
      ),
      rotationMatrix: numbers('matrix'),
      headingDeg: number('heading'),
      screenAngleDeg: number('screenAngle') ?? 0,
      accuracyDeg: accuracy,
      reliability: switch (status) {
        0 => SensorReliability.unreliable,
        1 => SensorReliability.low,
        2 => SensorReliability.medium,
        3 => SensorReliability.high,
        _ => SensorReliability.unknown,
      },
      magneticMicrotesla: vector('magnetic'),
      gravity: vector('gravity'),
      linearAcceleration: vector('linearAcceleration'),
      gyroscope: vector('gyro'),
    );
  }
}

abstract class CompassService {
  Stream<CompassReading>? get readings;
  bool get isSupported;
  Future<SensorCapabilities> capabilities();
  Future<double> screenAngleDeg();
}

/// App-owned native adapter. Android uses rotation vector / geomagnetic
/// rotation vector; iOS uses magnetic-north Core Motion with CLHeading as a
/// level-phone fallback. Both explicitly identify magnetic north. This avoids
/// flutter_compass 0.8.1's mixed iOS true / Android magnetic contract and its
/// synthetic Android accuracy values, while retaining OS sensor fusion.
class NativeCompassService implements CompassService {
  NativeCompassService({
    this.samplingPeriod = const Duration(milliseconds: 40),
  });

  static const MethodChannel _methods = MethodChannel('tshk/compass/methods');
  static const EventChannel _events = EventChannel('tshk/compass/events');
  final Duration samplingPeriod;
  Stream<CompassReading>? _readings;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<CompassReading>? get readings {
    if (!isSupported) {
      return null;
    }
    return _readings ??= _events
        .receiveBroadcastStream(<String, Object>{
          'samplingMicros': samplingPeriod.inMicroseconds,
        })
        .map(
          (Object? data) =>
              CompassReading.fromNative(data! as Map<Object?, Object?>),
        );
  }

  @override
  Future<SensorCapabilities> capabilities() async {
    if (!isSupported) {
      return const SensorCapabilities();
    }
    try {
      final Map<Object?, Object?>? data = await _methods
          .invokeMapMethod<Object?, Object?>('capabilities')
          .timeout(const Duration(seconds: 1));
      return SensorCapabilities(
        absoluteOrientation: data?['absoluteOrientation'] == true,
        magnetometer: data?['magnetometer'] == true,
        accelerometer: data?['accelerometer'] == true,
        gyroscope: data?['gyroscope'] == true,
      );
    } catch (_) {
      return const SensorCapabilities();
    }
  }

  @override
  Future<double> screenAngleDeg() async {
    try {
      return await _methods
              .invokeMethod<double>('screenAngle')
              .timeout(const Duration(seconds: 1)) ??
          0;
    } catch (_) {
      return 0;
    }
  }
}
