import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/data/repositories/location_repository.dart';
import 'package:tshk_compass/features/compass/engine/heading_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/gps_course_source.dart';
import 'package:tshk_compass/features/compass/engine/sources/relative_orientation_source.dart';

class _FakeLocationRepository implements LocationRepository {
  final StreamController<GeoPoint> controller =
      StreamController<GeoPoint>.broadcast();

  @override
  Stream<GeoPoint> get positionStream => controller.stream;

  @override
  Future<LocationAccess> checkAccess() async => LocationAccess.whileInUse;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.whileInUse;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<GeoPoint?> getCurrentPoint() async => null;

  @override
  Future<GeoPoint?> getLastKnownPoint() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  double distanceBetween(GeoPoint from, GeoPoint to) => 0;
}

void main() {
  group('sun calibration offset', () {
    test('offset = sun azimuth − relative heading; result is TRUE north', () {
      final RelativeCalibration cal = RelativeCalibration();
      expect(cal.set(300, CalibrationAnchor.sun), isFalse,
          reason: 'no relative heading seen yet');

      cal.observe(40); // gyro says we have turned 40° since start
      expect(cal.set(300, CalibrationAnchor.sun), isTrue); // sun at 300° true
      expect(cal.offsetDeg, closeTo(260, 1e-9));
      expect(cal.isTrueNorth, isTrue);
      // Now facing the sun: heading must read the sun's azimuth.
      expect(HeadingMath.applyOffset(40, cal.offsetDeg!), closeTo(300, 1e-9));
      // Turn 90° right: 30° true.
      expect(HeadingMath.applyOffset(130, cal.offsetDeg!), closeTo(30, 1e-9));
    });

    test('north calibration is MAGNETIC (declination still applies)', () {
      final RelativeCalibration cal = RelativeCalibration();
      cal.observe(350);
      expect(cal.set(0, CalibrationAnchor.north), isTrue);
      expect(cal.offsetDeg, closeTo(10, 1e-9));
      expect(cal.isTrueNorth, isFalse);
      final double magnetic = HeadingMath.applyOffset(350, cal.offsetDeg!);
      expect(magnetic, closeTo(0, 1e-9));
      // Johannesburg: declination about -20° → true heading 340°.
      expect(HeadingMath.magneticToTrue(magnetic, -20), closeTo(340, 1e-9));
    });

    test('clear forgets the anchor but keeps the latest relative heading', () {
      final RelativeCalibration cal = RelativeCalibration();
      cal.observe(10);
      cal.set(90, CalibrationAnchor.sun);
      cal.clear();
      expect(cal.isCalibrated, isFalse);
      expect(cal.latestRelativeDeg, 10);
    });

    test('wraps across 0/360', () {
      expect(
        HeadingMath.calibrationOffset(targetHeadingDeg: 10, relativeHeadingDeg: 350),
        closeTo(20, 1e-9),
      );
      expect(
        HeadingMath.calibrationOffset(targetHeadingDeg: 350, relativeHeadingDeg: 10),
        closeTo(340, 1e-9),
      );
    });
  });

  group('GPS course', () {
    test('only walking fixes with a sane course are accepted', () {
      const GeoPoint standing = GeoPoint(
          latitude: -26, longitude: 28, speedMps: 0.2, courseDeg: 90);
      const GeoPoint walking = GeoPoint(
          latitude: -26, longitude: 28, speedMps: 1.4, courseDeg: 90,
          courseAccuracyDeg: 20);
      const GeoPoint noCourse =
          GeoPoint(latitude: -26, longitude: 28, speedMps: 1.4);
      const GeoPoint badCourse = GeoPoint(
          latitude: -26, longitude: 28, speedMps: 1.4, courseDeg: -1);
      const GeoPoint poorAccuracy = GeoPoint(
          latitude: -26, longitude: 28, speedMps: 1.4, courseDeg: 90,
          courseAccuracyDeg: 120);
      const GeoPoint unknownAccuracy = GeoPoint(
          latitude: -26, longitude: 28, speedMps: 1.4, courseDeg: 90,
          courseAccuracyDeg: 0);

      expect(standing.hasWalkingCourse, isFalse);
      expect(walking.hasWalkingCourse, isTrue);
      expect(noCourse.hasWalkingCourse, isFalse);
      expect(badCourse.hasWalkingCourse, isFalse);
      expect(poorAccuracy.hasWalkingCourse, isFalse);
      expect(unknownAccuracy.hasWalkingCourse, isTrue);
    });

    test('samples are flagged true-north so no declination is added',
        () async {
      final _FakeLocationRepository repo = _FakeLocationRepository();
      final GpsCourseSource source = GpsCourseSource(repo);
      expect(await source.isAvailable(), isTrue);

      final List<HeadingSample> samples = <HeadingSample>[];
      final StreamSubscription<HeadingSample> sub =
          source.start().listen(samples.add);

      repo.controller.add(const GeoPoint(
          latitude: -26, longitude: 28, speedMps: 0.1, courseDeg: 10));
      repo.controller.add(const GeoPoint(
          latitude: -26, longitude: 28, speedMps: 1.5, courseDeg: 123.4));
      await Future<void>.delayed(Duration.zero);

      expect(samples, hasLength(1));
      expect(samples.single.isTrueNorth, isTrue);
      expect(samples.single.headingDeg, closeTo(123.4, 1e-9));
      // The controller keeps true samples as-is: magnetic = true − declination.
      expect(
        Angles.normalize360(samples.single.headingDeg - (-20)),
        closeTo(143.4, 1e-9),
      );
      await sub.cancel();
      await repo.controller.close();
    });

    test('rung timeouts favour walking', () {
      final GpsCourseSource source = GpsCourseSource(_FakeLocationRepository());
      expect(source.kind, HeadingSourceKind.gpsCourse);
      expect(source.acquireTimeout, greaterThan(const Duration(seconds: 30)));
      expect(source.staleTimeout, const Duration(seconds: 8));
    });
  });
}
