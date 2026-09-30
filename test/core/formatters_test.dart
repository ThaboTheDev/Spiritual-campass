import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/format/formatters.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/core/l10n/app_language.dart';

void main() {
  group('Formatters.distanceKm', () {
    test('metres under a kilometre', () {
      expect(Formatters.distanceKm(0.85), '850 m');
      expect(Formatters.distanceKm(0.0), '0 m');
    });

    test('one decimal under ten kilometres', () {
      expect(Formatters.distanceKm(9.44), '9.4 km');
      expect(Formatters.distanceKm(1.0), '1.0 km');
    });

    test('grouped whole kilometres with a thin space', () {
      expect(Formatters.distanceKm(1234), '1${Formatters.thinSpace}234 km');
      expect(Formatters.distanceKm(321.9857), '322 km');
      expect(Formatters.distanceKm(10842), '10${Formatters.thinSpace}842 km');
    });

    test('an unknown distance is a dash', () {
      expect(Formatters.distanceKm(null), '—');
    });
  });

  group('Formatters.bearing', () {
    test('rounds to whole degrees with a degree sign', () {
      expect(Formatters.bearing(318.4), '318°');
      expect(Formatters.bearing(0), '0°');
      expect(Formatters.bearing(359.6), '360°');
    });

    test('adds the cardinal point', () {
      expect(Formatters.bearingWithCardinal(318), '318° NW');
      expect(Formatters.bearingWithCardinal(0), '0° N');
      expect(Formatters.bearingWithCardinal(90), '90° E');
      expect(Formatters.bearingWithCardinal(180), '180° S');
      expect(Formatters.bearingWithCardinal(270), '270° W');
    });

    test('cardinal points are 16-point', () {
      expect(Formatters.cardinal(0), 'N');
      expect(Formatters.cardinal(45), 'NE');
      expect(Formatters.cardinal(22.5 + 1), 'NNE');
      expect(Formatters.cardinal(135), 'SE');
      expect(Formatters.cardinal(225), 'SW');
      expect(Formatters.cardinal(315), 'NW');
    });
  });

  group('Formatters.declination', () {
    test('west is negative and east positive', () {
      expect(Formatters.declination(-20.61), '20.6° W');
      expect(Formatters.declination(3.14), '3.1° E');
      expect(Formatters.declination(null), '—');
    });
  });

  group('Formatters coordinates', () {
    test('lat/lon with hemispheres', () {
      expect(Formatters.latLon(-26.2041, 28.0473),
          '26.2041° S, 28.0473° E');
      expect(Formatters.geoPoint(null), '—');
      expect(
        Formatters.geoPoint(
          const GeoPoint(latitude: -29.07547, longitude: 27.62453),
          decimals: 5,
        ),
        '29.07547° S, 27.62453° E',
      );
    });

    test('decimal degrees to DMS', () {
      expect(Formatters.dms(-29.0754722, 'S', 'N'), '29° 04′ 31.7″ S');
      expect(Formatters.dms(27.6245278, 'W', 'E'), '27° 37′ 28.3″ E');
      expect(Formatters.dmsPair(Ekuphumuleni.latitude, Ekuphumuleni.longitude),
          Ekuphumuleni.dms);
    });
  });

  group('Formatters in Portuguese (L = leste, O = oeste)', () {
    tearDown(() => L10n.setLanguage(AppLanguage.fallback));

    test('compass points', () {
      expect(Formatters.cardinal(90, language: AppLanguage.pt), 'L');
      expect(Formatters.cardinal(270, language: AppLanguage.pt), 'O');
      expect(Formatters.cardinal(315, language: AppLanguage.pt), 'NO');
      expect(Formatters.cardinal(90, language: AppLanguage.zu), 'E');
    });

    test('declination and coordinates', () {
      expect(Formatters.declination(-20.61, language: AppLanguage.pt),
          '20.6° O');
      expect(Formatters.latLon(-26.2041, 28.0473, language: AppLanguage.pt),
          '26.2041° S, 28.0473° L');
      expect(
        Formatters.dmsPair(Ekuphumuleni.latitude, Ekuphumuleni.longitude,
            language: AppLanguage.pt),
        '29° 04′ 31.7″ S   27° 37′ 28.3″ L',
      );
    });

    test('follows the app language by default', () {
      L10n.setLanguage(AppLanguage.pt);
      expect(Formatters.bearingWithCardinal(90), '90° L');
      L10n.setLanguage(AppLanguage.en);
      expect(Formatters.bearingWithCardinal(90), '90° E');
    });
  });

  group('Formatters.groupDigits', () {
    test('groups in threes and keeps the sign', () {
      expect(Formatters.groupDigits(1234567),
          '1${Formatters.thinSpace}234${Formatters.thinSpace}567');
      expect(Formatters.groupDigits(-1234), '−1${Formatters.thinSpace}234');
      expect(Formatters.groupDigits(42), '42');
    });
  });

  group('Formatters.accuracy and altitude', () {
    test('accuracy has a plus/minus sign', () {
      expect(Formatters.accuracyMetres(5), '± 5 m');
      expect(Formatters.accuracyMetres(0.4), '± 0.4 m');
      expect(Formatters.accuracyMetres(null), '—');
    });

    test('altitude is grouped metres', () {
      expect(Formatters.altitudeMetres(1753), '1${Formatters.thinSpace}753 m');
      expect(Formatters.altitudeMetres(null), '—');
    });
  });
}
