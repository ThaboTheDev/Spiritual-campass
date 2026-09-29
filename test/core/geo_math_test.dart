import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/geo/geo_math.dart';

void main() {
  group('Angles', () {
    test('normalize360 keeps values in [0, 360)', () {
      expect(Angles.normalize360(0), 0);
      expect(Angles.normalize360(360), 0);
      expect(Angles.normalize360(-10), 350);
      expect(Angles.normalize360(725), closeTo(5, 1e-9));
    });

    test('normalize180 keeps values in [-180, 180]', () {
      expect(Angles.normalize180(0), 0);
      expect(Angles.normalize180(190), -170);
      expect(Angles.normalize180(-190), 170);
    });

    test('shortestDelta takes the short way round', () {
      // 350 -> 10 is +20, not -340.
      expect(Angles.shortestDelta(350, 10), closeTo(20, 1e-9));
      expect(Angles.shortestDelta(10, 350), closeTo(-20, 1e-9));
      expect(Angles.shortestDelta(0, 180).abs(), 180);
    });

    test('difference is symmetric and unsigned', () {
      expect(Angles.difference(10, 350), closeTo(20, 1e-9));
      expect(Angles.difference(350, 10), closeTo(20, 1e-9));
    });
  });

  group('initialBearingDeg', () {
    test('due north, due east, due south, due west', () {
      expect(GeoMath.initialBearingDeg(lat1: 0, lon1: 0, lat2: 10, lon2: 0),
          closeTo(0, 1e-6));
      expect(GeoMath.initialBearingDeg(lat1: 0, lon1: 0, lat2: 0, lon2: 10),
          closeTo(90, 1e-6));
      expect(GeoMath.initialBearingDeg(lat1: 10, lon1: 0, lat2: 0, lon2: 0),
          closeTo(180, 1e-6));
      expect(GeoMath.initialBearingDeg(lat1: 0, lon1: 0, lat2: 0, lon2: -10),
          closeTo(270, 1e-6));
    });

    test('Johannesburg to Ekuphumuleni is 187.33 degrees', () {
      const GeoPoint johannesburg =
          GeoPoint(latitude: -26.2041, longitude: 28.0473);
      final double bearing =
          GeoMath.bearingBetween(johannesburg, Ekuphumuleni.point);
      expect(bearing, closeTo(187.3341, 0.01));
    });

    test('London to New York is 288.33 degrees', () {
      const GeoPoint london = GeoPoint(latitude: 51.5074, longitude: -0.1278);
      const GeoPoint newYork = GeoPoint(latitude: 40.7128, longitude: -74.0060);
      final double bearing = GeoMath.bearingBetween(london, newYork);
      expect(bearing, closeTo(288.3297, 0.01));
    });

    test('Cape Town to Ekuphumuleni is 60.75 degrees', () {
      const GeoPoint capeTown =
          GeoPoint(latitude: -33.9249, longitude: 18.4241);
      final double bearing =
          GeoMath.bearingBetween(capeTown, Ekuphumuleni.point);
      expect(bearing, closeTo(60.7486, 0.01));
    });
  });

  group('distanceKm', () {
    test('one degree of latitude is about 111.2 km', () {
      final double distance =
          GeoMath.distanceKm(lat1: 0, lon1: 0, lat2: 1, lon2: 0);
      expect(distance, closeTo(111.195, 0.01));
    });

    test('Johannesburg to Ekuphumuleni is 321.99 km', () {
      const GeoPoint johannesburg =
          GeoPoint(latitude: -26.2041, longitude: 28.0473);
      final double distance =
          GeoMath.distanceBetweenKm(johannesburg, Ekuphumuleni.point);
      expect(distance, closeTo(321.9857, 0.01));
    });

    test('London to New York is 5570.23 km', () {
      const GeoPoint london = GeoPoint(latitude: 51.5074, longitude: -0.1278);
      const GeoPoint newYork = GeoPoint(latitude: 40.7128, longitude: -74.0060);
      final double distance = GeoMath.distanceBetweenKm(london, newYork);
      expect(distance, closeTo(5570.2299, 0.01));
    });

    test('Cape Town to Ekuphumuleni is 1024.81 km', () {
      const GeoPoint capeTown =
          GeoPoint(latitude: -33.9249, longitude: 18.4241);
      final double distance =
          GeoMath.distanceBetweenKm(capeTown, Ekuphumuleni.point);
      expect(distance, closeTo(1024.8122, 0.01));
    });

    test('a point to itself is zero', () {
      const GeoPoint point = GeoPoint(latitude: -29.07547, longitude: 27.62453);
      expect(GeoMath.distanceBetweenKm(point, point), closeTo(0, 1e-9));
    });
  });

  group('readingTo', () {
    test('returns bearing and distance together', () {
      const GeoPoint johannesburg =
          GeoPoint(latitude: -26.2041, longitude: 28.0473);
      final TargetReading reading =
          GeoMath.readingTo(johannesburg, Ekuphumuleni.point);
      expect(reading.bearingDeg, closeTo(187.3341, 0.01));
      expect(reading.distanceKm, closeTo(321.9857, 0.01));
    });
  });

  group('true <-> magnetic', () {
    test('magnetic = true - declination, around the compass', () {
      // Johannesburg: about 20.6 degrees west, so magnetic is bigger.
      expect(GeoMath.trueToMagnetic(10, -20.6), closeTo(30.6, 1e-9));
      expect(GeoMath.trueToMagnetic(350, -20.6), closeTo(10.6, 1e-9));
      expect(GeoMath.trueToMagnetic(10, 5), closeTo(5, 1e-9));
    });

    test('true = magnetic + declination', () {
      expect(GeoMath.magneticToTrue(30.6, -20.6), closeTo(10, 1e-9));
      expect(GeoMath.magneticToTrue(5, 5), closeTo(10, 1e-9));
    });
  });

  group('Ekuphumuleni', () {
    test('matches the published coordinates', () {
      expect(Ekuphumuleni.latitude, -29.07547);
      expect(Ekuphumuleni.longitude, 27.62453);
      expect(Ekuphumuleni.point.latitude, -29.07547);
      expect(Ekuphumuleni.point.longitude, 27.62453);
    });
  });
}
