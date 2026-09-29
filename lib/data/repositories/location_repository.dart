import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/geo/coordinates.dart';

/// What the platform currently allows us to do with the device location.
enum LocationAccess {
  /// We have not asked yet, or the answer is unknown.
  unknown,

  /// Location while the app is in use is granted.
  whileInUse,

  /// Always-allowed (granted on Android 10+ / iOS); more than we need.
  always,

  /// The user said no, and we may ask again.
  denied,

  /// The user said no and asked not to be asked again: only Settings helps.
  deniedForever,

  /// Location services are switched off at the system level.
  serviceDisabled,
}

extension LocationAccessX on LocationAccess {
  /// Whether a fix can be requested right now.
  bool get canRequestFix =>
      this == LocationAccess.whileInUse || this == LocationAccess.always;

  /// Whether the user has to be sent to Settings to make progress.
  bool get needsSettings =>
      this == LocationAccess.deniedForever ||
      this == LocationAccess.serviceDisabled;
}

/// Everything the app needs from the platform location stack.
///
/// Wrapping geolocator keeps the controllers free of plugin types, which makes
/// them straightforward to unit test and to swap later.
abstract class LocationRepository {
  /// Whether the device location services are switched on.
  Future<bool> isServiceEnabled();

  /// The current permission state, without prompting.
  Future<LocationAccess> checkAccess();

  /// Asks the user for location permission and returns the outcome.
  Future<LocationAccess> requestAccess();

  /// One-shot fix. Returns `null` when no fix could be obtained.
  Future<GeoPoint?> getCurrentPoint();

  /// Continuous updates while the app is in use.
  Stream<GeoPoint> get positionStream;

  /// The last fix the platform still has cached, or `null`.
  Future<GeoPoint?> getLastKnownPoint();

  /// Opens this app's system settings page (used when permission is denied
  /// forever).
  Future<bool> openAppSettings();

  /// Opens the system location settings page (used when the service is off).
  Future<bool> openLocationSettings();

  /// Straight-line distance in metres between two points.
  double distanceBetween(GeoPoint from, GeoPoint to);
}

/// geolocator-backed implementation of [LocationRepository].
class GeolocatorLocationRepository implements LocationRepository {
  GeolocatorLocationRepository({
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  }) : _locationSettings = locationSettings;

  final LocationSettings _locationSettings;

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkAccess() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<LocationAccess> requestAccess() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationAccess.serviceDisabled;
    }
    final LocationPermission permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<GeoPoint?> getCurrentPoint() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      return position.toGeoPoint();
    } on LocationServiceDisabledException {
      return null;
    } on PermissionDeniedException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  @override
  Future<GeoPoint?> getLastKnownPoint() async {
    try {
      final Position? position = await Geolocator.getLastKnownPosition();
      return position?.toGeoPoint();
    } on PermissionDeniedException {
      return null;
    }
  }

  @override
  Stream<GeoPoint> get positionStream {
    return Geolocator.getPositionStream(locationSettings: _locationSettings)
        .map((Position position) => position.toGeoPoint());
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  double distanceBetween(GeoPoint from, GeoPoint to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  static LocationAccess _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return LocationAccess.always;
      case LocationPermission.whileInUse:
        return LocationAccess.whileInUse;
      case LocationPermission.denied:
        return LocationAccess.denied;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationAccess.unknown;
    }
  }
}

/// Converts a geolocator [Position] into the app's own [GeoPoint].
extension PositionToGeoPoint on Position {
  GeoPoint toGeoPoint() => GeoPoint(
        latitude: latitude,
        longitude: longitude,
        altitudeMetres: altitude,
        accuracyMetres: accuracy,
      );
}
