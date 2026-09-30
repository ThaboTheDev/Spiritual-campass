import '../../core/geo/coordinates.dart';

/// One entry of `assets/towns.json`: a named place with coordinates, used by
/// the Location tab's town picker.
class Town {
  const Town({
    required this.name,
    required this.group,
    required this.latitude,
    required this.longitude,
  });

  /// Parses `{"name": "...", "lat": -28.23, "lng": 28.307}` under a group.
  ///
  /// Throws [FormatException] on a missing field or an out-of-range value so
  /// that a corrupt asset is noticed in tests rather than silently dropped.
  factory Town.fromJson(Map<String, dynamic> json, {required String group}) {
    final Object? name = json['name'];
    final Object? lat = json['lat'];
    final Object? lng = json['lng'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Town without a name');
    }
    if (lat is! num || lng is! num) {
      throw FormatException('Town "$name" without coordinates');
    }
    if (lat.abs() > 90 || lng.abs() > 180) {
      throw FormatException('Town "$name" has out-of-range coordinates');
    }
    return Town(
      name: name.trim(),
      group: group,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }

  /// Display name, e.g. "Bloemfontein".
  final String name;

  /// Province / country heading, e.g. "Free State".
  final String group;

  /// Decimal degrees.
  final double latitude;

  /// Decimal degrees.
  final double longitude;

  /// The town as a point, with the region's fallback altitude.
  GeoPoint get point => GeoPoint(
        latitude: latitude,
        longitude: longitude,
        altitudeMetres: Ekuphumuleni.fallbackAltitudeMetres,
        label: name,
      );

  /// Case- and accent-insensitive search key.
  String get searchKey => normaliseForSearch('$name $group');

  /// Lower-cases and strips the accents that appear in a few place names
  /// (e.g. "Maputo", "Bié") so a plain keyboard finds them.
  static String normaliseForSearch(String value) {
    const String accented = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const String plain = 'aaaaaaeeeeiiiiooooouuuucn';
    final StringBuffer out = StringBuffer();
    for (final int rune in value.toLowerCase().runes) {
      final String ch = String.fromCharCode(rune);
      final int index = accented.indexOf(ch);
      out.write(index >= 0 ? plain[index] : ch);
    }
    return out.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is Town &&
      other.name == name &&
      other.group == group &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, group, latitude, longitude);

  @override
  String toString() => 'Town($name, $group, $latitude, $longitude)';
}

/// A province / country with its towns, in file order.
class TownGroup {
  const TownGroup({required this.name, required this.towns});

  final String name;
  final List<Town> towns;
}
