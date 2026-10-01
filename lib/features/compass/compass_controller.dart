import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/alignment_policy.dart';
import '../../core/geo/angle_smoother.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../core/geo/heading_math.dart';
import '../../core/geo/heading_quality.dart';
import '../../core/perf/performance_profile.dart';
import '../../core/sun/sun_position.dart';
import '../../core/wmm/wmm_context.dart';
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

export '../../core/geo/heading_quality.dart'
    show HeadingConfidence, HeadingIssue;
export 'engine/heading_ladder.dart' show LadderPhase;
export 'engine/heading_source.dart' show HeadingSourceKind, HeadingSourceKindX;
export 'engine/sources/relative_orientation_source.dart' show CalibrationAnchor;

enum CompassStatus { off, starting, running, noSensor, locationRequired, error }

enum CompassMode { phoneHeading, travelDirection }

class CompassState {
  const CompassState({
    this.status = CompassStatus.off,
    this.mode = CompassMode.phoneHeading,
    this.magneticHeadingDeg,
    this.trueHeadingDeg,
    this.declinationDeg,
    this.accuracyDeg,
    this.trueAccuracyDeg,
    this.confidence = HeadingConfidence.unreliable,
    this.issue = HeadingIssue.none,
    this.sampleAt,
    this.stableSince,
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

  final CompassStatus status;
  final CompassMode mode;
  final double? magneticHeadingDeg;
  final double? trueHeadingDeg;
  final double? declinationDeg;

  /// Platform-reported uncertainty, not a hard-coded vendor status mapping.
  final double? accuracyDeg;

  /// Includes filter lag and model uncertainty for magnetic → true correction.
  final double? trueAccuracyDeg;
  final HeadingConfidence confidence;
  final HeadingIssue issue;
  final DateTime? sampleAt;
  final DateTime? stableSince;
  final bool hasLocation;
  final bool needsCalibration;
  final String? errorMessage;
  final HeadingSourceKind? source;
  final LadderPhase ladderPhase;
  final bool isStale;
  final bool awaitingCalibration;
  final CalibrationAnchor? calibrationAnchor;
  final bool waitingForWalk;
  final Attitude? attitude;
  final bool paused;

  bool get isRunning => status == CompassStatus.running;
  bool get isActive =>
      status == CompassStatus.starting ||
      status == CompassStatus.running ||
      status == CompassStatus.noSensor;
  bool get hasHeading => dialHeadingDeg != null;
  bool get isTravelDirection => mode == CompassMode.travelDirection;
  double? get dialHeadingDeg =>
      paused ||
          isStale ||
          confidence == HeadingConfidence.unreliable ||
          !isRunning
      ? null
      : trueHeadingDeg ?? magneticHeadingDeg;
  bool get hasAttitude =>
      attitude != null && isActive && !paused && !isTravelDirection;
  bool get isFlat => attitude?.isFlat ?? false;
  bool get isSunOnly =>
      status == CompassStatus.noSensor || source == HeadingSourceKind.sunOnly;

  bool isAlignedTo(
    TargetReading? target,
    DateTime now, {
    double? bearingOverride,
  }) => AlignmentPolicy.confirms(
    trueHeadingDeg: trueHeadingDeg,
    headingUncertaintyDeg: trueAccuracyDeg,
    confidence: confidence,
    headingAt: sampleAt,
    stableSince: stableSince,
    now: now,
    target: target,
    travelDirection: isTravelDirection || source == HeadingSourceKind.gpsCourse,
    relativeHeading: source == HeadingSourceKind.relativeCalibrated,
    paused: paused || !isRunning,
    stale: isStale,
    bearingOverride: bearingOverride,
  );

  CompassState copyWith({
    CompassStatus? status,
    CompassMode? mode,
    double? magneticHeadingDeg,
    double? trueHeadingDeg,
    double? declinationDeg,
    double? accuracyDeg,
    double? trueAccuracyDeg,
    HeadingConfidence? confidence,
    HeadingIssue? issue,
    DateTime? sampleAt,
    DateTime? stableSince,
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
    bool clearTrueAccuracy = false,
    bool clearError = false,
    bool clearSource = false,
    bool clearCalibrationAnchor = false,
    bool clearAttitude = false,
    bool clearSample = false,
    bool clearStable = false,
  }) => CompassState(
    status: status ?? this.status,
    mode: mode ?? this.mode,
    magneticHeadingDeg: clearHeading || clearMagneticHeading
        ? null
        : magneticHeadingDeg ?? this.magneticHeadingDeg,
    trueHeadingDeg: clearHeading || clearTrueHeading
        ? null
        : trueHeadingDeg ?? this.trueHeadingDeg,
    declinationDeg: clearDeclination
        ? null
        : declinationDeg ?? this.declinationDeg,
    accuracyDeg: clearAccuracy ? null : accuracyDeg ?? this.accuracyDeg,
    trueAccuracyDeg: clearAccuracy || clearTrueAccuracy
        ? null
        : trueAccuracyDeg ?? this.trueAccuracyDeg,
    confidence: confidence ?? this.confidence,
    issue: issue ?? this.issue,
    sampleAt: clearSample ? null : sampleAt ?? this.sampleAt,
    stableSince: clearStable ? null : stableSince ?? this.stableSince,
    hasLocation: hasLocation ?? this.hasLocation,
    needsCalibration: needsCalibration ?? this.needsCalibration,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    source: clearSource ? null : source ?? this.source,
    ladderPhase: ladderPhase ?? this.ladderPhase,
    isStale: isStale ?? this.isStale,
    awaitingCalibration: awaitingCalibration ?? this.awaitingCalibration,
    calibrationAnchor: clearCalibrationAnchor
        ? null
        : calibrationAnchor ?? this.calibrationAnchor,
    waitingForWalk: waitingForWalk ?? this.waitingForWalk,
    attitude: clearAttitude ? null : attitude ?? this.attitude,
    paused: paused ?? this.paused,
  );
}

/// Shared engine for Compass and Msamo. Quality runs at acquisition rate;
/// rendering is separately capped, and GPS never masquerades as phone heading.
class CompassController extends Notifier<CompassState> {
  final AngleSmoother _smoother = AngleSmoother();
  HeadingThrottle _throttle = HeadingThrottle();
  late RelativeCalibration _calibration;
  HeadingLadder? _ladder;
  StreamSubscription<HeadingSample>? _sampleSub;
  StreamSubscription<LadderStatus>? _statusSub;
  StreamSubscription<MotionSample>? _attitudeSub;
  Timer? _heartbeat;
  DateTime? _lastAttitudeEmit;
  DateTime? _lastAttitudeSample;
  double _filterError = 0;
  DateTime? _stableSince;
  DateTime? _lastInputAt;
  double? _stableHeading;
  bool? _sampleIsTrue;
  double _screenAngle = 0;
  bool _wakeLocked = false;
  late WakeLockService _wakeLock;
  Future<void> _wakeOperation = Future<void>.value();
  Future<void> _sensorShutdown = Future<void>.value();
  bool _disposed = false;
  bool _sensorsStarted = false;
  int _session = 0;

  DateTime get _now => ref.read(compassClockProvider)();
  MagneticContext get _context => ref
      .read(wmmContextCacheProvider)
      .evaluate(ref.read(effectiveLocationProvider), _now);

  @override
  CompassState build() {
    _wakeLock = ref.read(wakeLockServiceProvider);
    _calibration = RelativeCalibration(now: ref.read(compassClockProvider));
    ref.onDispose(() {
      _disposed = true;
      _session++;
      _releaseSensors();
      _releaseWakeLock();
    });
    ref.listen<GeoPoint?>(
      effectiveLocationProvider,
      (_, __) => _refreshDeclination(),
    );
    ref.listen<LocationState>(locationControllerProvider, (
      LocationState? previous,
      LocationState next,
    ) {
      if (_sensorsStarted &&
          state.isActive &&
          !state.paused &&
          state.isTravelDirection &&
          next.access.canRequestFix &&
          !(previous?.access.canRequestFix ?? false)) {
        _startLadder(); // permission granted after the compass had already started
      }
    });
    ref.listen<PerfSettings>(perfSettingsProvider, (_, PerfSettings next) {
      _throttle = HeadingThrottle(minInterval: next.arrowFrameInterval);
      if (state.isActive && !state.paused) {
        unawaited(_activate());
      }
    });
    return const CompassState();
  }

  Future<void> start() async {
    if (state.isActive && !state.paused) {
      return;
    }
    await _activate();
  }

  Future<void> _activate() async {
    final int session = ++_session;
    _releaseSensors();
    // A source from an old session must never clear a new session's anchor.
    _calibration = RelativeCalibration(now: ref.read(compassClockProvider));
    state = state.copyWith(
      status: CompassStatus.starting,
      paused: false,
      confidence: HeadingConfidence.unreliable,
      issue: HeadingIssue.none,
      clearHeading: true,
      clearSample: true,
      clearStable: true,
      clearAccuracy: true,
      clearCalibrationAnchor: true,
      clearError: true,
    );
    _refreshDeclination();
    // Location / GPS acquisition must not delay a working magnetic compass.
    unawaited(_ensureLocation());
    final double screenAngle = await ref
        .read(compassServiceProvider)
        .screenAngleDeg();
    await _sensorShutdown;
    if (_disposed || session != _session || state.paused) {
      return;
    }
    _screenAngle = screenAngle;
    final PerfSettings perf = ref.read(perfSettingsProvider);
    _throttle = HeadingThrottle(minInterval: perf.arrowFrameInterval);
    _sensorsStarted = true;
    _startLadder();
    if (!state.isTravelDirection) {
      _startAttitude();
    }
    _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _acquireWakeLock();
  }

  Future<void> _ensureLocation() async {
    try {
      await ref.read(locationControllerProvider.notifier).startTracking();
      if (!_disposed) {
        _refreshDeclination();
      }
    } catch (_) {
      // Location failures belong to the Location screen; sensor use is independent.
    }
  }

  Future<void> setMode(CompassMode mode) async {
    if (state.mode == mode) {
      return;
    }
    final bool active = state.isActive && !state.paused;
    state = state.copyWith(
      mode: mode,
      clearHeading: true,
      clearAccuracy: true,
      clearStable: true,
      clearSample: true,
      clearAttitude: true,
      clearCalibrationAnchor: true,
      confidence: HeadingConfidence.unreliable,
      issue: HeadingIssue.none,
      awaitingCalibration: false,
      waitingForWalk: false,
    );
    _calibration.resetTracking();
    if (active) {
      await _activate();
    }
  }

  void stop() {
    _session++;
    _releaseSensors();
    _releaseWakeLock();
    _calibration.resetTracking();
    ref.read(locationControllerProvider.notifier).stopTracking();
    if (!_disposed) {
      state = CompassState(
        mode: state.mode,
        declinationDeg: state.declinationDeg,
        hasLocation: ref.read(effectiveLocationProvider) != null,
      );
    }
  }

  void retry() {
    if (state.isActive && !state.paused) {
      unawaited(_activate());
    }
  }

  void onAppPaused() {
    if (!state.isActive || state.paused) {
      return;
    }
    _session++;
    _releaseSensors();
    _releaseWakeLock();
    _calibration.resetTracking();
    ref.read(locationControllerProvider.notifier).stopTracking();
    state = state.copyWith(
      paused: true,
      clearHeading: true,
      clearAccuracy: true,
      clearSample: true,
      clearStable: true,
      clearAttitude: true,
      clearCalibrationAnchor: true,
      confidence: HeadingConfidence.unreliable,
    );
  }

  void onAppResumed() {
    if (state.isActive && state.paused) {
      unawaited(_activate());
    }
  }

  bool calibrateToSun() {
    final GeoPoint? point = ref.read(effectiveLocationProvider);
    if (point == null || !point.isValid) {
      return false;
    }
    final SunPosition sun = SunCalculator.calculate(
      at: _now.toUtc(),
      latitudeDeg: point.latitude,
      longitudeDeg: point.longitude,
    );
    if (!sun.canAnchorHeading) {
      return false;
    }
    return _applyCalibration(sun.azimuthDeg, CalibrationAnchor.sun);
  }

  bool calibrateToNorth() => _applyCalibration(0, CalibrationAnchor.north);
  void clearCalibration() {
    _calibration.clear();
    _resetFilter();
    if (state.source == HeadingSourceKind.relativeCalibrated) {
      state = state.copyWith(
        awaitingCalibration: true,
        clearHeading: true,
        clearAccuracy: true,
        clearCalibrationAnchor: true,
        clearStable: true,
        confidence: HeadingConfidence.uncertain,
        issue: HeadingIssue.calibrationRequired,
      );
    }
  }

  bool _applyCalibration(double target, CalibrationAnchor anchor) {
    if (state.isTravelDirection ||
        !state.isActive ||
        state.source != HeadingSourceKind.relativeCalibrated ||
        state.paused ||
        state.isStale ||
        !_calibration.set(target, anchor)) {
      return false;
    }
    _resetFilter();
    state = state.copyWith(
      awaitingCalibration: false,
      calibrationAnchor: anchor,
    );
    _onSample(
      HeadingSample(
        headingDeg: HeadingMath.applyOffset(
          _calibration.latestRelativeDeg!,
          _calibration.offsetDeg!,
        ),
        isTrueNorth: _calibration.isTrueNorth,
        timestamp: _now,
        assessment: const HeadingAssessment(
          HeadingConfidence.uncertain,
          HeadingIssue.gyroDrift,
        ),
      ),
    );
    return true;
  }

  List<HeadingSource> buildSources() {
    if (state.isTravelDirection) {
      return <HeadingSource>[
        GpsCourseSource(
          ref.read(locationRepositoryProvider),
          now: ref.read(compassClockProvider),
        ),
      ];
    }
    final MotionSensors sensors = ref.read(motionSensorsProvider);
    final PerfSettings perf = ref.read(perfSettingsProvider);
    return <HeadingSource>[
      FusedCompassSource(
        ref.read(compassServiceProvider),
        expectedField: () => _context.field,
        modelValid: () => _context.modelValid,
      ),
      RawSensorSource(
        sensors,
        samplingPeriod: perf.sensorInterval,
        screenAngleDeg: _screenAngle,
        expectedField: () => _context.field,
        modelValid: () => _context.modelValid,
      ),
      RelativeOrientationSource(
        sensors,
        _calibration,
        samplingPeriod: perf.sensorInterval,
        screenAngleDeg: _screenAngle,
      ),
    ];
  }

  void _startLadder() {
    _releaseLadder();
    _resetFilter();
    final HeadingLadder ladder = HeadingLadder(
      sources: buildSources(),
      now: ref.read(compassClockProvider),
      recoveryInterval: ref.read(perfSettingsProvider).isLow
          ? const Duration(seconds: 60)
          : const Duration(seconds: 30),
    );
    _ladder = ladder;
    _statusSub = ladder.status.listen(_onLadderStatus);
    _sampleSub = ladder.samples.listen(_onSample);
    ladder.start();
  }

  void _onLadderStatus(LadderStatus status) {
    if (_disposed || state.paused) {
      return;
    }
    switch (status.phase) {
      case LadderPhase.idle:
        return;
      case LadderPhase.trying:
        if (state.source != status.source) {
          _resetFilter();
        }
        state = state.copyWith(
          status: CompassStatus.starting,
          source: status.source,
          ladderPhase: status.phase,
          isStale: false,
          issue: status.issue,
          confidence: HeadingConfidence.unreliable,
          clearHeading: true,
          clearAccuracy: true,
          clearStable: true,
          clearSample: true,
          awaitingCalibration: false,
          clearCalibrationAnchor: true,
          waitingForWalk: status.source == HeadingSourceKind.gpsCourse,
        );
      case LadderPhase.active:
        state = state.copyWith(
          status: CompassStatus.running,
          source: status.source,
          ladderPhase: status.phase,
          isStale: false,
          clearError: true,
        );
      case LadderPhase.degraded:
      case LadderPhase.stale:
        _resetFilter();
        state = state.copyWith(
          ladderPhase: status.phase,
          issue: status.issue,
          isStale: status.phase == LadderPhase.stale,
          clearHeading: true,
          clearAccuracy: true,
          clearStable: true,
          clearSample: true,
          confidence: HeadingConfidence.unreliable,
        );
      case LadderPhase.exhausted:
        _resetFilter();
        state = state.copyWith(
          status: CompassStatus.noSensor,
          source: HeadingSourceKind.sunOnly,
          ladderPhase: status.phase,
          issue: status.issue,
          confidence: HeadingConfidence.unreliable,
          isStale: false,
          awaitingCalibration: false,
          waitingForWalk: false,
          clearHeading: true,
          clearAccuracy: true,
          clearStable: true,
          clearSample: true,
          clearCalibrationAnchor: true,
        );
    }
  }

  void _onSample(HeadingSample sample) {
    if (_disposed || state.paused) {
      return;
    }
    if (!sample.assessment.isUsable || !sample.headingDeg.isFinite) {
      _resetFilter();
      state = state.copyWith(
        confidence: HeadingConfidence.unreliable,
        issue: sample.assessment.issue,
        clearHeading: true,
        clearAccuracy: true,
        clearStable: true,
        clearSample: true,
      );
      return;
    }
    if (sample.isProvisional) {
      _resetFilter();
      state = state.copyWith(
        status: CompassStatus.running,
        awaitingCalibration: !state.isTravelDirection,
        waitingForWalk: state.isTravelDirection,
        clearHeading: true,
        clearAccuracy: true,
        clearStable: true,
        clearSample: true,
        clearCalibrationAnchor: true,
        confidence: HeadingConfidence.uncertain,
        issue: sample.assessment.issue,
      );
      return;
    }
    if (_lastInputAt != null &&
        sample.timestamp.difference(_lastInputAt!) >
            const Duration(milliseconds: 300)) {
      _resetFilter();
    }
    if (_sampleIsTrue != sample.isTrueNorth) {
      _resetFilter();
      _sampleIsTrue = sample.isTrueNorth;
    }
    _lastInputAt = sample.timestamp;
    final double smoothed = _smoother.push(
      sample.headingDeg,
      timestamp: sample.timestamp,
    );
    _filterError = Angles.difference(sample.headingDeg, smoothed);
    final MagneticContext context = _context;
    final double? declination = context.declinationDeg;
    final double? magnetic = sample.isTrueNorth
        ? (declination == null
              ? null
              : Angles.normalize360(smoothed - declination))
        : smoothed;
    final double? trueHeading = sample.isTrueNorth
        ? smoothed
        : (declination == null
              ? null
              : HeadingMath.magneticToTrue(smoothed, declination));
    final double? accuracy = sample.accuracyDeg;
    final double? trueAccuracy = accuracy == null || trueHeading == null
        ? null
        : accuracy +
              _filterError +
              (sample.isTrueNorth
                  ? 0
                  : context.field?.declinationUncertaintyDeg ?? 0);
    if (sample.assessment.confidence == HeadingConfidence.reliable) {
      if (_stableHeading == null ||
          Angles.difference(sample.headingDeg, _stableHeading!) > 1) {
        _stableHeading = sample.headingDeg;
        _stableSince = sample.timestamp;
      }
    } else {
      _stableSince = null;
      _stableHeading = null;
    }
    final bool qualityChanged =
        state.confidence != sample.assessment.confidence ||
        state.issue != sample.assessment.issue ||
        state.accuracyDeg != accuracy ||
        state.awaitingCalibration ||
        state.waitingForWalk ||
        ((state.trueAccuracyDeg ?? double.infinity) <=
                AlignmentPolicy.toleranceDeg &&
            (state.stableSince != _stableSince ||
                (trueAccuracy ?? double.infinity) >
                    AlignmentPolicy.toleranceDeg));
    // Quality changes, even at a stationary heading, are never dropped by the
    // repaint throttle. Sensor calculations and settling run on every sample.
    if (!qualityChanged && !_throttle.shouldEmit(smoothed, now: _now)) {
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
      accuracyDeg: accuracy,
      trueAccuracyDeg: trueAccuracy,
      clearTrueAccuracy: trueAccuracy == null,
      clearAccuracy: accuracy == null,
      confidence: sample.assessment.confidence,
      issue: sample.assessment.issue,
      sampleAt: sample.timestamp,
      stableSince: _stableSince,
      clearStable: _stableSince == null,
      hasLocation: ref.read(effectiveLocationProvider) != null,
      needsCalibration:
          sample.assessment.issue == HeadingIssue.calibrationRequired &&
          (state.source == HeadingSourceKind.fusedCompass ||
              state.source == HeadingSourceKind.rawSensors),
      calibrationAnchor: _calibration.anchor,
      clearCalibrationAnchor: _calibration.anchor == null,
      awaitingCalibration: false,
      waitingForWalk: false,
      isStale: false,
      clearError: true,
    );
  }

  void _tick() {
    if (_disposed || state.paused) {
      return;
    }
    _refreshDeclination();
    if (_lastAttitudeSample != null &&
        _now.difference(_lastAttitudeSample!).abs() >
            const Duration(milliseconds: 500)) {
      state = state.copyWith(clearAttitude: true);
    }
    if (state.source == HeadingSourceKind.relativeCalibrated &&
        !_calibration.isCalibrated &&
        state.hasHeading) {
      clearCalibration();
    }
    final DateTime? at = state.sampleAt;
    if (at != null && _now.difference(at) > const Duration(seconds: 2)) {
      _resetFilter();
      state = state.copyWith(
        isStale: true,
        issue: HeadingIssue.stale,
        confidence: HeadingConfidence.unreliable,
        clearHeading: true,
        clearAccuracy: true,
        clearStable: true,
        clearSample: true,
      );
    }
  }

  void _refreshDeclination() {
    if (_disposed) {
      return;
    }
    final MagneticContext context = _context;
    final double? declination = context.declinationDeg;
    final double? smoothed = _smoother.value;
    final bool isTrue = _sampleIsTrue ?? false;
    final double? magnetic = smoothed == null
        ? state.magneticHeadingDeg
        : (isTrue
              ? (declination == null
                    ? null
                    : Angles.normalize360(smoothed - declination))
              : smoothed);
    final double? heading = smoothed == null
        ? state.trueHeadingDeg
        : (isTrue
              ? smoothed
              : (declination == null
                    ? null
                    : HeadingMath.magneticToTrue(smoothed, declination)));
    final double? accuracy = state.accuracyDeg;
    final double? trueAccuracy = accuracy == null || heading == null
        ? null
        : isTrue
        ? accuracy + _filterError
        : context.field == null
        ? null
        : accuracy + _filterError + context.field!.declinationUncertaintyDeg;
    state = state.copyWith(
      declinationDeg: declination,
      clearDeclination: declination == null,
      trueAccuracyDeg: trueAccuracy,
      clearTrueAccuracy: trueAccuracy == null,
      magneticHeadingDeg: magnetic,
      clearMagneticHeading: magnetic == null,
      trueHeadingDeg: heading,
      clearTrueHeading: heading == null,
      hasLocation: ref.read(effectiveLocationProvider) != null,
    );
  }

  void _startAttitude() {
    _lastAttitudeEmit = null;
    _lastAttitudeSample = null;
    _attitudeSub = ref
        .read(motionSensorsProvider)
        .accelerometer(
          samplingPeriod: ref.read(perfSettingsProvider).sensorInterval * 2,
        )
        .listen(
          (MotionSample sample) {
            if (_disposed) {
              return;
            }
            if (!sample.vector.isUsable ||
                _now.difference(sample.timestamp).abs() >
                    const Duration(milliseconds: 500)) {
              state = state.copyWith(clearAttitude: true);
              return;
            }
            if (_lastAttitudeSample != null &&
                !sample.timestamp.isAfter(_lastAttitudeSample!)) {
              return;
            }
            _lastAttitudeSample = sample.timestamp;
            if (_lastAttitudeEmit != null &&
                _now.difference(_lastAttitudeEmit!) <
                    const Duration(milliseconds: 120)) {
              return;
            }
            _lastAttitudeEmit = _now;
            // Rotate gravity into the UI frame, including naturally landscape tablets.
            final double angle = Angles.toRadians(_screenAngle);
            final Vector3 g = sample.vector;
            final Vector3 ui = Quaternion.rotation(
              Vector3(0, 0, angle),
            ).rotate(g);
            state = state.copyWith(attitude: Attitude.fromAccelerometer(ui));
          },
          onError: (Object _, StackTrace __) {
            if (!_disposed) {
              state = state.copyWith(clearAttitude: true);
            }
          },
          cancelOnError: true,
        );
  }

  void _resetFilter() {
    _smoother.reset();
    _throttle.reset();
    _sampleIsTrue = null;
    _filterError = 0;
    _lastInputAt = null;
    _stableSince = null;
    _stableHeading = null;
  }

  void _releaseLadder() {
    final HeadingLadder? previous = _ladder;
    previous?.dispose();
    if (previous != null) {
      _sensorShutdown = Future.wait<void>(<Future<void>>[
        _sensorShutdown,
        previous.shutdown,
      ]).then((_) {});
    }
    _ladder = null;
    _sampleSub?.cancel();
    _sampleSub = null;
    _statusSub?.cancel();
    _statusSub = null;
  }

  void _releaseSensors() {
    _sensorsStarted = false;
    _releaseLadder();
    final StreamSubscription<MotionSample>? attitude = _attitudeSub;
    if (attitude != null) {
      final Future<void> pending = attitude
          .cancel()
          .timeout(const Duration(seconds: 1))
          .catchError((Object _) {});
      _sensorShutdown = Future.wait<void>(<Future<void>>[
        _sensorShutdown,
        pending,
      ]).then((_) {});
    }
    _attitudeSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _resetFilter();
  }

  void _acquireWakeLock() {
    if (_wakeLocked) {
      return;
    }
    _wakeLocked = true;
    _wakeOperation = _wakeOperation
        .then((_) => _acquireWakeWithTimeout())
        .catchError((Object _) {});
  }

  Future<void> _acquireWakeWithTimeout() {
    final Future<void> pending = _wakeLock.acquire();
    return pending.timeout(
      const Duration(seconds: 1),
      onTimeout: () {
        // A timed-out Future does not cancel the native operation. If it acquires
        // after the queued release, compensate unless a new session wants it on.
        unawaited(
          pending
              .then((_) async {
                if (!_wakeLocked) {
                  await _wakeLock.release().timeout(const Duration(seconds: 1));
                }
              })
              .catchError((Object _) {}),
        );
        return Future<void>.value();
      },
    );
  }

  void _releaseWakeLock() {
    if (!_wakeLocked) {
      return;
    }
    _wakeLocked = false;
    _wakeOperation = _wakeOperation
        .then((_) => _wakeLock.release().timeout(const Duration(seconds: 1)))
        .catchError((Object _) {});
  }
}

final NotifierProvider<CompassController, CompassState>
compassControllerProvider = NotifierProvider<CompassController, CompassState>(
  CompassController.new,
);
