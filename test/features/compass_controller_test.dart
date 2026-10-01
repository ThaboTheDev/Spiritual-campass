import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/geo_math.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';
import 'package:tshk_compass/features/compass/compass_controller.dart';
import 'package:tshk_compass/features/location/location_controller.dart';
import 'package:tshk_compass/services/compass_service.dart';
import 'package:tshk_compass/services/motion_sensors.dart';

import '../support/compass_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late FakeCompassService native;
  late FakeMotionSensors sensors;
  late FakeLocationRepository location;
  late CountingWakeLock wake;
  late ProviderContainer container;
  late CompassController controller;

  setUp(() async {
    now = DateTime.utc(2026, 1, 1);
    native = FakeCompassService();
    sensors = FakeMotionSensors();
    location = FakeLocationRepository()
      ..current = GeoPoint(
        latitude: -26.2041,
        longitude: 28.0473,
        accuracyMetres: 5,
        timestamp: now,
        speedMps: 0,
        speedAccuracyMps: 0.1,
      );
    wake = CountingWakeLock();
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        compassServiceProvider.overrideWithValue(native),
        motionSensorsProvider.overrideWithValue(sensors),
        locationRepositoryProvider.overrideWithValue(location),
        wakeLockServiceProvider.overrideWithValue(wake),
        compassClockProvider.overrideWithValue(() => now),
      ],
    );
    controller = container.read(compassControllerProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await flushStreams();
    await native.controller.close();
    await sensors.close();
    await location.controller.close();
  });
  CompassState state() => container.read(compassControllerProvider);
  Future<void> emit(
    double heading,
    NorthReference reference, {
    double? accuracy = 2,
    SensorReliability reliability = SensorReliability.high,
  }) async {
    native.controller.add(
      CompassReading(
        reference: reference,
        timestamp: now,
        headingDeg: heading,
        accuracyDeg: accuracy,
        reliability: reliability,
      ),
    );
    await flushStreams();
  }

  test(
    'magnetic headings get one correction; true headings never get a second',
    () async {
      await controller.start();
      await flushStreams();
      await emit(30, NorthReference.magnetic);
      final double declination = state().declinationDeg!;
      expect(
        state().trueHeadingDeg,
        closeTo(Angles.normalize360(30 + declination), 1e-8),
      );
      now = now.add(const Duration(milliseconds: 40));
      await emit(30, NorthReference.trueNorth);
      expect(state().trueHeadingDeg, closeTo(30, 1e-8));
      expect(
        state().magneticHeadingDeg,
        closeTo(Angles.normalize360(30 - declination), 1e-8),
      );
    },
  );
  test(
    'quality changes at a stationary heading bypass the presentation throttle',
    () async {
      await controller.start();
      await flushStreams();
      await emit(30, NorthReference.magnetic);
      now = now.add(const Duration(milliseconds: 5));
      await emit(30, NorthReference.magnetic, accuracy: null);
      expect(state().confidence, HeadingConfidence.uncertain);
      expect(state().accuracyDeg, isNull);
      now = now.add(const Duration(milliseconds: 5));
      await emit(
        30,
        NorthReference.magnetic,
        reliability: SensorReliability.unreliable,
      );
      expect(state().hasHeading, isFalse);
      expect(state().confidence, HeadingConfidence.unreliable);
    },
  );
  test(
    'precision confirmation needs continuous trustworthy samples and fresh GPS',
    () async {
      await controller.start();
      await flushStreams();
      final TargetReading target = GeoMath.readingTo(
        location.current!,
        Ekuphumuleni.point,
        at: now,
      );
      for (int i = 0; i <= 12; i++) {
        now = DateTime.utc(2026, 1, 1).add(Duration(milliseconds: i * 100));
        await emit(target.bearingDeg, NorthReference.trueNorth, accuracy: 1);
      }
      expect(state().isAlignedTo(target, now), isTrue);
      expect(
        state().isAlignedTo(target, now.add(const Duration(seconds: 1))),
        isFalse,
      );
      controller.onAppPaused();
      expect(state().hasHeading, isFalse);
      expect(state().isAlignedTo(target, now), isFalse);
    },
  );
  test(
    'a gap cannot count as time spent steadily measuring direction',
    () async {
      await controller.start();
      await flushStreams();
      final TargetReading target = GeoMath.readingTo(
        location.current!,
        Ekuphumuleni.point,
        at: now,
      );
      await emit(target.bearingDeg, NorthReference.trueNorth, accuracy: 1);
      now = now.add(const Duration(milliseconds: 1500));
      await emit(target.bearingDeg, NorthReference.trueNorth, accuracy: 1);
      expect(state().isAlignedTo(target, now), isFalse);
    },
  );
  test(
    'GPS is explicitly selectable even when gyro calibration is pending',
    () async {
      native.available = false;
      sensors.noMag = true;
      await controller.start();
      await flushStreams();
      sensors.level(now);
      await flushStreams();
      sensors.still(now);
      await flushStreams();
      expect(state().source, HeadingSourceKind.relativeCalibrated);
      expect(state().awaitingCalibration, isTrue);
      expect(
        controller.buildSources().map((s) => s.kind),
        isNot(contains(HeadingSourceKind.gpsCourse)),
      );
      await controller.setMode(CompassMode.travelDirection);
      await flushStreams();
      expect(controller.buildSources().map((s) => s.kind), [
        HeadingSourceKind.gpsCourse,
      ]);
      for (int i = 1; i <= 3; i++) {
        now = now.add(const Duration(seconds: 1));
        location.controller.add(
          GeoPoint(
            latitude: -26.2,
            longitude: 28 + i * 0.00002,
            accuracyMetres: 5,
            timestamp: now,
            speedMps: 1.5,
            speedAccuracyMps: 0.1,
            courseDeg: 90,
            courseAccuracyDeg: 5,
          ),
        );
        await flushStreams();
      }
      expect(state().trueHeadingDeg, closeTo(90, 1e-8));
      expect(state().isTravelDirection, isTrue);
      expect(state().awaitingCalibration, isFalse);
      expect(controller.calibrateToNorth(), isFalse);
    },
  );
  test(
    'gyro calibration is forgotten on pause / resume and every retry',
    () async {
      native.available = false;
      sensors.noMag = true;
      await controller.start();
      await flushStreams();
      sensors.level(now);
      await flushStreams();
      sensors.still(now);
      await flushStreams();
      expect(controller.calibrateToNorth(), isTrue);
      expect(state().hasHeading, isTrue);
      controller.onAppPaused();
      expect(state().calibrationAnchor, isNull);
      controller.onAppResumed();
      await flushStreams();
      now = now.add(const Duration(milliseconds: 100));
      sensors.level(now);
      await flushStreams();
      sensors.still(now);
      await flushStreams();
      expect(state().awaitingCalibration, isTrue);
      expect(state().hasHeading, isFalse);
    },
  );
  test('sensors start without waiting for an indoor GPS fix', () async {
    location.currentRequest = Completer<GeoPoint?>();
    await controller.start();
    await flushStreams();
    await emit(90, NorthReference.magnetic);
    expect(state().hasHeading, isTrue);
    expect(state().trueHeadingDeg, isNull);
    location.currentRequest!.complete(null);
    await flushStreams();
  });
  test(
    'stop cancels pending startup and cached-location futures cannot revive it',
    () async {
      native.screenRequest = Completer<double>();
      location.currentRequest = Completer<GeoPoint?>();
      final Future<void> startup = controller.start();
      await flushStreams();
      controller.stop();
      native.screenRequest!.complete(0);
      location.currentRequest!.complete(location.current);
      await startup;
      await flushStreams();
      expect(state().status, CompassStatus.off);
      expect(native.controller.hasListener, isFalse);
      expect(container.read(locationControllerProvider).tracking, isFalse);
      expect(location.controller.hasListener, isFalse);
      expect(wake.acquires, 0);
    },
  );
  test(
    'expired WMM leaves magnetic direction but never a corrected target heading',
    () async {
      now = DateTime.utc(2030, 1, 1);
      await controller.start();
      await flushStreams();
      await emit(30, NorthReference.magnetic);
      expect(state().magneticHeadingDeg, closeTo(30, 1e-8));
      expect(state().trueHeadingDeg, isNull);
      expect(state().issue, HeadingIssue.modelExpired);
    },
  );
  test(
    'filter lag is part of precision uncertainty and motion restarts settling',
    () async {
      await controller.start();
      await flushStreams();
      await emit(0, NorthReference.trueNorth, accuracy: 1);
      now = now.add(const Duration(milliseconds: 40));
      await emit(3, NorthReference.trueNorth, accuracy: 1);
      expect(state().accuracyDeg, 1);
      expect(state().trueAccuracyDeg, greaterThan(3));
      expect(state().stableSince, now);
    },
  );
  test(
    'a late orientation query cannot overwrite the resumed display frame',
    () async {
      final Completer<double> oldScreen = Completer<double>();
      native.screenRequest = oldScreen;
      final Future<void> oldStart = controller.start();
      await flushStreams();
      controller.onAppPaused();
      native.screenRequest = null;
      native.screenAngle = -90;
      controller.onAppResumed();
      await flushStreams();
      oldScreen.complete(0);
      await oldStart;
      await flushStreams();
      sensors.acc.add(MotionSample(const Vector3(0, 4, 8.9), now));
      await flushStreams();
      expect(state().attitude!.rollDeg, greaterThan(0));
      expect(state().attitude!.pitchDeg, closeTo(0, 1e-8));
    },
  );
  test(
    'a slow wake acquisition is followed by release, not a leaked lock',
    () async {
      wake.acquireGate = Completer<void>();
      await controller.start();
      await flushStreams();
      expect(wake.acquires, 1);
      controller.stop();
      expect(wake.releases, 0);
      wake.acquireGate!.complete();
      await flushStreams();
      expect(wake.releases, 1);
      expect(wake.held, isFalse);
      expect(location.fixCancellations, greaterThan(0));
    },
  );
  test(
    'a wake acquisition completing after timeout is compensated after stop',
    () async {
      wake.acquireGate = Completer<void>();
      await controller.start();
      await flushStreams();
      controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await flushStreams();
      expect(wake.releases, 1);
      wake.acquireGate!.complete();
      await flushStreams();
      expect(wake.releases, 2);
      expect(wake.held, isFalse);
    },
  );
}
