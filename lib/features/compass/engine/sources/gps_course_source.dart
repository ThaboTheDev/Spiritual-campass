import 'dart:async';

import '../../../../core/geo/coordinates.dart';
import '../../../../data/repositories/location_repository.dart';
import '../heading_source.dart';

/// Rung 4: GPS course over ground while walking.
///
/// Only fixes that pass [GeoPoint.hasWalkingCourse] (speed above about 1 m/s,
/// a finite course, a sane accuracy when one is reported) become samples. The
/// course is referenced to **true** north, so [HeadingSample.isTrueNorth] is
/// `true` and no declination is ever added.
///
/// A standing user produces no samples, so this rung gets a long acquire
/// timeout: while it is "trying" the UI shows "Walk a few steps to get
/// direction" together with the sun guidance.
class GpsCourseSource implements HeadingSource {
  GpsCourseSource(
    this._repository, {
    this.walkTimeout = const Duration(minutes: 2),
    this.standingTimeout = const Duration(seconds: 8),
  });

  final LocationRepository _repository;

  /// How long we wait for the user to start walking before giving up.
  final Duration walkTimeout;

  /// How long after the last walking fix the heading is considered stale.
  final Duration standingTimeout;

  @override
  HeadingSourceKind get kind => HeadingSourceKind.gpsCourse;

  @override
  Duration? get acquireTimeout => walkTimeout;

  @override
  Duration? get staleTimeout => standingTimeout;

  @override
  Future<bool> isAvailable() async {
    try {
      final LocationAccess access = await _repository.checkAccess();
      return access.canRequestFix;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<HeadingSample> start() {
    return _repository.positionStream
        .where((GeoPoint point) => point.hasWalkingCourse)
        .map<HeadingSample>(
          (GeoPoint point) => HeadingSample(
            headingDeg: Angles.normalize360(point.courseDeg!),
            isTrueNorth: true,
            timestamp: DateTime.now(),
            accuracyDeg: point.courseAccuracyDeg,
          ),
        );
  }
}
