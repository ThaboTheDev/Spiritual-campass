import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/data/models/town.dart';
import 'package:tshk_compass/data/repositories/towns_repository.dart';

const String _sample = '''
[
  {"group": "Free State", "towns": [
    {"name": "Welkom", "lat": -27.98, "lng": 26.73},
    {"name": "Bethlehem", "lat": -28.23, "lng": 28.307}
  ]},
  {"group": "Mozambique", "towns": [
    {"name": "Maputo", "lat": -25.97, "lng": 32.57}
  ]}
]
''';

void main() {
  group('TownsRepository.parse', () {
    test('keeps group order and sorts towns by name', () {
      final List<TownGroup> groups = TownsRepository.parse(_sample);
      expect(groups.map((TownGroup g) => g.name), <String>['Free State', 'Mozambique']);
      expect(groups.first.towns.map((Town t) => t.name), <String>['Bethlehem', 'Welkom']);
    });

    test('rejects a town without coordinates', () {
      expect(
        () => TownsRepository.parse('[{"group": "X", "towns": [{"name": "A"}]}]'),
        throwsFormatException,
      );
    });

    test('rejects out-of-range coordinates', () {
      expect(
        () => TownsRepository.parse(
            '[{"group": "X", "towns": [{"name": "A", "lat": 95, "lng": 0}]}]'),
        throwsFormatException,
      );
    });

    test('filter is case/accent-insensitive and drops empty groups', () {
      final List<TownGroup> groups = TownsRepository.parse(_sample);
      final List<TownGroup> hits = TownsRepository.filter(groups, 'MAPU');
      expect(hits, hasLength(1));
      expect(hits.single.towns.single.name, 'Maputo');
      expect(TownsRepository.filter(groups, ''), same(groups));
      expect(TownsRepository.filter(groups, 'zzz'), isEmpty);
      // Group names are searchable too.
      expect(TownsRepository.filter(groups, 'free').single.towns, hasLength(2));
    });

    test('a town becomes a labelled GeoPoint', () {
      final Town town = TownsRepository.parse(_sample).last.towns.single;
      expect(town.point.latitude, -25.97);
      expect(town.point.longitude, 32.57);
      expect(town.point.label, 'Maputo');
    });
  });

  test('assets/towns.json parses with valid coordinates', () {
    final File file = File('assets/towns.json');
    expect(file.existsSync(), isTrue);
    final List<TownGroup> groups = TownsRepository.parse(file.readAsStringSync());
    expect(groups, isNotEmpty);
    final List<Town> all = TownsRepository.flatten(groups);
    expect(all.length, greaterThan(50));
    for (final Town town in all) {
      expect(town.latitude, inInclusiveRange(-90.0, 90.0), reason: town.name);
      expect(town.longitude, inInclusiveRange(-180.0, 180.0), reason: town.name);
    }
  });
}
