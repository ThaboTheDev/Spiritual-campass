import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/coordinates.dart';
import '../../data/repositories/location_repository.dart';

/// Where the position the app is using came from.
enum LocationSource {
  /// No position at all yet.
  none,

  /// Live GPS / network fix from the device.
  gps,

  /// A location the user entered by hand or picked from the centres list.
  manual,
}

/// Everything the Location screen and the compass need to know about "where am
/// I".
class LocationState {
  const LocationState({
    required this.access,
    required this.tracking,
    required this.loading,
    required this.source,
    this.gpsPoint,
    this.manualPoint,
    this.errorMessage,
  });

  /// What the platform currently allows.
  final LocationAccess access;

  /// Whether we are subscribed to live updates.
  final bool tracking;

  /// Whether a fix is being fetched right now.
  final bool loading;

  /// Which of [gpsPoint] / [manualPoint] is in effect.
  final LocationSource source;

  /// Most recent live fix, when live tracking is on.
  final GeoPoint? gpsPoint;

  /// The saved manual location, when the user has chosen one.
  final GeoPoint? manualPoint;

  /// Unexpected errors, for the rare case the UI has nothing better to say.
  final String? errorMessage;

  /// The point every bearing and distance is measured from.
  ///
  /// A manual location always wins: it is there precisely because GPS could not
  /// be used.
  GeoPoint? get effectivePoint => manualPoint ?? gpsPoint;

  /// Whether the effective point came from a manual entry.
  bool get isManual => source == LocationSource.manual && manualPoint != null;

  /// Whether any position is available at all.
  bool get hasPoint => effectivePoint != null;

  /// Whether location is completely unavailable (no fix and no manual point).
  bool get isEmpty => effectivePoint == null;

  LocationState copyWith({
    LocationAccess? access,
    bool? tracking,
    bool? loading,
    LocationSource? source,
    GeoPoint? gpsPoint,
    GeoPoint? manualPoint,
    String? errorMessage,
    bool clearGpsPoint = false,
    bool clearManualPoint = false,
    bool clearError = false,
  }) {
    return LocationState(
      access: access ?? this.access,
      tracking: tracking ?? this.tracking,
      loading: loading ?? this.loading,
      source: source ?? this.source,
      gpsPoint: clearGpsPoint ? null : (gpsPoint ?? this.gpsPoint),
      manualPoint: clearManualPoint ? null : (manualPoint ?? this.manualPoint),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns location permission, live tracking and the manual override.
///
/// All bearings and distances in the app are measured from
/// [LocationState.effectivePoint], so a manual location set on the Location tab
/// changes every screen at once.
class LocationController extends Notifier<LocationState> {
  StreamSubscription<GeoPoint>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  Future<LocationAccess>? _starting;
  late LocationRepository _repository;

  @override
  LocationState build() {
    _repository = ref.read(locationRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _repository.cancelPendingFixes();
      unawaited(_cancelSubscription());
    });

    final GeoPoint? stored = ref.watch(preferencesStoreProvider).manualLocation;
    return LocationState(
      access: LocationAccess.unknown,
      tracking: false,
      loading: false,
      source: stored != null ? LocationSource.manual : LocationSource.none,
      manualPoint: stored,
    );
  }

  /// Asks for permission, takes one fix and keeps tracking.
  ///
  /// Returns the access state afterwards so callers can explain what happened
  /// (for example "location services are off").
  Future<LocationAccess> startTracking() {
    if (_starting != null) {
      return _starting!;
    }
    if (state.tracking) {
      return Future<LocationAccess>.value(state.access);
    }
    final int generation = ++_generation;
    final Future<LocationAccess> pending = _startTracking(generation);
    _starting = pending;
    pending.then((_) {
      if (identical(_starting, pending)) {
        _starting = null;
      }
    });
    return pending;
  }

  Future<LocationAccess> _startTracking(int generation) async {
    state = state.copyWith(loading: true, clearError: true);
    bool current() => !_disposed && generation == _generation;
    try {
      final LocationAccess access = await _repository.requestAccess();
      if (!current()) {
        return access;
      }
      state = state.copyWith(access: access);
      if (!access.canRequestFix) {
        state = state.copyWith(loading: false);
        return access;
      }
      final GeoPoint? cached = await _repository.getLastKnownPoint();
      if (!current()) {
        return access;
      }
      if (cached != null) {
        _acceptFix(cached);
      }
      await _subscribe(generation);
      if (!current()) {
        return access;
      }
      final GeoPoint? point = await _repository.getCurrentPoint();
      if (!current()) {
        return access;
      }
      if (point != null) {
        _acceptFix(point);
      }
      state = state.copyWith(loading: false);
      return access;
    } catch (error) {
      if (current()) {
        _onError(error);
      }
      return _disposed ? LocationAccess.unknown : state.access;
    }
  }

  /// Takes a single fresh fix without starting continuous tracking.
  Future<LocationAccess> refreshOnce() async {
    final int generation = _generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final LocationAccess access = await _repository.requestAccess();
      if (_disposed || generation != _generation) {
        return access;
      }
      state = state.copyWith(access: access);
      if (!access.canRequestFix) {
        state = state.copyWith(loading: false);
        return access;
      }
      final GeoPoint? point = await _repository.getCurrentPoint();
      if (_disposed || generation != _generation) {
        return access;
      }
      if (point != null) {
        _acceptFix(point);
      }
      state = state.copyWith(loading: false);
      return access;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _onError(error);
      }
      return _disposed ? LocationAccess.unknown : state.access;
    }
  }

  /// Stops listening for updates. The last fix is kept.
  void stopTracking() {
    _generation++;
    _starting = null;
    _repository.cancelPendingFixes();
    unawaited(_cancelSubscription());
    if (!_disposed) {
      state = state.copyWith(tracking: false, loading: false);
    }
  }

  /// Saves a manually entered location and uses it from now on.
  Future<void> useManualLocation(GeoPoint point, {String? label}) async {
    final GeoPoint stored = point.copyWith(label: label, isApproximate: true);
    await ref.read(preferencesStoreProvider).saveManualLocation(stored);
    if (_disposed) {
      return;
    }
    state = state.copyWith(
      manualPoint: stored,
      source: LocationSource.manual,
      clearError: true,
    );
  }

  /// Forgets the manual location and goes back to live GPS.
  Future<void> useLiveGps() async {
    await ref.read(preferencesStoreProvider).clearManualLocation();
    if (_disposed) {
      return;
    }
    state = state.copyWith(
      clearManualPoint: true,
      source: state.gpsPoint != null ? LocationSource.gps : LocationSource.none,
    );
    if (state.gpsPoint == null) {
      await startTracking();
    }
  }

  /// Opens the app settings (for a permanent denial) or the system location
  /// settings (when the service is off).
  Future<void> openSettings() async {
    final LocationAccess access = await _repository.checkAccess();
    if (access == LocationAccess.serviceDisabled) {
      await _repository.openLocationSettings();
      return;
    }
    await _repository.openAppSettings();
  }

  Future<void> _cancelSubscription() async {
    final StreamSubscription<GeoPoint>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel().timeout(const Duration(seconds: 1));
      } catch (_) {
        /* Native cancellation must not trap a new session. */
      }
    }
  }

  Future<void> _subscribe(int generation) async {
    await _cancelSubscription();
    if (_disposed || generation != _generation) {
      return;
    }
    _subscription = _repository.positionStream.listen(
      (GeoPoint point) {
        if (generation == _generation) {
          _onPosition(point);
        }
      },
      onError: (Object error) {
        if (generation == _generation) {
          _onError(error);
        }
      },
      onDone: () {
        if (!_disposed && generation == _generation) {
          _subscription = null;
          state = state.copyWith(tracking: false, loading: false);
        }
      },
    );
    if (!_disposed) {
      state = state.copyWith(tracking: true);
    }
  }

  void _onPosition(GeoPoint point) => _acceptFix(point);

  void _acceptFix(GeoPoint point) {
    if (_disposed || !point.isValid) {
      return;
    }
    final DateTime? previous = state.gpsPoint?.timestamp;
    if (previous != null &&
        (point.timestamp == null || point.timestamp!.isBefore(previous))) {
      return;
    }
    state = state.copyWith(
      gpsPoint: point,
      source: state.isManual ? state.source : LocationSource.gps,
      access: state.access == LocationAccess.unknown
          ? LocationAccess.whileInUse
          : state.access,
      loading: false,
      clearError: true,
    );
  }

  void _onError(Object error) {
    if (_disposed) {
      return;
    }
    unawaited(_cancelSubscription());
    state = state.copyWith(
      loading: false,
      tracking: false,
      errorMessage: error.toString(),
    );
  }
}

/// The live location state.
final NotifierProvider<LocationController, LocationState>
locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

/// The point every bearing and distance is measured from, or `null`.
final Provider<GeoPoint?> effectiveLocationProvider = Provider<GeoPoint?>(
  (ref) => ref.watch(locationControllerProvider).effectivePoint,
);
