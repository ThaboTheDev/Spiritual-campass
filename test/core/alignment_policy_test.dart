import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/alignment_policy.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/geo_math.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 1, 1);
  const TargetReading target = TargetReading(
    bearingDeg: 1,
    distanceKm: 100,
    bearingUncertaintyDeg: 0.2,
    isApproximate: false,
    locationReliable: true,
  );
  bool confirms({
    double? error = 1,
    HeadingConfidence confidence = HeadingConfidence.reliable,
    bool travel = false,
    bool relative = false,
    bool paused = false,
    bool stale = false,
    DateTime? at,
    DateTime? settled,
    TargetReading? reading,
  }) => AlignmentPolicy.confirms(
    trueHeadingDeg: 0,
    headingUncertaintyDeg: error,
    confidence: confidence,
    headingAt: at ?? now,
    stableSince: settled ?? now.subtract(const Duration(seconds: 2)),
    now: now,
    target: reading ?? target,
    travelDirection: travel,
    relativeHeading: relative,
    paused: paused,
    stale: stale,
  );

  test(
    'a fresh steady heading inside its combined uncertainty budget confirms',
    () {
      expect(confirms(), isTrue);
    },
  );
  test(
    'a needle on target does not overcome unknown or broad sensor error',
    () {
      expect(confirms(error: null), isFalse);
      expect(confirms(error: 0), isFalse);
      expect(confirms(error: 15), isFalse);
      expect(confirms(confidence: HeadingConfidence.uncertain), isFalse);
      expect(confirms(error: double.nan), isFalse);
    },
  );
  test('GPS course and relative anchors cannot confirm phone alignment', () {
    expect(confirms(travel: true), isFalse);
    expect(confirms(relative: true), isFalse);
  });
  test('stale, paused, unsettled or old headings never confirm', () {
    expect(confirms(stale: true), isFalse);
    expect(confirms(paused: true), isFalse);
    expect(confirms(at: now.subtract(const Duration(seconds: 3))), isFalse);
    expect(confirms(settled: now), isFalse);
  });
  test('manual / stale locations and near-target bearings cannot confirm', () {
    expect(
      confirms(reading: const TargetReading(bearingDeg: 1, distanceKm: 100)),
      isFalse,
    );
    expect(
      confirms(
        reading: const TargetReading(
          bearingDeg: 1,
          distanceKm: 0,
          bearingUncertaintyDeg: 0,
          locationReliable: true,
          isNearTarget: true,
        ),
      ),
      isFalse,
    );
  });
  test('location uncertainty is reflected in the target bearing', () {
    final GeoPoint far = GeoPoint(
      latitude: -26.2,
      longitude: 28,
      accuracyMetres: 10,
      timestamp: now,
      speedMps: 0,
      speedAccuracyMps: 0.1,
    );
    final TargetReading reading = GeoMath.readingTo(
      far,
      Ekuphumuleni.point,
      at: now,
    );
    expect(reading.locationReliable, isTrue);
    expect(reading.bearingUncertaintyDeg, lessThan(0.01));
    expect(
      GeoMath.readingTo(
        far.copyWith(isApproximate: true),
        Ekuphumuleni.point,
        at: now,
      ).locationReliable,
      isFalse,
    );
    expect(
      GeoMath.readingTo(
        far,
        Ekuphumuleni.point,
        at: now.add(const Duration(minutes: 1)),
      ).locationReliable,
      isFalse,
    );
    final TargetReading near = GeoMath.readingTo(
      GeoPoint(
        latitude: Ekuphumuleni.latitude,
        longitude: Ekuphumuleni.longitude,
        accuracyMetres: 10,
        timestamp: now,
      ),
      Ekuphumuleni.point,
      at: now,
    );
    expect(near.isNearTarget, isTrue);
    expect(near.bearingUncertaintyDeg, isNull);
  });
  test('equal positions with new course or timestamps are not equal fixes', () {
    final GeoPoint point = GeoPoint(
      latitude: 0,
      longitude: 0,
      timestamp: now,
      courseDeg: 0,
    );
    expect(point, isNot(point.copyWith(courseDeg: 90)));
    expect(
      point,
      isNot(point.copyWith(timestamp: now.add(const Duration(seconds: 1)))),
    );
  });
  test('a frozen mark cannot spend the live target error budget twice', () {
    expect(
      AlignmentPolicy.confirms(
        trueHeadingDeg: 0,
        headingUncertaintyDeg: 1,
        confidence: HeadingConfidence.reliable,
        headingAt: now,
        stableSince: now.subtract(const Duration(seconds: 2)),
        now: now,
        target: const TargetReading(
          bearingDeg: 2.9,
          distanceKm: 100,
          bearingUncertaintyDeg: 0.2,
          isApproximate: false,
          locationReliable: true,
        ),
        bearingOverride: 0,
      ),
      isFalse,
    );
  });
  test('invalid target errors and future heading acquisition are rejected', () {
    expect(confirms(at: now.add(const Duration(milliseconds: 1))), isFalse);
    expect(
      confirms(
        reading: const TargetReading(
          bearingDeg: 1,
          distanceKm: 100,
          bearingUncertaintyDeg: -1,
          isApproximate: false,
          locationReliable: true,
        ),
      ),
      isFalse,
    );
  });
  test(
    'location error grows with reported motion; old or unknown motion is not precise',
    () {
      final GeoPoint moving = GeoPoint(
        latitude: 0,
        longitude: 0,
        accuracyMetres: 1,
        timestamp: now,
        speedMps: 20,
        speedAccuracyMps: 1,
      );
      const GeoPoint destination = GeoPoint(latitude: 0.005, longitude: 0);
      final TargetReading reading = GeoMath.readingTo(
        moving,
        destination,
        at: now,
      );
      expect(reading.locationReliable, isTrue);
      expect(
        reading.bearingUncertaintyAt(now.add(const Duration(seconds: 2))),
        greaterThan(4),
      );
      expect(
        GeoMath.readingTo(
          moving,
          destination,
          at: now.add(const Duration(seconds: 4)),
        ).locationReliable,
        isFalse,
      );
      expect(
        GeoMath.readingTo(
          GeoPoint(
            latitude: 0,
            longitude: 0,
            accuracyMetres: 1,
            timestamp: now,
          ),
          destination,
          at: now,
        ).locationReliable,
        isFalse,
      );
      final DateTime later = now.add(const Duration(seconds: 2));
      expect(
        AlignmentPolicy.confirms(
          trueHeadingDeg: 0,
          headingUncertaintyDeg: 1,
          confidence: HeadingConfidence.reliable,
          headingAt: later,
          stableSince: now,
          now: later,
          target: reading,
        ),
        isFalse,
      );
      final TargetReading stationary = GeoMath.readingTo(
        moving.copyWith(speedMps: 0),
        destination,
        at: now,
      );
      final DateTime old = now.add(const Duration(seconds: 4));
      expect(
        AlignmentPolicy.confirms(
          trueHeadingDeg: 0,
          headingUncertaintyDeg: 1,
          confidence: HeadingConfidence.reliable,
          headingAt: old,
          stableSince: now,
          now: old,
          target: stationary,
        ),
        isFalse,
      );
    },
  );
}
