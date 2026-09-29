import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/centre.dart';

/// Reads the list of centres from the bundled `assets/centres.json`.
///
/// The file is the single source of truth for the Centres tab: edit the JSON to
/// add, rename or move a centre, and the map, the search and the grouped list
/// all follow. Nothing about the centres lives in Dart.
class CentresRepository {
  const CentresRepository({this.assetPath = 'assets/centres.json'});

  /// Path of the JSON file inside the asset bundle.
  final String assetPath;

  /// Loads every centre, sorted by region and then by name.
  ///
  /// Throws a [CentreFormatException] when the file is not valid JSON or an
  /// entry is missing its `id` / `name`.
  Future<List<Centre>> load() async {
    final String raw = await rootBundle.loadString(assetPath);
    return parse(raw);
  }

  /// Parses the raw JSON. Exposed (and unit tested) separately from [load] so
  /// the format can be checked without an asset bundle.
  List<Centre> parse(String raw) {
    if (raw.trim().isEmpty) {
      throw const CentreFormatException('The centres file is empty.');
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw CentreFormatException('The centres file is not valid JSON: $error');
    }

    List<Object?> entries;
    if (decoded is Map<String, dynamic>) {
      final Object? list = decoded['centres'];
      if (list is List<Object?>) {
        entries = list;
      } else {
        throw const CentreFormatException(
          'The centres file must contain a "centres" array.',
        );
      }
    } else if (decoded is List<Object?>) {
      entries = decoded;
    } else {
      throw const CentreFormatException(
        'The centres file must be a JSON array, or an object with a "centres" '
        'array.',
      );
    }

    final List<Centre> centres = <Centre>[];
    for (final Object? entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const CentreFormatException('Each centre must be a JSON object.');
      }
      centres.add(Centre.fromJson(entry));
    }
    return sort(centres);
  }

  /// Sorts by region (alphabetically) and then by centre name.
  static List<Centre> sort(List<Centre> centres) {
    final List<Centre> sorted = List<Centre>.of(centres)
      ..sort((Centre a, Centre b) {
        final int byRegion =
            a.region.toLowerCase().compareTo(b.region.toLowerCase());
        if (byRegion != 0) {
          return byRegion;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  /// Groups centres by region, preserving the sorted order of both the regions
  /// and the centres inside them.
  static List<RegionGroup> groupByRegion(List<Centre> centres) {
    final Map<String, List<Centre>> grouped = <String, List<Centre>>{};
    for (final Centre centre in centres) {
      grouped.putIfAbsent(centre.region, () => <Centre>[]).add(centre);
    }
    final List<String> regions = grouped.keys.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <RegionGroup>[
      for (final String region in regions)
        RegionGroup(region: region, centres: grouped[region]!),
    ];
  }
}

/// A region heading and the centres under it, ready for the list view.
class RegionGroup {
  const RegionGroup({required this.region, required this.centres});

  /// Region name, e.g. "Gauteng".
  final String region;

  /// Centres in that region, sorted by name.
  final List<Centre> centres;

  /// Number of centres in the region.
  int get count => centres.length;
}
