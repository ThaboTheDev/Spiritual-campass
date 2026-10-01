import 'dart:async';

import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/data/repositories/location_repository.dart';
import 'package:tshk_compass/services/compass_service.dart';
import 'package:tshk_compass/services/motion_sensors.dart';
import 'package:tshk_compass/services/wake_lock_service.dart';

Future<void> flushStreams() async {
  for (int i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakeCompassService implements CompassService {
  final StreamController<CompassReading> controller =
      StreamController<CompassReading>.broadcast();
  bool available = true;
  double screenAngle = 0;
  Completer<double>? screenRequest;
  @override
  bool get isSupported => true;
  @override
  Stream<CompassReading> get readings => controller.stream;
  @override
  Future<SensorCapabilities> capabilities() async => SensorCapabilities(
    absoluteOrientation: available,
    magnetometer: available,
    accelerometer: true,
    gyroscope: true,
  );
  @override
  Future<double> screenAngleDeg() =>
      screenRequest?.future ?? Future<double>.value(screenAngle);
}

class FakeMotionSensors implements MotionSensors {
  final StreamController<MotionSample> acc =
      StreamController<MotionSample>.broadcast();
  final StreamController<MotionSample> mag =
      StreamController<MotionSample>.broadcast();
  final StreamController<MotionSample> gyro =
      StreamController<MotionSample>.broadcast();
  bool noMag = false;
  bool noGyro = false;
  bool noAcc = false;
  final List<Duration?> requestedPeriods = <Duration?>[];
  @override
  Stream<MotionSample> accelerometer({Duration? samplingPeriod}) {
    requestedPeriods.add(samplingPeriod);
    return noAcc
        ? Stream<MotionSample>.error(const SensorUnavailable())
        : acc.stream;
  }

  @override
  Stream<MotionSample> magnetometer({Duration? samplingPeriod}) {
    requestedPeriods.add(samplingPeriod);
    return noMag
        ? Stream<MotionSample>.error(const SensorUnavailable())
        : mag.stream;
  }

  @override
  Stream<MotionSample> gyroscope({Duration? samplingPeriod}) {
    requestedPeriods.add(samplingPeriod);
    return noGyro
        ? Stream<MotionSample>.error(const SensorUnavailable())
        : gyro.stream;
  }

  void level(DateTime at) =>
      acc.add(MotionSample(const Vector3(0, 0, 9.80665), at));
  void still(DateTime at) => gyro.add(MotionSample(const Vector3(0, 0, 0), at));
  Future<void> close() async {
    await acc.close();
    await mag.close();
    await gyro.close();
  }
}

class FakeLocationRepository implements LocationRepository {
  final StreamController<GeoPoint> controller =
      StreamController<GeoPoint>.broadcast();
  LocationAccess access = LocationAccess.whileInUse;
  bool enabled = true;
  GeoPoint? current;
  GeoPoint? cached;
  Completer<GeoPoint?>? currentRequest;
  Completer<LocationAccess>? permissionRequest;
  int accessRequests = 0;
  int fixCancellations = 0;
  @override
  Stream<GeoPoint> get positionStream => controller.stream;
  @override
  Future<bool> isServiceEnabled() async => enabled;
  @override
  Future<LocationAccess> requestAccess() async {
    accessRequests++;
    if (permissionRequest != null) {
      return permissionRequest!.future;
    }
    return enabled ? access : LocationAccess.serviceDisabled;
  }

  @override
  Future<LocationAccess> checkAccess() async => access;
  @override
  Future<GeoPoint?> getCurrentPoint() =>
      currentRequest?.future ?? Future<GeoPoint?>.value(current);
  @override
  void cancelPendingFixes() {
    fixCancellations++;
  }

  @override
  Future<GeoPoint?> getLastKnownPoint() async => cached;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  double distanceBetween(GeoPoint from, GeoPoint to) => 0;
}

class CountingWakeLock implements WakeLockService {
  int acquires = 0;
  int releases = 0;
  bool held = false;
  Completer<void>? acquireGate;
  @override
  Future<void> acquire() async {
    acquires++;
    await acquireGate?.future;
    held = true;
  }

  @override
  Future<void> release() async {
    releases++;
    held = false;
  }
}
