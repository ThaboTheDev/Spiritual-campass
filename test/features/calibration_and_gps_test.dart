import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';
import 'package:tshk_compass/features/compass/engine/heading_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/gps_course_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/relative_orientation_source.dart';

import '../support/compass_fakes.dart';

void main() {
  final DateTime origin = DateTime.utc(2026, 1, 1);
  group('relative anchors', () {
    test(
      'sun is true north; hand compass is magnetic; restart clears the origin',
      () {
        DateTime now = origin;
        final RelativeCalibration c = RelativeCalibration(now: () => now);
        expect(c.set(300, CalibrationAnchor.sun), isFalse);
        c.observe(40);
        expect(c.set(300, CalibrationAnchor.sun), isTrue);
        expect(c.isTrueNorth, isTrue);
        expect(HeadingMath.applyOffset(40, c.offsetDeg!), closeTo(300, 1e-9));
        c.clear();
        expect(c.latestRelativeDeg, 40);
        expect(c.set(0, CalibrationAnchor.north), isTrue);
        expect(c.isTrueNorth, isFalse);
        now = now.add(const Duration(seconds: 61));
        expect(c.isCalibrated, isFalse);
        c.observe(10);
        expect(c.set(0, CalibrationAnchor.north), isTrue);
        c.resetTracking();
        expect(c.latestRelativeDeg, isNull);
        expect(c.isCalibrated, isFalse);
        expect(c.set(0, CalibrationAnchor.north), isFalse);
      },
    );
    test('old, moving and non-finite observations cannot be anchored', () {
      DateTime now = origin;
      final RelativeCalibration c = RelativeCalibration(now: () => now);
      c.observe(10, anchorable: false);
      expect(c.set(0, CalibrationAnchor.north), isFalse);
      c.observe(10);
      now = now.add(const Duration(seconds: 1));
      expect(c.set(0, CalibrationAnchor.north), isFalse);
      c.observe(double.nan);
      expect(c.set(0, CalibrationAnchor.north), isFalse);
    });
    test(
      'source start, sensor gaps and cancellation invalidate calibration',
      () async {
        DateTime now = origin;
        final FakeMotionSensors sensors = FakeMotionSensors();
        final RelativeCalibration calibration = RelativeCalibration(
          now: () => now,
        );
        calibration.observe(40);
        calibration.set(0, CalibrationAnchor.north);
        final RelativeOrientationSource source = RelativeOrientationSource(
          sensors,
          calibration,
        );
        final List<HeadingSample> samples = [];
        final StreamSubscription<HeadingSample> sub = source.start().listen(
          samples.add,
        );
        expect(calibration.isCalibrated, isFalse);
        sensors.level(now);
        await flushStreams();
        sensors.still(now);
        await flushStreams();
        expect(samples.last.isProvisional, isTrue);
        expect(calibration.set(0, CalibrationAnchor.north), isTrue);
        now = now.add(const Duration(milliseconds: 100));
        sensors.level(now);
        sensors.still(now);
        await flushStreams();
        expect(samples.last.isProvisional, isFalse);
        expect(samples.last.accuracyDeg, isNull, reason: 'no invented ±10°');
        expect(samples.last.assessment.confidence, HeadingConfidence.uncertain);
        now = now.add(const Duration(seconds: 1));
        sensors.level(now);
        await flushStreams();
        sensors.still(now);
        await flushStreams();
        expect(samples.last.isProvisional, isTrue);
        await sub.cancel();
        expect(calibration.latestRelativeDeg, isNull);
        await sensors.close();
      },
    );
  });

  group('explicit GPS travel direction', () {
    test(
      'freshness, fix accuracy and speed uncertainty matter, not just speed',
      () {
        GeoPoint point({
          double speed = 1.5,
          double error = 10,
          double speedError = 0.2,
          DateTime? at,
          double? courseError = 5,
        }) => GeoPoint(
          latitude: -26,
          longitude: 28,
          speedMps: speed,
          accuracyMetres: error,
          courseDeg: 90,
          courseAccuracyDeg: courseError,
          speedAccuracyMps: speedError,
          timestamp: at ?? origin,
        );
        expect(point().hasWalkingCourseAt(origin), isTrue);
        expect(point(speed: 0.2).hasWalkingCourseAt(origin), isFalse);
        expect(point(error: 100).hasWalkingCourseAt(origin), isFalse);
        expect(point(speedError: 1).hasWalkingCourseAt(origin), isFalse);
        expect(point(courseError: 45).hasWalkingCourseAt(origin), isFalse);
        expect(
          point(
            at: origin.subtract(const Duration(minutes: 1)),
          ).hasWalkingCourseAt(origin),
          isFalse,
        );
        expect(
          const GeoPoint(
            latitude: 0,
            longitude: 0,
            speedMps: 2,
            courseDeg: 90,
          ).hasWalkingCourseAt(origin),
          isFalse,
        );
      },
    );
    test(
      'requires sustained movement and immediately clears course on stopping',
      () async {
        DateTime now = origin;
        final FakeLocationRepository repository = FakeLocationRepository();
        final GpsCourseSource source = GpsCourseSource(
          repository,
          now: () => now,
        );
        final List<HeadingSample> samples = [];
        final StreamSubscription<HeadingSample> sub = source.start().listen(
          samples.add,
        );
        for (int i = 0; i < 3; i++) {
          now = origin.add(Duration(seconds: i));
          repository.controller.add(
            GeoPoint(
              latitude: -26,
              longitude: 28 + i * 0.00002,
              timestamp: now,
              accuracyMetres: 5,
              speedMps: 1.5,
              speedAccuracyMps: 0.2,
              courseDeg: 123.4,
              courseAccuracyDeg: 5,
            ),
          );
          await flushStreams();
        }
        expect(samples[0].isProvisional, isTrue);
        expect(samples[1].isProvisional, isTrue);
        expect(samples[2].isProvisional, isFalse);
        expect(samples[2].isTrueNorth, isTrue);
        expect(samples[2].headingDeg, 123.4);
        now = now.add(const Duration(seconds: 1));
        repository.controller.add(
          GeoPoint(
            latitude: -26,
            longitude: 28,
            timestamp: now,
            accuracyMetres: 5,
            speedMps: 0.1,
            courseDeg: 123.4,
          ),
        );
        await flushStreams();
        expect(samples.last.isProvisional, isTrue);
        expect(samples.last.assessment.issue, HeadingIssue.waitingForMovement);
        await sub.cancel();
        await repository.controller.close();
      },
    );
    test(
      'unknown course accuracy needs a baseline exceeding position uncertainty',
      () async {
        DateTime now = origin;
        final FakeLocationRepository repository = FakeLocationRepository();
        final List<HeadingSample> samples = [];
        final StreamSubscription<HeadingSample> sub = GpsCourseSource(
          repository,
          now: () => now,
        ).start().listen(samples.add);
        for (int i = 0; i < 7; i++) {
          now = origin.add(Duration(seconds: i));
          repository.controller.add(
            GeoPoint(
              latitude: -26,
              longitude: 28 + i * 0.00012,
              timestamp: now,
              accuracyMetres: 5,
              speedMps: 12,
              courseDeg: 0,
            ),
          );
          await flushStreams();
        }
        expect(samples[1].isProvisional, isTrue);
        expect(
          samples.skip(3).map((HeadingSample sample) => sample.isProvisional),
          everyElement(isFalse),
        );
        expect(samples.last.isProvisional, isFalse);
        expect(
          samples.last.headingDeg,
          closeTo(90, 0.1),
          reason: 'derive movement east, do not trust unknown native course 0',
        );
        expect(samples.last.assessment.confidence, HeadingConfidence.uncertain);
        await sub.cancel();
        await repository.controller.close();
      },
    );
    test(
      'disabled location service is unavailable, even with permission',
      () async {
        final FakeLocationRepository repository = FakeLocationRepository()
          ..enabled = false;
        expect(await GpsCourseSource(repository).isAvailable(), isFalse);
        await repository.controller.close();
      },
    );
  });
}
