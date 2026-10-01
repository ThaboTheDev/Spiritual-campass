import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';
import 'package:tshk_compass/features/compass/engine/heading_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/fused_compass_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/raw_sensor_source.dart';
import 'package:tshk_compass/services/compass_service.dart';
import 'package:tshk_compass/services/motion_sensors.dart';

import '../support/compass_fakes.dart';

void main() {
  final DateTime at = DateTime.utc(2026, 1, 1);
  test(
    'true north is identified, while signed Android azimuth is legitimate',
    () async {
      final FakeCompassService service = FakeCompassService();
      final List<HeadingSample> samples = [];
      final StreamSubscription<HeadingSample> sub = FusedCompassSource(
        service,
      ).start().listen(samples.add);
      service.controller.add(
        CompassReading(
          reference: NorthReference.trueNorth,
          timestamp: at,
          headingDeg: 30,
          accuracyDeg: 5,
          reliability: SensorReliability.high,
        ),
      );
      service.controller.add(
        CompassReading(
          reference: NorthReference.magnetic,
          timestamp: at,
          headingDeg: -1,
          accuracyDeg: 5,
          reliability: SensorReliability.high,
        ),
      );
      service.controller.add(
        CompassReading(
          reference: NorthReference.trueNorth,
          timestamp: at,
          headingDeg: -1,
          accuracyDeg: 5,
          reliability: SensorReliability.high,
        ),
      );
      await flushStreams();
      expect(samples[0].isTrueNorth, isTrue);
      expect(samples[0].timestamp, at);
      expect(samples[1].headingDeg, 359);
      expect(samples[1].isTrueNorth, isFalse);
      expect(
        samples[2].assessment.isUsable,
        isFalse,
        reason: '-1 true heading is unavailable, not 359°',
      );
      await sub.cancel();
      await service.controller.close();
    },
  );
  test(
    'raw source waits for accelerometer startup instead of assuming flat',
    () async {
      final FakeMotionSensors sensors = FakeMotionSensors();
      final List<HeadingSample> samples = [];
      final StreamSubscription<HeadingSample> sub = RawSensorSource(
        sensors,
        samplingPeriod: const Duration(milliseconds: 66),
      ).start().listen(samples.add);
      sensors.mag.add(MotionSample(const Vector3(0, 25, -35), at));
      await flushStreams();
      expect(samples, isEmpty);
      sensors.level(at);
      await flushStreams();
      sensors.mag.add(MotionSample(const Vector3(0, 25, -35), at));
      await flushStreams();
      expect(samples.single.headingDeg, closeTo(0, 1e-9));
      expect(samples.single.accuracyDeg, isNull);
      expect(samples.single.assessment.confidence, HeadingConfidence.uncertain);
      expect(
        sensors.requestedPeriods,
        everyElement(const Duration(milliseconds: 66)),
      );
      sensors.mag.add(
        MotionSample(
          const Vector3(0, 25, -35),
          at.add(const Duration(seconds: 1)),
        ),
      );
      await flushStreams();
      expect(samples.last.assessment.issue, HeadingIssue.stale);
      await sub.cancel();
      expect(sensors.acc.hasListener, isFalse);
      expect(sensors.mag.hasListener, isFalse);
      await sensors.close();
    },
  );
  test(
    'confirmed missing accelerometer permits only an explicitly uncertain flat fallback',
    () async {
      final FakeMotionSensors sensors = FakeMotionSensors()..noAcc = true;
      final List<HeadingSample> samples = [];
      final StreamSubscription<HeadingSample> sub = RawSensorSource(
        sensors,
      ).start().listen(samples.add);
      await flushStreams();
      sensors.mag.add(MotionSample(const Vector3(0, 25, -35), at));
      await flushStreams();
      expect(samples.single.assessment.issue, HeadingIssue.holdLevel);
      expect(samples.single.accuracyDeg, isNull);
      await sub.cancel();
      await sensors.close();
    },
  );
  test(
    'native matrices use screen rotation and reject degenerate orientation',
    () {
      CompassReading reading(List<double> matrix, {double angle = 0}) =>
          CompassReading(
            reference: NorthReference.magnetic,
            timestamp: at,
            rotationMatrix: matrix,
            screenAngleDeg: angle,
          );
      const List<double> identity = [1, 0, 0, 0, 1, 0, 0, 0, 1];
      expect(reading(identity).facingHeadingDeg, closeTo(0, 1e-9));
      expect(
        reading(identity, angle: -90).facingHeadingDeg,
        closeTo(270, 1e-9),
      );
      expect(
        reading(identity, angle: -180).facingHeadingDeg,
        closeTo(180, 1e-9),
      );
      expect(reading(List<double>.filled(9, 0)).facingHeadingDeg, isNull);
      expect(
        reading([1, 0, 0, 0, 1, 0, 0, 0, -1]).facingHeadingDeg,
        isNull,
        reason: 'reflection is not a rotation',
      );
    },
  );
  test(
    'native parser preserves metadata and never invents a degree estimate',
    () {
      final CompassReading reading = CompassReading.fromNative({
        'reference': 'magnetic',
        'heading': 0,
        'timestampMs': at.millisecondsSinceEpoch,
        'reliability': 0,
        'accuracy': null,
        'magnetic': [0, 25, -35],
      });
      expect(reading.reliability, SensorReliability.unreliable);
      expect(reading.accuracyDeg, isNull);
      expect(reading.timestamp, at);
      expect(reading.magneticMicrotesla!.y, 25);
    },
  );
  test(
    'invalid raw acceleration clears the previous usable gravity immediately',
    () async {
      final FakeMotionSensors sensors = FakeMotionSensors();
      final List<HeadingSample> samples = [];
      final StreamSubscription<HeadingSample> sub = RawSensorSource(
        sensors,
      ).start().listen(samples.add);
      sensors.level(at);
      await flushStreams();
      sensors.mag.add(MotionSample(const Vector3(0, 25, -35), at));
      await flushStreams();
      expect(samples.single.assessment.isUsable, isTrue);
      sensors.acc.add(
        MotionSample(
          const Vector3(double.nan, 0, 0),
          at.add(const Duration(milliseconds: 40)),
        ),
      );
      await flushStreams();
      expect(samples.last.assessment.isUsable, isFalse);
      final int count = samples.length;
      sensors.mag.add(
        MotionSample(
          const Vector3(0, 25, -35),
          at.add(const Duration(milliseconds: 80)),
        ),
      );
      await flushStreams();
      expect(samples.length, count);
      await sub.cancel();
      await sensors.close();
    },
  );
}
