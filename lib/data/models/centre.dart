import '../../core/geo/coordinates.dart';

/// One spiritual centre (isikhungo), fetched from `GET /api/centres`.
///
/// The list is no longer bundled with the app: it is downloaded after login
/// (so it stays protected on the server) and kept in an app-private cache
/// for offline use. See `CentresRepository`.
class Centre {
  const Centre({
    required this.id,
    required this.name,
    required this.region,
    this.address = '',
    this.phone = '',
    this.town = '',
    this.lat,
    this.lng,
    this.verified = true,
  });

  /// Stable identifier, unique within the file.
  final String id;

  /// Display name, e.g. "eBhubesini".
  final String name;

  /// Region the centre is grouped under, e.g. "Gauteng".
  final String region;

  /// Street address as it should be shown (and passed to the maps app).
  final String address;

  /// Phone number in international format, e.g. "+27 67 300 3886".
  final String phone;

  /// Optional suburb / town, used by the search when present.
  final String town;

  /// Latitude in decimal degrees. `null` when not yet geocoded.
  final double? lat;

  /// Longitude in decimal degrees. `null` when not yet geocoded.
  final double? lng;

  /// `false` for coordinates that still need to be checked on the ground.
  final bool verified;

  /// Whether this centre can be shown on the map or used for directions.
  bool get hasCoordinates =>
      lat != null &&
      lng != null &&
      !lat!.isNaN &&
      !lng!.isNaN &&
      lat!.abs() <= 90 &&
      lng!.abs() <= 180;

  /// Whether a phone number is available.
  bool get hasPhone => phone.trim().isNotEmpty;

  /// Whether an address has been captured.
  bool get hasAddress => address.trim().isNotEmpty;

  /// The centre as a [GeoPoint], or `null` when it has no coordinates.
  GeoPoint? get point => hasCoordinates
      ? GeoPoint(latitude: lat!, longitude: lng!, label: name)
      : null;

  /// Case-insensitive match against name, town, address and region.
  bool matches(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return name.toLowerCase().contains(needle) ||
        town.toLowerCase().contains(needle) ||
        address.toLowerCase().contains(needle) ||
        region.toLowerCase().contains(needle);
  }

  /// Reads the long-form shape (`id`, `name`, `region`, …), used by the
  /// cache round trip and the tests. The wire format of `/api/centres` is
  /// the short one and is mapped by `CentresRepository.centreFromRemoteJson`.
  factory Centre.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim() ?? '';
    final String name = (json['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw const CentreFormatException(
        'Each centre needs an "id" and a "name".',
      );
    }
    return Centre(
      id: id,
      name: name,
      region: (json['region'] as String?)?.trim().isNotEmpty == true
          ? (json['region'] as String).trim()
          : 'Other',
      address: (json['address'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      town: (json['town'] as String?)?.trim() ?? '',
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      verified: json['verified'] is bool ? json['verified'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'region': region,
        'address': address,
        'phone': phone,
        if (town.isNotEmpty) 'town': town,
        'lat': lat,
        'lng': lng,
        'verified': verified,
      };

  static double? _toDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Centre &&
      other.id == id &&
      other.name == name &&
      other.region == region &&
      other.address == address &&
      other.phone == phone &&
      other.town == town &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(id, name, region, address, phone, town, lat, lng);

  @override
  String toString() => 'Centre($id, $name, $region)';
}

/// Thrown when a centre payload cannot be read.
class CentreFormatException implements Exception {
  const CentreFormatException(this.message);

  /// What is wrong with the file.
  final String message;

  @override
  String toString() => 'CentreFormatException: $message';
}
