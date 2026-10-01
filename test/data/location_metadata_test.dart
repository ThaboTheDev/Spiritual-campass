import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/data/repositories/location_repository.dart';

void main() {
  test(
    'native fix preserves acquisition time and error; invalid courses do not become 359°',
    () {
      final DateTime at = DateTime.utc(2026, 1, 1);
      final Position position = Position(
        latitude: -26,
        longitude: 28,
        timestamp: at,
        accuracy: 8,
        altitude: 1500,
        altitudeAccuracy: 4,
        heading: -1,
        headingAccuracy: -1,
        speed: -1,
        speedAccuracy: 0.2,
        isMocked: true,
      );
      final GeoPoint point = position.toGeoPoint();
      expect(point.timestamp, at);
      expect(point.accuracyMetres, 8);
      expect(point.speedAccuracyMps, 0.2);
      expect(point.courseDeg, isNull);
      expect(point.courseAccuracyDeg, isNull);
      expect(point.speedMps, isNull);
      expect(
        point.isApproximate,
        isTrue,
        reason: 'mocked positions cannot confirm alignment',
      );
    },
  );
}
