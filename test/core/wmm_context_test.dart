import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/wmm/wmm.dart';
import 'package:tshk_compass/core/wmm/wmm_context.dart';

void main() {
  test('current model has an explicit, exclusive expiry date', () {
    expect(Wmm2025.isValidAt(DateTime.utc(2024, 12, 31)), isFalse);
    expect(Wmm2025.isValidAt(DateTime.utc(2025, 1, 1)), isTrue);
    expect(Wmm2025.isValidAt(DateTime.utc(2029, 12, 31)), isTrue);
    expect(Wmm2025.isValidAt(DateTime.utc(2030, 1, 1)), isFalse);
  });
  test(
    'field cache avoids harmonics per frame and refreshes on travel/date',
    () {
      final WmmContextCache cache = WmmContextCache();
      final DateTime at = DateTime.utc(2026, 1, 1);
      const GeoPoint point = GeoPoint(
        latitude: -26.2,
        longitude: 28,
        altitudeMetres: 1500,
      );
      final MagneticContext first = cache.evaluate(point, at);
      expect(
        identical(
          first.field,
          cache.evaluate(point.copyWith(longitude: 28.00001), at).field,
        ),
        isTrue,
      );
      expect(
        identical(
          first.field,
          cache.evaluate(point.copyWith(longitude: 28.01), at).field,
        ),
        isFalse,
      );
      expect(
        identical(
          first.field,
          cache.evaluate(point, at.add(const Duration(days: 1))).field,
        ),
        isFalse,
      );
      expect(
        cache.evaluate(point, DateTime.utc(2030, 1, 1)).declinationDeg,
        isNull,
      );
      expect(
        cache.evaluate(const GeoPoint(latitude: 100, longitude: 0), at).field,
        isNull,
      );
    },
  );
}
