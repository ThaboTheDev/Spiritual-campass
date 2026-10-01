import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Cancel owned one-shot work when the app stops / goes into the background.
  void cancelPendingFixes();

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
  GeolocatorLocationRepository({LocationSettings? locationSettings})
    : _locationSettings = locationSettings ?? _platformSettings();

  static LocationSettings _platformSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  final LocationSettings _locationSettings;
  // Unknown/reduced permission is never silently promoted to precise.
  bool _approximate = true;
  int _accuracyGeneration = 0;
  Completer<GeoPoint?>? _pendingFix;
  StreamSubscription<GeoPoint>? _fixSubscription;
  Timer? _fixTimer;

  Future<void> _refreshAccuracyStatus() async {
    final int generation = ++_accuracyGeneration;
    try {
      final LocationAccuracyStatus status =
          await Geolocator.getLocationAccuracy().timeout(
            const Duration(seconds: 3),
          );
      if (generation == _accuracyGeneration) {
        _approximate = status != LocationAccuracyStatus.precise;
      }
    } catch (_) {
      if (generation == _accuracyGeneration) {
        _approximate = true;
      }
    }
  }

  GeoPoint _point(Position position) => position.toGeoPoint().copyWith(
    isApproximate: _approximate || position.isMocked,
  );

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkAccess() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    final LocationAccess access = _mapPermission(permission);
    if (access.canRequestFix) {
      await _refreshAccuracyStatus();
    } else {
      _approximate = true;
    }
    return access;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationAccess.serviceDisabled;
    }
    final LocationPermission permission = await Geolocator.requestPermission();
    final LocationAccess access = _mapPermission(permission);
    if (access.canRequestFix) {
      await _refreshAccuracyStatus();
    } else {
      _approximate = true;
    }
    return access;
  }

  @override
  Future<GeoPoint?> getCurrentPoint() {
    final Completer<GeoPoint?>? current = _pendingFix;
    if (current != null) {
      return current.future;
    }
    final Completer<GeoPoint?> pending = Completer<GeoPoint?>();
    _pendingFix = pending;
    void finish(GeoPoint? point) {
      if (!identical(_pendingFix, pending)) {
        return;
      }
      _pendingFix = null;
      _fixTimer?.cancel();
      _fixTimer = null;
      final StreamSubscription<GeoPoint>? subscription = _fixSubscription;
      _fixSubscription = null;
      if (subscription != null) {
        unawaited(
          subscription
              .cancel()
              .timeout(const Duration(seconds: 1))
              .catchError((Object _) {}),
        );
      }
      if (!pending.isCompleted) {
        pending.complete(point);
      }
    }

    // Use an owned stream instead of Future.timeout(getCurrentPosition):
    // timing out a future alone does not cancel the native GPS request.
    _fixTimer = Timer(const Duration(seconds: 25), () => finish(null));
    try {
      final StreamSubscription<GeoPoint> subscription = positionStream.listen(
        (GeoPoint point) => finish(point),
        onError: (Object _, StackTrace __) => finish(null),
        onDone: () => finish(null),
      );
      if (identical(_pendingFix, pending)) {
        _fixSubscription = subscription;
      } else {
        unawaited(
          subscription
              .cancel()
              .timeout(const Duration(seconds: 1))
              .catchError((Object _) {}),
        );
      }
    } catch (_) {
      finish(null);
    }
    return pending.future;
  }

  @override
  void cancelPendingFixes() {
    final Completer<GeoPoint?>? pending = _pendingFix;
    _pendingFix = null;
    _fixTimer?.cancel();
    _fixTimer = null;
    final StreamSubscription<GeoPoint>? subscription = _fixSubscription;
    _fixSubscription = null;
    if (subscription != null) {
      unawaited(
        subscription
            .cancel()
            .timeout(const Duration(seconds: 1))
            .catchError((Object _) {}),
      );
    }
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }
  }

  @override
  Future<GeoPoint?> getLastKnownPoint() async {
    try {
      final Position? position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
      return position == null ? null : _point(position);
    } on PermissionDeniedException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  @override
  Stream<GeoPoint> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).map(_point);
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
    altitudeMetres: altitude.isFinite ? altitude : null,
    accuracyMetres: accuracy.isFinite && accuracy > 0 ? accuracy : null,
    timestamp: timestamp,
    isApproximate: isMocked,
    speedAccuracyMps: speedAccuracy.isFinite && speedAccuracy >= 0
        ? speedAccuracy
        : null,
    speedMps: speed.isFinite && speed >= 0 ? speed : null,
    courseDeg: heading.isFinite && heading >= 0 ? heading : null,
    courseAccuracyDeg: headingAccuracy.isFinite && headingAccuracy > 0
        ? headingAccuracy
        : null,
  );
}
