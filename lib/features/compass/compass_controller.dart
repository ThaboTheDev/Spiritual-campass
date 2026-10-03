import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/angle_smoother.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/heading_math.dart';
import '../../core/perf/performance_profile.dart';
import '../../core/sun/sun_position.dart';
import '../../core/wmm/wmm.dart';
import '../../data/repositories/location_repository.dart';
import '../../services/motion_sensors.dart';
import '../../services/wake_lock_service.dart';
import '../location/location_controller.dart';
import 'engine/heading_ladder.dart';
import 'engine/heading_source.dart';
import 'engine/sources/fused_compass_source.dart';
import 'engine/sources/gps_course_source.dart';
import 'engine/sources/raw_sensor_source.dart';
import 'engine/sources/relative_orientation_source.dart';

export 'engine/heading_ladder.dart' show LadderPhase;
export 'engine/heading_source.dart' show HeadingSourceKind, HeadingSourceKindX;
export 'engine/sources/relative_orientation_source.dart'
    show CalibrationAnchor;

/// High level state of the compass.
enum CompassStatus {
  /// Not started: the user has not tapped "Start compass" yet.
  off,

  /// Permissions are being requested / the ladder is looking for a sensor.
  starting,

  /// Receiving heading samples (or waiting for a one-tap calibration).
  running,

  /// Every rung failed: sun-only guidance. Bearings still work.
  noSensor,

  /// Location is needed before a true heading can be shown.
  locationRequired,

  /// Something else went wrong; see [CompassState.errorMessage].
  error,
}

/// Everything the compass and msamo screens need for one frame.
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
    this.source,
    this.ladderPhase = LadderPhase.idle,
    this.isStale = false,
    this.awaitingCalibration = false,
    this.calibrationAnchor,
    this.waitingForWalk = false,
    this.attitude,
    this.paused = false,
  });

  /// Whether the compass is off, starting, running, …
  final CompassStatus status;

  /// Smoothed *magnetic* heading in degrees, or `null` when the active source
  /// is true-north only and the declination is unknown.
  final double? magneticHeadingDeg;

  /// Smoothed heading corrected to *true* north, or `null` when the source is
  /// magnetic and there is no location for the WMM.
  final double? trueHeadingDeg;

  /// Declination at the user's position, in degrees (negative = west).
  final double? declinationDeg;

  /// Latest sensor accuracy in degrees (±).
  final double? accuracyDeg;

  /// Whether a location is available.
  final bool hasLocation;

  /// Whether the sensor accuracy is poor enough to ask for a figure-8.
  final bool needsCalibration;

  /// Unexpected errors only; known conditions are expressed by [status].
  final String? errorMessage;

  /// The rung of the ladder that is driving the dial.
  final HeadingSourceKind? source;

  /// Raw ladder phase (trying / active / stale / exhausted).
  final LadderPhase ladderPhase;

  /// The active sensor has gone quiet: "Move the phone to wake the compass".
  final bool isStale;

  /// The relative source is running but has not been anchored yet: show the
  /// two "Set" buttons.
  final bool awaitingCalibration;

  /// What the relative source was anchored to, once calibrated.
  final CalibrationAnchor? calibrationAnchor;

  /// The GPS rung is waiting for the user to walk.
  final bool waitingForWalk;

  /// Pitch / roll from the accelerometer, when one exists.
  final Attitude? attitude;

  /// Sensors were released because the app went to the background; they
  /// restart on resume.
  final bool paused;

  /// Whether usable headings are arriving.
  bool get isRunning => status == CompassStatus.running;

  /// Whether the user has started the compass at all.
  bool get isActive =>
      status == CompassStatus.starting ||
      status == CompassStatus.running ||
      status == CompassStatus.noSensor;

  /// Whether a heading (true or magnetic) is available for the dial.
  bool get hasHeading => trueHeadingDeg != null || magneticHeadingDeg != null;

  /// The best heading for the dial: true when known, otherwise magnetic.
  double? get dialHeadingDeg => trueHeadingDeg ?? magneticHeadingDeg;

  /// Whether a motion sensor is feeding the level bubble.
  bool get hasAttitude => attitude != null && isActive && !paused;

  /// "Flat · Ithe bha" when both angles are within 8°.
  bool get isFlat => attitude?.isFlat ?? false;

  /// Whether the sun-only fallback is in effect.
  bool get isSunOnly =>
      status == CompassStatus.noSensor || source == HeadingSourceKind.sunOnly;

  CompassState copyWith({
    CompassStatus? status,
    double? magneticHeadingDeg,
    double? trueHeadingDeg,
    double? declinationDeg,
    double? accuracyDeg,
    bool? hasLocation,
    bool? needsCalibration,
    String? errorMessage,
    HeadingSourceKind? source,
    LadderPhase? ladderPhase,
    bool? isStale,
    bool? awaitingCalibration,
    CalibrationAnchor? calibrationAnchor,
    bool? waitingForWalk,
    Attitude? attitude,
    bool? paused,
    bool clearHeading = false,
    bool clearTrueHeading = false,
    bool clearMagneticHeading = false,
    bool clearDeclination = false,
    bool clearAccuracy = false,
    bool clearError = false,
    bool clearSource = false,
    bool clearCalibrationAnchor = false,
    bool clearAttitude = false,
  }) {
    return CompassState(
      status: status ?? this.status,
      magneticHeadingDeg: (clearHeading || clearMagneticHeading)
          ? null
          : (magneticHeadingDeg ?? this.magneticHeadingDeg),
      trueHeadingDeg: (clearHeading || clearTrueHeading)
          ? null
          : (trueHeadingDeg ?? this.trueHeadingDeg),
      declinationDeg:
          clearDeclination ? null : (declinationDeg ?? this.declinationDeg),
      accuracyDeg: clearAccuracy ? null : (accuracyDeg ?? this.accuracyDeg),
      hasLocation: hasLocation ?? this.hasLocation,
      needsCalibration: needsCalibration ?? this.needsCalibration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      source: clearSource ? null : (source ?? this.source),
      ladderPhase: ladderPhase ?? this.ladderPhase,
      isStale: isStale ?? this.isStale,
      awaitingCalibration: awaitingCalibration ?? this.awaitingCalibration,
      calibrationAnchor: clearCalibrationAnchor
          ? null
          : (calibrationAnchor ?? this.calibrationAnchor),
      waitingForWalk: waitingForWalk ?? this.waitingForWalk,
      attitude: clearAttitude ? null : (attitude ?? this.attitude),
      paused: paused ?? this.paused,
    );
  }
}

/// Owns the heading ladder, the WMM correction, the smoothing, the level
/// bubble and the wake lock.
///
/// Start it once (from the Compass or Msamo screen) and every screen reads the
/// same smoothed, declination-corrected heading.
class CompassController extends Notifier<CompassState> {
  /// Smoothing factor: high enough to feel responsive, low enough to kill the
  /// jitter of a hand-held magnetometer.
  static const double _smoothingAlpha = 0.18;

  /// How often the declination is recomputed while running (it drifts slowly).
  static const Duration _declinationRefresh = Duration(minutes: 30);

  /// Level bubble update budget.
  static const Duration _attitudeInterval = Duration(milliseconds: 120);

  final AngleSmoother _smoother = AngleSmoother(alpha: _smoothingAlpha);
  HeadingThrottle _throttle = HeadingThrottle(
    minInterval: PerfSettings.normal.arrowFrameInterval,
    minDeltaDeg: 0.2,
  );
  final RelativeCalibration _calibration = RelativeCalibration();

  HeadingLadder? _ladder;
  StreamSubscription<HeadingSample>? _sampleSub;
  StreamSubscription<LadderStatus>? _statusSub;
  StreamSubscription<MotionSample>? _attitudeSub;
  Timer? _declinationTimer;
  DateTime? _lastAttitudeEmit;
  HeadingSourceKind? _smoothedSource;
  bool _wakeLocked = false;
  bool _disposed = false;

  @override
  CompassState build() {
    ref.onDispose(() {
      _disposed = true;
      _releaseSensors();
      _declinationTimer?.cancel();
      _declinationTimer = null;
      _releaseWakeLock();
    });

    // Keep the declination in step with the location, which can change because
    // of a manual entry, a fresh fix, or live movement.
    ref.listen<GeoPoint?>(
      effectiveLocationProvider,
      (GeoPoint? previous, GeoPoint? next) => _refreshDeclination(),
    );

    // Follow the performance profile (15 vs 30 fps arrow).
    ref.listen<PerfSettings>(perfSettingsProvider, (_, PerfSettings next) {
      _throttle = HeadingThrottle(
        minInterval: next.arrowFrameInterval,
        minDeltaDeg: 0.2,
      );
    });

    return const CompassState();
  }

  /// Requests location, then walks the ladder of heading sources.
  ///
  /// The compass is usable without location (the magnetic heading still moves
  /// the dial) and location is usable without a compass sensor (the bearing and
  /// distance are still correct), so a failure in either half is reported but
  /// never blocks the other.
  Future<void> start() async {
    if (state.isActive && !state.paused) {
      return;
    }
    state = state.copyWith(
      status: CompassStatus.starting,
      paused: false,
      clearError: true,
    );

    // Location first: without it we cannot correct to true north.
    final LocationAccess access =
        await ref.read(locationControllerProvider.notifier).startTracking();
    if (_disposed) {
      return;
    }
    _refreshDeclination();
    state = state.copyWith(
      hasLocation: ref.read(effectiveLocationProvider) != null,
    );

    _throttle = HeadingThrottle(
      minInterval: ref.read(perfSettingsProvider).arrowFrameInterval,
      minDeltaDeg: 0.2,
    );
    _startLadder();
    _startAttitude();
    _startDeclinationTimer();
    _acquireWakeLock();

    if (!access.canRequestFix) {
      // No location: the dial still turns; the true bearing, the magnetic
      // bearing and the declination cannot be shown yet.
      state = state.copyWith(hasLocation: false);
    }
  }

  /// Stops every sensor and forgets the heading.
  void stop() {
    _releaseSensors();
    _declinationTimer?.cancel();
    _declinationTimer = null;
    _releaseWakeLock();
    _calibration.clear();
    if (!_disposed) {
      state = state.copyWith(
        status: CompassStatus.off,
        ladderPhase: LadderPhase.idle,
        isStale: false,
        awaitingCalibration: false,
        waitingForWalk: false,
        paused: false,
        clearHeading: true,
        clearAccuracy: true,
        clearSource: true,
        clearCalibrationAnchor: true,
        clearAttitude: true,
      );
    }
  }

  /// Goes back to the top of the ladder ("Retry", or after the phone was
  /// moved to wake a stale sensor).
  void retry() {
    if (!state.isActive) {
      return;
    }
    _smoother.reset();
    _throttle.reset();
    state = state.copyWith(
      status: CompassStatus.starting,
      isStale: false,
      waitingForWalk: false,
      clearError: true,
    );
    if (_ladder == null) {
      _startLadder();
    } else {
      _ladder!.restart();
    }
  }

  /// The app went to the background: release the sensors and the wake lock,
  /// but remember that the compass was on so [onAppResumed] can restart it.
  void onAppPaused() {
    if (!state.isActive || state.paused) {
      return;
    }
    _releaseSensors();
    _releaseWakeLock();
    state = state.copyWith(paused: true, clearAttitude: true);
  }

  /// The app is back: start fresh (no spinning catch-up) if it was on.
  void onAppResumed() {
    if (!state.isActive || !state.paused) {
      return;
    }
    _smoother.reset();
    _throttle.reset();
    state = state.copyWith(
      paused: false,
      status: CompassStatus.starting,
      isStale: false,
      clearHeading: true,
    );
    _startLadder();
    _startAttitude();
    _acquireWakeLock();
  }

  // -------------------------------------------------------------- calibration

  /// "Set: the phone points at the sun". Anchors the relative source so its
  /// headings are *true*. Returns `false` when there is no location, the sun
  /// is below the horizon, or the turn sensor has not produced a sample yet.
  bool calibrateToSun() {
    final GeoPoint? point = ref.read(effectiveLocationProvider);
    if (point == null) {
      return false;
    }
    final SunPosition sun = SunCalculator.calculate(
      at: DateTime.now().toUtc(),
      latitudeDeg: point.latitude,
      longitudeDeg: point.longitude,
    );
    if (sun.elevationDeg < -1) {
      return false;
    }
    return _applyCalibration(sun.azimuthDeg, CalibrationAnchor.sun);
  }

  /// "Set: the phone points north" (with a hand compass, i.e. magnetic
  /// north). Headings are magnetic and the WMM declination applies.
  bool calibrateToNorth() => _applyCalibration(0, CalibrationAnchor.north);

  /// Forgets the one-tap calibration and shows the Set buttons again.
  void clearCalibration() {
    _calibration.clear();
    _smoother.reset();
    _throttle.reset();
    if (state.source == HeadingSourceKind.relativeCalibrated) {
      state = state.copyWith(
        awaitingCalibration: true,
        clearCalibrationAnchor: true,
        clearHeading: true,
      );
    }
  }

  bool _applyCalibration(double targetDeg, CalibrationAnchor anchor) {
    if (!_calibration.set(targetDeg, anchor)) {
      return false;
    }
    _smoother.reset();
    _throttle.reset();
    state = state.copyWith(
      awaitingCalibration: false,
      calibrationAnchor: anchor,
      clearHeading: true,
    );
    // Feed the current relative heading straight through so the dial reacts
    // without waiting for the next gyroscope sample.
    final double? relative = _calibration.latestRelativeDeg;
    final double? offset = _calibration.offsetDeg;
    if (relative != null && offset != null) {
      _onSample(
        HeadingSample(
          headingDeg: HeadingMath.applyOffset(relative, offset),
          isTrueNorth: _calibration.isTrueNorth,
          timestamp: DateTime.now(),
          accuracyDeg: RelativeOrientationSource.calibratedAccuracyDeg,
        ),
      );
    }
    return true;
  }

  // ------------------------------------------------------------------ ladder

  /// The rungs, best first. Kept in one place so tests and the README agree.
  List<HeadingSource> buildSources() {
    final MotionSensors sensors = ref.read(motionSensorsProvider);
    return <HeadingSource>[
      FusedCompassSource(ref.read(compassServiceProvider)),
      RawSensorSource(sensors),
      RelativeOrientationSource(sensors, _calibration),
      GpsCourseSource(ref.read(locationRepositoryProvider)),
    ];
  }

  void _startLadder() {
    _releaseLadder();
    _smoother.reset();
    _throttle.reset();
    _smoothedSource = null;
    final HeadingLadder ladder = HeadingLadder(sources: buildSources());
    _ladder = ladder;
    _statusSub = ladder.status.listen(_onLadderStatus);
    _sampleSub = ladder.samples.listen(_onSample, onError: _onError);
    ladder.start();
  }

  void _onLadderStatus(LadderStatus status) {
    if (_disposed) {
      return;
    }
    switch (status.phase) {
      case LadderPhase.idle:
        break;
      case LadderPhase.trying:
        state = state.copyWith(
          status: state.isRunning ? CompassStatus.running : CompassStatus.starting,
          source: status.source,
          ladderPhase: status.phase,
          isStale: false,
          awaitingCalibration: false,
          waitingForWalk: status.source == HeadingSourceKind.gpsCourse,
          clearCalibrationAnchor: true,
          // A new rung means a new reference: drop the old heading.
          clearHeading: status.source != _smoothedSource,
        );
      case LadderPhase.active:
        state = state.copyWith(
          status: CompassStatus.running,
          source: status.source,
          ladderPhase: status.phase,
          isStale: false,
          waitingForWalk: false,
          clearError: true,
        );
      case LadderPhase.stale:
        state = state.copyWith(
          ladderPhase: status.phase,
          isStale: true,
        );
      case LadderPhase.exhausted:
        state = state.copyWith(
          status: CompassStatus.noSensor,
          source: HeadingSourceKind.sunOnly,
          ladderPhase: status.phase,
          isStale: false,
          awaitingCalibration: false,
          waitingForWalk: false,
          clearHeading: true,
          clearAccuracy: true,
          clearCalibrationAnchor: true,
        );
    }
  }

  void _onSample(HeadingSample sample) {
    if (_disposed) {
      return;
    }
    final HeadingSourceKind? source = state.source;

    if (sample.isProvisional) {
      // Uncalibrated relative source: keep the rung, show the Set buttons.
      if (!state.awaitingCalibration || !state.isRunning) {
        state = state.copyWith(
          status: CompassStatus.running,
          awaitingCalibration: true,
          isStale: false,
          clearHeading: true,
          clearCalibrationAnchor: true,
        );
      }
      return;
    }

    if (_smoothedSource != source) {
      // Different rung, different reference frame: no sweeping catch-up.
      _smoother.reset();
      _throttle.reset();
      _smoothedSource = source;
    }

    final double smoothed = _smoother.push(sample.headingDeg);
    final double? declination = state.declinationDeg ?? _computeDeclination();

    final double? magnetic;
    final double? trueHeading;
    if (sample.isTrueNorth) {
      // GPS course / sun calibration: already true. Never add declination.
      trueHeading = smoothed;
      magnetic = declination == null
          ? null
          : Angles.normalize360(smoothed - declination);
    } else {
      magnetic = smoothed;
      trueHeading = declination == null
          ? null
          : HeadingMath.magneticToTrue(smoothed, declination);
    }

    if (!_throttle.shouldEmit(trueHeading ?? magnetic!)) {
      return;
    }

    state = state.copyWith(
      status: CompassStatus.running,
      magneticHeadingDeg: magnetic,
      clearMagneticHeading: magnetic == null,
      trueHeadingDeg: trueHeading,
      clearTrueHeading: trueHeading == null,
      declinationDeg: declination,
      clearDeclination: declination == null,
      accuracyDeg: sample.accuracyDeg,
      clearAccuracy: sample.accuracyDeg == null,
      hasLocation: ref.read(effectiveLocationProvider) != null,
      needsCalibration: _isPoorAccuracy(sample.accuracyDeg, source),
      awaitingCalibration: false,
      isStale: false,
      waitingForWalk: false,
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
  /// from 30 degrees up deserves the figure-8 hint — but only for magnetic
  /// sources; a figure-8 does nothing for GPS or a calibrated gyroscope.
  static bool _isPoorAccuracy(double? accuracyDeg, HeadingSourceKind? source) {
    if (accuracyDeg == null) {
      return false;
    }
    if (source != HeadingSourceKind.fusedCompass &&
        source != HeadingSourceKind.rawSensors) {
      return false;
    }
    return accuracyDeg >= 30.0;
  }

  // ---------------------------------------------------------------- attitude

  void _startAttitude() {
    _attitudeSub?.cancel();
    final PerfSettings perf = ref.read(perfSettingsProvider);
    _attitudeSub = ref
        .read(motionSensorsProvider)
        .accelerometer(samplingPeriod: perf.sensorInterval * 2)
        .listen(
      (MotionSample sample) {
        if (_disposed || !sample.vector.isUsable) {
          return;
        }
        final DateTime now = DateTime.now();
        final DateTime? last = _lastAttitudeEmit;
        if (last != null && now.difference(last) < _attitudeInterval) {
          return;
        }
        _lastAttitudeEmit = now;
        final Attitude attitude = Attitude.fromAccelerometer(sample.vector);
        final Attitude? previous = state.attitude;
        if (previous != null &&
            (previous.pitchDeg - attitude.pitchDeg).abs() < 0.5 &&
            (previous.rollDeg - attitude.rollDeg).abs() < 0.5) {
          return;
        }
        state = state.copyWith(attitude: attitude);
      },
      onError: (Object _, StackTrace __) {
        // No accelerometer: no bubble. Nothing else depends on it here.
        if (!_disposed) {
          state = state.copyWith(clearAttitude: true);
        }
      },
      cancelOnError: true,
    );
  }

  // -------------------------------------------------------------- wake lock

  void _acquireWakeLock() {
    if (_wakeLocked) {
      return;
    }
    _wakeLocked = true;
    final WakeLockService service = ref.read(wakeLockServiceProvider);
    unawaited(service.acquire());
  }

  void _releaseWakeLock() {
    if (!_wakeLocked) {
      return;
    }
    _wakeLocked = false;
    final WakeLockService service = ref.read(wakeLockServiceProvider);
    unawaited(service.release());
  }

  // ------------------------------------------------------------- housekeeping

  void _releaseLadder() {
    _statusSub?.cancel();
    _statusSub = null;
    _sampleSub?.cancel();
    _sampleSub = null;
    _ladder?.dispose();
    _ladder = null;
  }

  void _releaseSensors() {
    _releaseLadder();
    _attitudeSub?.cancel();
    _attitudeSub = null;
    _smoother.reset();
    _throttle.reset();
    _smoothedSource = null;
  }

  void _startDeclinationTimer() {
    _declinationTimer?.cancel();
    _declinationTimer =
        Timer.periodic(_declinationRefresh, (_) => _refreshDeclination());
  }

  /// Recomputes the declination for the current position and refreshes the
  /// other heading from the smoothed one.
  void _refreshDeclination() {
    if (_disposed) {
      return;
    }
    final double? declination = _computeDeclination();
    final double? smoothed = _smoother.value;
    final bool sourceIsTrue = _activeSampleIsTrue();

    double? magnetic = state.magneticHeadingDeg;
    double? trueHeading = state.trueHeadingDeg;
    if (smoothed != null) {
      if (sourceIsTrue) {
        trueHeading = smoothed;
        magnetic = declination == null
            ? null
            : Angles.normalize360(smoothed - declination);
      } else {
        magnetic = smoothed;
        trueHeading = declination == null
            ? null
            : HeadingMath.magneticToTrue(smoothed, declination);
      }
    }
    state = state.copyWith(
      declinationDeg: declination,
      clearDeclination: declination == null,
      magneticHeadingDeg: magnetic,
      clearMagneticHeading: magnetic == null,
      trueHeadingDeg: trueHeading,
      clearTrueHeading: trueHeading == null,
      hasLocation: declination != null,
    );
  }

  /// Whether the rung currently being smoothed delivers true-north headings.
  bool _activeSampleIsTrue() {
    switch (_smoothedSource) {
      case HeadingSourceKind.gpsCourse:
        return true;
      case HeadingSourceKind.relativeCalibrated:
        return _calibration.isTrueNorth;
      case HeadingSourceKind.fusedCompass:
      case HeadingSourceKind.rawSensors:
      case HeadingSourceKind.sunOnly:
      case null:
        return false;
    }
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

/// The live compass state, shared by the Compass and Msamo screens.
final NotifierProvider<CompassController, CompassState>
    compassControllerProvider =
    NotifierProvider<CompassController, CompassState>(CompassController.new);
