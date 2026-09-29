import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/angle_smoother.dart';
import '../../core/geo/coordinates.dart';
import '../../core/wmm/wmm.dart';
import '../../data/repositories/location_repository.dart';
import '../../services/compass_service.dart';
import '../location/location_controller.dart';

/// High level state of the compass.
enum CompassStatus {
  /// Not started: the user has not tapped "Start compass" yet.
  off,

  /// Permissions are being requested / the sensor is warming up.
  starting,

  /// Receiving heading samples.
  running,

  /// The device reports no compass sensor (or only null headings).
  noSensor,

  /// Location is needed before a true heading can be shown.
  locationRequired,

  /// Something else went wrong; see [CompassState.errorMessage].
  error,
}

/// Everything the compass screen needs for one frame.
class CompassState {
  const CompassState({
    this.status = CompassStatus.off,
    this.magneticHeadingDeg,
    this.trueHeadingDeg,
    this.declinationDeg,
    this.accuracyDeg,
    this.hasLocation = false,
    this.needsCalibration = false,
    this.errorMessage,
  });

  /// Whether the compass is off, starting, running, …
  final CompassStatus status;

  /// Smoothed *magnetic* heading in degrees (what the sensor reports).
  final double? magneticHeadingDeg;

  /// Smoothed heading corrected to *true* north with the WMM declination.
  final double? trueHeadingDeg;

  /// Declination at the user's position, in degrees (negative = west).
  final double? declinationDeg;

  /// Latest sensor accuracy in degrees (±).
  final double? accuracyDeg;

  /// Whether a location is available, i.e. whether [trueHeadingDeg] could be
  /// corrected to true north.
  final bool hasLocation;

  /// Whether the sensor accuracy is poor enough to ask for a figure-8.
  final bool needsCalibration;

  /// Unexpected errors only; known conditions are expressed by [status].
  final String? errorMessage;

  /// Whether usable headings are arriving.
  bool get isRunning => status == CompassStatus.running;

  /// Whether the user has started the compass at all.
  bool get isActive =>
      status == CompassStatus.starting ||
      status == CompassStatus.running ||
      status == CompassStatus.noSensor;

  CompassState copyWith({
    CompassStatus? status,
    double? magneticHeadingDeg,
    double? trueHeadingDeg,
    double? declinationDeg,
    double? accuracyDeg,
    bool? hasLocation,
    bool? needsCalibration,
    String? errorMessage,
    bool clearHeading = false,
    bool clearTrueHeading = false,
    bool clearDeclination = false,
    bool clearAccuracy = false,
    bool clearError = false,
  }) {
    return CompassState(
      status: status ?? this.status,
      magneticHeadingDeg: clearHeading
          ? null
          : (magneticHeadingDeg ?? this.magneticHeadingDeg),
      trueHeadingDeg: (clearHeading || clearTrueHeading)
          ? null
          : (trueHeadingDeg ?? this.trueHeadingDeg),
      declinationDeg: clearDeclination
          ? null
          : (declinationDeg ?? this.declinationDeg),
      accuracyDeg:
          clearAccuracy ? null : (accuracyDeg ?? this.accuracyDeg),
      hasLocation: hasLocation ?? this.hasLocation,
      needsCalibration: needsCalibration ?? this.needsCalibration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the compass sensor stream, the WMM correction and the smoothing.
///
/// Start it once (from the compass or msamo screen) and every screen reads the
/// same smoothed, declination-corrected heading.
class CompassController extends Notifier<CompassState> {
  /// Smoothing factor: high enough to feel responsive, low enough to kill the
  /// jitter of a hand-held magnetometer.
  static const double _smoothingAlpha = 0.18;

  /// UI update budget: ~30 fps, with large movements let through immediately.
  static const Duration _emitInterval = Duration(milliseconds: 33);

  /// How often the declination is recomputed while running (it drifts slowly).
  static const Duration _declinationRefresh = Duration(minutes: 30);

  final AngleSmoother _smoother = AngleSmoother(alpha: _smoothingAlpha);
  final HeadingThrottle _throttle =
      HeadingThrottle(minInterval: _emitInterval, minDeltaDeg: 0.2);

  StreamSubscription<CompassReading>? _subscription;
  Timer? _declinationTimer;
  int _nullHeadingSamples = 0;
  bool _disposed = false;

  @override
  CompassState build() {
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
      _subscription = null;
      _declinationTimer?.cancel();
      _declinationTimer = null;
    });

    // Keep the declination in step with the location, which can change because
    // of a manual entry, a fresh fix, or live movement.
    ref.listen<GeoPoint?>(
      effectiveLocationProvider,
      (GeoPoint? previous, GeoPoint? next) => _refreshDeclination(),
    );

    return const CompassState();
  }

  /// Requests location, then starts listening to the compass sensor.
  ///
  /// The compass is usable without location (the magnetic heading still moves
  /// the dial) and location is usable without a compass sensor (the bearing and
  /// distance are still correct), so a failure in either half is reported but
  /// never blocks the other.
  Future<void> start() async {
    if (state.isActive) {
      return;
    }
    state = state.copyWith(
      status: CompassStatus.starting,
      clearError: true,
    );

    // Location first: without it we cannot correct to true north.
    final LocationAccess access =
        await ref.read(locationControllerProvider.notifier).startTracking();
    if (_disposed) {
      return;
    }
    _refreshDeclination();

    final CompassService service = ref.read(compassServiceProvider);
    final Stream<CompassReading>? stream = service.readings;

    if (stream == null) {
      // flutter_compass only returns null on platforms without a compass at
      // all; the UI explains that the bearings are still available.
      state = state.copyWith(
        status: CompassStatus.noSensor,
        hasLocation: ref.read(effectiveLocationProvider) != null,
      );
      _startDeclinationTimer();
      return;
    }

    _smoother.reset();
    _throttle.reset();
    _nullHeadingSamples = 0;

    state = state.copyWith(
      status: CompassStatus.starting,
      hasLocation: ref.read(effectiveLocationProvider) != null,
    );

    _subscription = stream.listen(_onReading, onError: _onError);
    _startDeclinationTimer();

    // If location was denied we keep going: the dial still turns with the
    // magnetic heading, and `hasLocation` tells the UI that the true bearing,
    // the magnetic bearing and the declination cannot be shown yet.
    if (!access.canRequestFix) {
      state = state.copyWith(
        hasLocation: false,
        status: CompassStatus.running,
      );
    }
  }

  /// Stops the sensor stream and forgets the heading.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _declinationTimer?.cancel();
    _declinationTimer = null;
    _smoother.reset();
    _throttle.reset();
    if (!_disposed) {
      state = state.copyWith(
        status: CompassStatus.off,
        clearHeading: true,
        clearAccuracy: true,
      );
    }
  }

  void _onReading(CompassReading reading) {
    if (_disposed) {
      return;
    }

    if (!reading.hasHeading) {
      // Android returns a null heading when the sensor is missing or has not
      // been calibrated yet. A handful of consecutive nulls means "no sensor".
      _nullHeadingSamples++;
      if (_nullHeadingSamples >= 5 && !state.isRunning) {
        state = state.copyWith(status: CompassStatus.noSensor);
      }
      return;
    }

    _nullHeadingSamples = 0;

    final double magnetic = _smoother.push(reading.headingDeg!);
    final double? declination = state.declinationDeg ?? _computeDeclination();
    final double? trueHeading =
        declination == null ? null : Angles.normalize360(magnetic + declination);

    final bool poorAccuracy = _isPoorAccuracy(reading.accuracyDeg);

    if (!_throttle.shouldEmit(trueHeading ?? magnetic)) {
      return;
    }

    state = state.copyWith(
      status: CompassStatus.running,
      magneticHeadingDeg: magnetic,
      trueHeadingDeg: trueHeading,
      clearTrueHeading: trueHeading == null,
      declinationDeg: declination,
      clearDeclination: declination == null,
      accuracyDeg: reading.accuracyDeg,
      hasLocation: declination != null,
      needsCalibration: poorAccuracy,
      clearError: true,
    );
  }

  void _onError(Object error) {
    if (_disposed) {
      return;
    }
    state = state.copyWith(
      status: CompassStatus.error,
      errorMessage: error.toString(),
    );
  }

  /// iOS reports degrees of deviation; the Android side of flutter_compass maps
  /// the sensor status to 15 (high), 30 (medium), 45 (low) degrees. Anything
  /// from 30 degrees up — or unknown — deserves the figure-8 hint.
  static bool _isPoorAccuracy(double? accuracyDeg) {
    if (accuracyDeg == null) {
      return false;
    }
    return accuracyDeg >= 30.0;
  }

  void _startDeclinationTimer() {
    _declinationTimer?.cancel();
    _declinationTimer =
        Timer.periodic(_declinationRefresh, (_) => _refreshDeclination());
  }

  /// Recomputes the declination for the current position and refreshes the true
  /// heading from the last smoothed magnetic heading.
  void _refreshDeclination() {
    if (_disposed) {
      return;
    }
    final double? declination = _computeDeclination();
    final double? magnetic = _smoother.value;
    final double? trueHeading =
        (declination != null && magnetic != null)
            ? Angles.normalize360(magnetic + declination)
            : null;
    state = state.copyWith(
      declinationDeg: declination,
      clearDeclination: declination == null,
      trueHeadingDeg: trueHeading,
      clearTrueHeading: trueHeading == null,
      hasLocation: declination != null,
    );
  }

  /// Declination from the WMM at the user's position, altitude and the date.
  double? _computeDeclination() {
    final GeoPoint? point = ref.read(effectiveLocationProvider);
    if (point == null) {
      return null;
    }
    return Wmm2025.declinationDeg(
      latitudeDeg: point.latitude,
      longitudeDeg: point.longitude,
      altitudeKm: point.altitudeKm,
      when: DateTime.now(),
    );
  }
}

/// The live compass state.
final NotifierProvider<CompassController, CompassState>
    compassControllerProvider =
    NotifierProvider<CompassController, CompassState>(CompassController.new);
