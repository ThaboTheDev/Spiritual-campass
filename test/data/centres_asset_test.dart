import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/data/models/centre.dart';
import 'package:tshk_compass/data/repositories/centres_repository.dart';

/// The bundled `assets/centres.json` is the single source of truth for the
/// Centres tab and the "Pick from centres" list.
void main() {
  late List<Centre> centres;

  setUpAll(() {
    final File file = File('assets/centres.json');
    expect(file.existsSync(), isTrue);
    centres = const CentresRepository().parse(file.readAsStringSync());
  });

  test('88 centres in 15 regions', () {
    expect(centres, hasLength(88));
    final Set<String> regions = centres.map((Centre c) => c.region).toSet();
    expect(regions, hasLength(15));
    expect(regions, contains('Gauteng'));
  });

  test('every centre has a unique id and valid coordinates',
      () {
    final Set<String> ids = <String>{};
    for (final Centre centre in centres) {
      expect(ids.add(centre.id), isTrue, reason: 'duplicate id ${centre.id}');
      expect(centre.hasCoordinates, isTrue, reason: centre.name);
      expect(centre.lat!, inInclusiveRange(-90.0, 90.0), reason: centre.name);
      expect(centre.lng!, inInclusiveRange(-180.0, 180.0), reason: centre.name);
    }
  });

  test('region headers carry counts, e.g. "GAUTENG · 20"', () {
    final List<RegionGroup> groups = CentresRepository.groupByRegion(centres);
    final RegionGroup gauteng =
        groups.firstWhere((RegionGroup g) => g.region == 'Gauteng');
    expect(gauteng.centres, hasLength(20));
    expect('${gauteng.region.toUpperCase()} · ${gauteng.centres.length}',
        'GAUTENG · 20');
  });
}
