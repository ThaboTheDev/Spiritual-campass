import 'dart:convert';

import '../../features/membership/membership_api.dart';
import '../local/centres_cache.dart';
import '../models/centre.dart';

/// The centres as the Centres tab needs them: the list, the regions the
/// server knows about, and where the data came from.
class CentresData {
  const CentresData({
    this.centres = const <Centre>[],
    this.regions = const <String>[],
    this.fromCache = false,
    this.offline = false,
    this.blocked = false,
  });

  /// Nothing to show.
  static const CentresData empty = CentresData();

  /// Every centre, sorted by region then name.
  final List<Centre> centres;

  /// Region names as sent by the server (used by the admin "Add centre"
  /// dropdown). Falls back to the regions found in [centres].
  final List<String> regions;

  /// The list came from the offline cache, not from the server.
  final bool fromCache;

  /// The server could not be reached on the last attempt.
  final bool offline;

  /// The server refused the list (401 / 402). The gate decides what happens
  /// next; the screen just shows an empty state.
  final bool blocked;

  bool get isEmpty => centres.isEmpty;

  CentresData copyWith({
    List<Centre>? centres,
    List<String>? regions,
    bool? fromCache,
    bool? offline,
    bool? blocked,
  }) =>
      CentresData(
        centres: centres ?? this.centres,
        regions: regions ?? this.regions,
        fromCache: fromCache ?? this.fromCache,
        offline: offline ?? this.offline,
        blocked: blocked ?? this.blocked,
      );
}

/// Fetches the centres from `GET /api/centres` and keeps the last good copy
/// in an app-private cache so the list still works offline.
///
/// The JSON is deliberately terse on the wire (`{id, r, n, a, p, la, lo}`);
/// [parseRemote] maps it onto [Centre]. Sorting, grouping and searching are
/// unchanged from the bundled-asset version.
class CentresRepository {
  const CentresRepository({required this.api, required this.cache});

  final MembershipApiClient api;
  final CentresCache cache;

  /// `GET /api/centres`, cached on success.
  ///
  /// Throws [MembershipOffline] when the host is unreachable and
  /// [MembershipApiException] for a non-2xx answer (notably 402
  /// `subscription_required`), so the caller can decide.
  Future<CentresData> fetchRemote(String accessToken) async {
    final Map<String, dynamic> body = await api.centres(accessToken);
    final CentresData data = parseRemote(body);
    await cache.write(jsonEncode(body));
    return data;
  }

  /// The last good list, or `null` when nothing is cached (or it is corrupt).
  Future<CentresData?> readCache() async {
    final String? raw = await cache.read();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return parseRemote(decoded).copyWith(fromCache: true);
    } catch (_) {
      return null;
    }
  }

  /// Drops the cached list (log out, 401, 402).
  Future<void> clearCache() => cache.clear();

  /// Maps `{regions:[…], centres:[{id,r,n,a,p,la,lo}]}` onto [CentresData].
  ///
  /// Entries that cannot be read (no id, no name) are skipped rather than
  /// failing the whole list: one bad row must not hide the other 87 centres.
  static CentresData parseRemote(Map<String, dynamic> body) {
    final List<Centre> centres = <Centre>[];
    final Object? rawCentres = body['centres'];
    if (rawCentres is List<Object?>) {
      for (final Object? entry in rawCentres) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final Centre? centre = centreFromRemoteJson(entry);
        if (centre != null) {
          centres.add(centre);
        }
      }
    }

    final List<String> regions = <String>[];
    final Object? rawRegions = body['regions'];
    if (rawRegions is List<Object?>) {
      for (final Object? region in rawRegions) {
        final String name = region?.toString().trim() ?? '';
        if (name.isNotEmpty && !regions.contains(name)) {
          regions.add(name);
        }
      }
    }
    if (regions.isEmpty) {
      for (final Centre centre in centres) {
        if (!regions.contains(centre.region)) {
          regions.add(centre.region);
        }
      }
    }
    regions.sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return CentresData(centres: sort(centres), regions: regions);
  }

  /// One wire row → [Centre]; `null` when it has no usable id or name.
  static Centre? centreFromRemoteJson(Map<String, dynamic> json) {
    final String name = (json['n'] ?? json['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return null;
    }
    final String region = (json['r'] ?? json['region'] ?? '').toString().trim();
    final String id = (json['id'] ?? '').toString().trim();
    return Centre(
      id: id.isNotEmpty ? id : _slug('$region-$name'),
      name: name,
      region: region.isNotEmpty ? region : 'Other',
      address: (json['a'] ?? json['address'] ?? '').toString().trim(),
      phone: (json['p'] ?? json['phone'] ?? '').toString().trim(),
      lat: _toDouble(json['la'] ?? json['lat']),
      lng: _toDouble(json['lo'] ?? json['lng']),
    );
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

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
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
