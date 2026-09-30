import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/town.dart';

/// Loads the grouped town list from `assets/towns.json`.
///
/// The file is a list of `{"group": "...", "towns": [...]}` objects. Groups
/// keep their file order (South African provinces first, then neighbouring
/// countries); towns inside a group are sorted by name.
class TownsRepository {
  TownsRepository({AssetBundle? bundle, this.assetPath = 'assets/towns.json'})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  List<TownGroup>? _cache;

  /// Loads (once) and returns the groups.
  Future<List<TownGroup>> load() async {
    final List<TownGroup>? cached = _cache;
    if (cached != null) {
      return cached;
    }
    final String raw = await _bundle.loadString(assetPath);
    final List<TownGroup> groups = parse(raw);
    _cache = groups;
    return groups;
  }

  /// Parses the JSON text. Pure, so tests can feed it strings.
  static List<TownGroup> parse(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('towns.json must be a list of groups');
    }
    final List<TownGroup> groups = <TownGroup>[];
    for (final Object? entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Group entry is not an object');
      }
      final Object? name = entry['group'];
      final Object? towns = entry['towns'];
      if (name is! String || name.trim().isEmpty) {
        throw const FormatException('Group without a name');
      }
      if (towns is! List) {
        throw FormatException('Group "$name" has no towns list');
      }
      final List<Town> parsed = <Town>[
        for (final Object? town in towns)
          if (town is Map<String, dynamic>)
            Town.fromJson(town, group: name.trim())
          else
            throw FormatException('Town entry in "$name" is not an object'),
      ]..sort((Town a, Town b) => a.name.compareTo(b.name));
      groups.add(TownGroup(name: name.trim(), towns: parsed));
    }
    return groups;
  }

  /// Every town, flattened, in group order.
  static List<Town> flatten(List<TownGroup> groups) =>
      <Town>[for (final TownGroup g in groups) ...g.towns];

  /// Filters the groups by a free-text query, keeping group order and
  /// dropping empty groups. An empty query returns everything.
  static List<TownGroup> filter(List<TownGroup> groups, String query) {
    final String q = Town.normaliseForSearch(query.trim());
    if (q.isEmpty) {
      return groups;
    }
    final List<String> words = q.split(RegExp(r'\s+'));
    return <TownGroup>[
      for (final TownGroup group in groups)
        if (group.towns.any((Town t) => _matches(t, words)))
          TownGroup(
            name: group.name,
            towns: group.towns.where((Town t) => _matches(t, words)).toList(),
          ),
    ];
  }

  static bool _matches(Town town, List<String> words) {
    final String key = town.searchKey;
    return words.every(key.contains);
  }
}
