import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/data/models/centre.dart';
import 'package:tshk_compass/data/repositories/centres_repository.dart';

const String _sampleJson = '''
{
  "version": 1,
  "centres": [
    {
      "id": "gauteng-pretoria",
      "name": "Pretoria",
      "region": "Gauteng",
      "address": "Cnr Bloed & Bosman Street, Pretoria",
      "phone": "+27 81 032 3331",
      "lat": -25.7461,
      "lng": 28.1881,
      "verified": false
    },
    {
      "id": "gauteng-ebhubesini",
      "name": "eBhubesini",
      "region": "Gauteng",
      "address": "10 Small Street, Marshalltown, Johannesburg",
      "town": "Marshalltown",
      "phone": "+27 67 300 3886",
      "lat": -26.2056,
      "lng": 28.0456
    },
    {
      "id": "kzn-durban",
      "name": "Durban",
      "region": "KwaZulu-Natal",
      "address": "1 Point Road, Durban",
      "phone": "+27 31 000 0000",
      "lat": -29.8579,
      "lng": 31.0292,
      "verified": true
    },
    {
      "id": "fs-bloem",
      "name": "Bloemfontein",
      "region": "Free State",
      "address": "",
      "phone": "",
      "lat": null,
      "lng": null
    }
  ]
}
''';

void main() {
  final CentresRepository repository = const CentresRepository();

  group('CentresRepository.parse', () {
    test('reads every centre', () {
      final List<Centre> centres = repository.parse(_sampleJson);
      expect(centres, hasLength(4));
    });

    test('sorts by region then name', () {
      final List<Centre> centres = repository.parse(_sampleJson);
      expect(centres.first.region, 'Free State');
      expect(centres[1].region, 'Gauteng');
      expect(centres[1].name, 'eBhubesini');
      expect(centres[2].name, 'Pretoria');
      expect(centres.last.region, 'KwaZulu-Natal');
    });

    test('maps every field', () {
      final Centre centre = repository
          .parse(_sampleJson)
          .firstWhere((Centre c) => c.id == 'gauteng-ebhubesini');
      expect(centre.name, 'eBhubesini');
      expect(centre.region, 'Gauteng');
      expect(centre.address, '10 Small Street, Marshalltown, Johannesburg');
      expect(centre.town, 'Marshalltown');
      expect(centre.phone, '+27 67 300 3886');
      expect(centre.lat, -26.2056);
      expect(centre.lng, 28.0456);
      expect(centre.verified, isTrue); // defaults to true when absent
      expect(centre.hasCoordinates, isTrue);
      expect(centre.hasPhone, isTrue);
      expect(centre.point!.latitude, -26.2056);
    });

    test('accepts a bare array as well', () {
      final List<Centre> centres = repository.parse(
        '[{"id": "a", "name": "A", "region": "Gauteng"}]',
      );
      expect(centres, hasLength(1));
      expect(centres.single.name, 'A');
      expect(centres.single.hasAddress, isFalse);
      expect(centres.single.hasPhone, isFalse);
      expect(centres.single.hasCoordinates, isFalse);
    });

    test('a centre without coordinates still lists', () {
      final Centre centre = repository
          .parse(_sampleJson)
          .firstWhere((Centre c) => c.id == 'fs-bloem');
      expect(centre.hasCoordinates, isFalse);
      expect(centre.point, isNull);
      expect(centre.hasAddress, isFalse);
      expect(centre.hasPhone, isFalse);
    });

    test('rejects broken JSON', () {
      expect(() => repository.parse('not json'),
          throwsA(isA<CentreFormatException>()));
    });

    test('rejects an object without a centres array', () {
      expect(() => repository.parse('{"foo": 1}'),
          throwsA(isA<CentreFormatException>()));
    });

    test('rejects an entry without an id', () {
      expect(
        () => repository.parse('[{"name": "No id", "region": "Gauteng"}]'),
        throwsA(isA<CentreFormatException>()),
      );
    });

    test('rejects an empty file', () {
      expect(() => repository.parse('   '),
          throwsA(isA<CentreFormatException>()));
    });
  });

  group('grouping', () {
    test('groups by region and counts', () {
      final List<RegionGroup> groups =
          CentresRepository.groupByRegion(repository.parse(_sampleJson));
      expect(groups, hasLength(3));
      expect(groups.first.region, 'Free State');
      expect(groups.first.count, 1);
      final RegionGroup gauteng =
          groups.firstWhere((RegionGroup g) => g.region == 'Gauteng');
      expect(gauteng.count, 2);
      expect(gauteng.centres.first.name, 'eBhubesini');
    });
  });

  group('Centre.matches', () {
    final List<Centre> centres = repository.parse(_sampleJson);

    test('matches the name, case-insensitively', () {
      expect(centres.firstWhere((Centre c) => c.name == 'eBhubesini')
          .matches('BHUBE'), isTrue);
    });

    test('matches the town and the address', () {
      expect(
          centres
              .firstWhere((Centre c) => c.name == 'eBhubesini')
              .matches('marshalltown'),
          isTrue);
      expect(
          centres
              .firstWhere((Centre c) => c.name == 'eBhubesini')
              .matches('small street'),
          isTrue);
    });

    test('matches the region', () {
      expect(
          centres
              .firstWhere((Centre c) => c.name == 'eBhubesini')
              .matches('gauteng'),
          isTrue);
    });

    test('an empty query matches everything', () {
      for (final Centre centre in centres) {
        expect(centre.matches('   '), isTrue);
      }
    });

    test('a miss returns false', () {
      expect(
          centres
              .firstWhere((Centre c) => c.name == 'eBhubesini')
              .matches('Cape Town'),
          isFalse);
    });
  });

  group('Centre json round trip', () {
    test('toJson keeps the fields the UI needs', () {
      final Centre centre = repository
          .parse(_sampleJson)
          .firstWhere((Centre c) => c.id == 'kzn-durban');
      final Map<String, dynamic> json = centre.toJson();
      expect(json['id'], 'kzn-durban');
      expect(json['name'], 'Durban');
      expect(json['region'], 'KwaZulu-Natal');
      expect(json['lat'], -29.8579);
      expect(json['lng'], 31.0292);
      expect(json['verified'], isTrue);
    });
  });
}
