import 'dart:async';
import 'dart:math' as math;

import '../../../../core/geo/coordinates.dart';
import '../../../../core/geo/geo_math.dart';
import '../../../../core/geo/heading_quality.dart';
import '../../../../data/repositories/location_repository.dart';
import '../heading_source.dart';

/// Travel direction, NEVER a phone-facing heading. Requires fresh, sustained
/// movement and real course uncertainty or a sufficiently long GPS baseline.
/// A stationary fix immediately removes the old travel arrow.
class GpsCourseSource implements HeadingSource {
  GpsCourseSource(
    this._repository, {
    this.walkTimeout = const Duration(minutes: 2),
    this.standingTimeout = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LocationRepository _repository;
  final DateTime Function() _now;
  final Duration walkTimeout;
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
      return await _repository.isServiceEnabled() &&
          (await _repository.checkAccess()).canRequestFix;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<HeadingSample> start() {
    GeoPoint? baseline;
    final List<GeoPoint> history = <GeoPoint>[];
    DateTime? lastFix;
    int movingFixes = 0;
    return _repository.positionStream.map((GeoPoint point) {
      final DateTime at = point.timestamp ?? _now();
      HeadingSample waiting() => HeadingSample(
        headingDeg: 0,
        isTrueNorth: true,
        timestamp: at,
        isProvisional: true,
        assessment: const HeadingAssessment(
          HeadingConfidence.uncertain,
          HeadingIssue.waitingForMovement,
        ),
      );
      if (!point.hasMovementFixAt(_now()) ||
          (lastFix != null &&
              (at.difference(lastFix!).isNegative ||
                  at.difference(lastFix!) > const Duration(seconds: 4)))) {
        baseline = null;
        history.clear();
        movingFixes = 0;
        lastFix = point.timestamp;
        return waiting();
      }
      if (at == lastFix) {
        return waiting();
      }
      lastFix = at;
      baseline ??= point;
      history.add(point);
      history.removeWhere(
        (GeoPoint fix) =>
            at.difference(fix.timestamp!) > const Duration(seconds: 60),
      );
      if (history.length > 64) {
        history.removeAt(0);
      }
      movingFixes++;
      if (movingFixes < 3 ||
          at.difference(baseline!.timestamp!) < const Duration(seconds: 2)) {
        return waiting();
      }

      final double? nativeAccuracy = point.courseAccuracyDeg;
      if (point.hasWalkingCourseAt(_now()) && nativeAccuracy != null) {
        return HeadingSample(
          headingDeg: point.courseDeg!,
          isTrueNorth: true,
          timestamp: at,
          accuracyDeg: nativeAccuracy,
          assessment: nativeAccuracy <= 10 && !point.isApproximate
              ? HeadingAssessment.reliable
              : const HeadingAssessment(
                  HeadingConfidence.uncertain,
                  HeadingIssue.accuracyUnknown,
                ),
        );
      }
      // Older hardware may not report course accuracy. Do not accept speed
      // alone: infer a course only after displacement dominates both fix radii.
      GeoPoint? start;
      double distance = 0;
      double radii = 0;
      // Use the shortest recent baseline that dominates position uncertainty.
      for (final GeoPoint candidate in history.reversed.skip(1)) {
        final double length =
            GeoMath.distanceBetweenKm(candidate, point) * 1000;
        final double radiusSum =
            candidate.accuracyMetres! + point.accuracyMetres!;
        if (length >= math.max(10, radiusSum * 2.5)) {
          start = candidate;
          distance = length;
          radii = radiusSum;
          break;
        }
      }
      if (start == null) {
        return waiting();
      }
      final double course = GeoMath.bearingBetween(start, point);
      final double geometricError = Angles.toDegrees(
        math.asin((radii / distance).clamp(0, 1)),
      );
      return HeadingSample(
        headingDeg: course,
        isTrueNorth: true,
        timestamp: at,
        accuracyDeg: geometricError,
        assessment: const HeadingAssessment(
          HeadingConfidence.uncertain,
          HeadingIssue.accuracyUnknown,
        ),
      );
    });
  }
}
