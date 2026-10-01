import 'dart:async';

import '../../../core/geo/heading_quality.dart';
import 'heading_source.dart';

enum LadderPhase { idle, trying, active, degraded, stale, exhausted }

class LadderStatus {
  const LadderStatus(this.phase, this.source, {this.issue = HeadingIssue.none});
  final LadderPhase phase;
  final HeadingSourceKind? source;
  final HeadingIssue issue;
  bool get isActive => phase == LadderPhase.active;

  @override
  bool operator ==(Object other) =>
      other is LadderStatus &&
      other.phase == phase &&
      other.source == source &&
      other.issue == issue;
  @override
  int get hashCode => Object.hash(phase, source, issue);
  @override
  String toString() => 'LadderStatus($phase, $source, $issue)';
}

/// Best-first failover with timestamp validation and quality hysteresis.
/// Bad readings immediately clear the displayed direction; sustained failure
/// demotes the source. Recovery must remain healthy for a full second.
/// A bounded background probe can restore native fusion without interrupting
/// an active fallback. GPS is intentionally selected as a separate UI mode.
class HeadingLadder {
  HeadingLadder({
    required this.sources,
    this.acquireTimeout = const Duration(seconds: 3),
    this.staleTimeout = const Duration(seconds: 2),
    this.qualityTimeout = const Duration(seconds: 2),
    this.recoveryHold = const Duration(seconds: 1),
    this.recoveryInterval = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final List<HeadingSource> sources;
  final Duration acquireTimeout;
  final Duration staleTimeout;
  final Duration qualityTimeout;
  final Duration recoveryHold;
  final Duration recoveryInterval;
  final DateTime Function() _now;

  final StreamController<HeadingSample> _samples =
      StreamController<HeadingSample>.broadcast();
  final StreamController<LadderStatus> _status =
      StreamController<LadderStatus>.broadcast();
  LadderStatus _current = const LadderStatus(LadderPhase.idle, null);
  int _index = -1;
  int _generation = 0;
  bool _acquired = false;
  bool _disposed = false;
  bool _restartingAfterStale = false;
  DateTime? _lastSampleAt;
  DateTime? _healthySince;
  StreamSubscription<HeadingSample>? _subscription;
  StreamSubscription<HeadingSample>? _probeSub;
  Future<void> _cancellation = Future<void>.value();
  Timer? _acquireTimer;
  Timer? _staleTimer;
  Timer? _qualityTimer;
  Timer? _recoveryTimer;
  Timer? _probeTimer;

  Stream<HeadingSample> get samples => _samples.stream;
  Stream<LadderStatus> get status => _status.stream;
  LadderStatus get current => _current;
  bool get isRunning => _current.phase != LadderPhase.idle;
  bool get isRestartingAfterStale => _restartingAfterStale;

  /// Resource cancellation is bounded; callers await this before opening a
  /// new engine against the same platform channels.
  Future<void> get shutdown => _cancellation;

  void start() {
    if (_disposed) {
      return;
    }
    _index = -1;
    _tryNext();
  }

  void restart() => start();
  void stop() {
    _teardown();
    _index = -1;
    _emitStatus(const LadderStatus(LadderPhase.idle, null));
  }

  void dispose() {
    stop();
    _disposed = true;
    _samples.close();
    _status.close();
  }

  void _tryNext() {
    final HeadingIssue lastIssue = _current.issue;
    _teardown();
    _index++;
    if (_index >= sources.length) {
      _emitStatus(LadderStatus(LadderPhase.exhausted, null, issue: lastIssue));
      return;
    }
    _openCurrent(afterStale: false);
  }

  void _openCurrent({required bool afterStale}) {
    final HeadingSource source = sources[_index];
    final int generation = ++_generation;
    _acquired = false;
    _lastSampleAt = null;
    _healthySince = null;
    _restartingAfterStale = afterStale;
    if (!afterStale) {
      _emitStatus(LadderStatus(LadderPhase.trying, source.kind));
    }
    // The deadline includes cancellation and availability. A hung capability
    // query must not block every lower rung forever.
    _acquireTimer?.cancel();
    _acquireTimer = Timer(source.acquireTimeout ?? acquireTimeout, () {
      if (generation == _generation && !_acquired && !_disposed) {
        _tryNext();
      }
    });
    _connect(source, generation);
  }

  Future<void> _connect(HeadingSource source, int generation) async {
    try {
      await _cancellation;
      if (!_isCurrent(generation)) {
        return;
      }
      final bool available = await source.isAvailable().timeout(
        source.acquireTimeout ?? acquireTimeout,
      );
      if (!_isCurrent(generation)) {
        return;
      }
      if (!available) {
        _tryNext();
        return;
      }
      _subscription = source.start().listen(
        (HeadingSample sample) => _onSample(sample, source, generation),
        onError: (Object _, StackTrace __) {
          if (_isCurrent(generation)) {
            _tryNext();
          }
        },
        onDone: () {
          if (_isCurrent(generation)) {
            _tryNext();
          }
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        _tryNext();
      }
    }
  }

  bool _isCurrent(int generation) => generation == _generation && !_disposed;

  bool _fresh(HeadingSample sample) {
    final Duration age = _now().difference(sample.timestamp);
    return age <= const Duration(seconds: 2) &&
        age >= const Duration(milliseconds: -250);
  }

  void _onSample(HeadingSample sample, HeadingSource source, int generation) {
    if (!_isCurrent(generation)) {
      return;
    }
    if (!_fresh(sample)) {
      _reject(sample, source, generation, HeadingIssue.stale);
      return;
    }
    if (_lastSampleAt != null && !sample.timestamp.isAfter(_lastSampleAt!)) {
      return; // repeating an old value is not proof of a live sensor
    }
    _lastSampleAt = sample.timestamp;
    final bool usable =
        sample.headingDeg.isFinite && sample.assessment.isUsable;
    if (!usable) {
      _reject(sample, source, generation, sample.assessment.issue);
      return;
    }
    if (_current.phase == LadderPhase.degraded) {
      _healthySince ??= _now();
      if (_now().difference(_healthySince!) < recoveryHold) {
        return;
      }
    }
    _qualityTimer?.cancel();
    _qualityTimer = null;
    _healthySince = null;
    _acquired = true;
    _acquireTimer?.cancel();
    _acquireTimer = null;
    _restartingAfterStale = false;
    _emitStatus(LadderStatus(LadderPhase.active, source.kind));
    _samples.add(sample);
    _armStale(source, generation);
    _scheduleRecovery(generation);
  }

  void _reject(
    HeadingSample sample,
    HeadingSource source,
    int generation,
    HeadingIssue issue,
  ) {
    _healthySince = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    final HeadingIssue reason = issue == HeadingIssue.none
        ? HeadingIssue.calibrationRequired
        : issue;
    _emitStatus(
      LadderStatus(
        _acquired ? LadderPhase.degraded : LadderPhase.trying,
        source.kind,
        issue: reason,
      ),
    );
    _samples.add(
      HeadingSample(
        headingDeg: sample.headingDeg,
        isTrueNorth: sample.isTrueNorth,
        timestamp: sample.timestamp,
        isProvisional: sample.isProvisional,
        assessment: HeadingAssessment(HeadingConfidence.unreliable, reason),
      ),
    );
    _qualityTimer ??= Timer(qualityTimeout, () {
      if (_isCurrent(generation)) {
        _tryNext();
      }
    });
  }

  void _armStale(HeadingSource source, int generation) {
    _staleTimer?.cancel();
    _staleTimer = Timer(source.staleTimeout ?? staleTimeout, () {
      if (!_isCurrent(generation)) {
        return;
      }
      _teardown();
      _emitStatus(
        LadderStatus(LadderPhase.stale, source.kind, issue: HeadingIssue.stale),
      );
      _openCurrent(afterStale: true);
    });
  }

  void _scheduleRecovery(int generation) {
    if (_index <= 0 ||
        _recoveryTimer != null ||
        _probeTimer != null ||
        sources.first.kind != HeadingSourceKind.fusedCompass) {
      return;
    }
    _recoveryTimer = Timer(recoveryInterval, () {
      _recoveryTimer = null;
      if (_isCurrent(generation)) {
        _probePreferred(generation);
      }
    });
  }

  Future<void> _probePreferred(int generation) async {
    DateTime? healthySince;
    DateTime? lastProbeAt;
    try {
      if (!await sources.first.isAvailable().timeout(acquireTimeout) ||
          !_isCurrent(generation)) {
        if (_isCurrent(generation)) {
          _scheduleRecovery(generation);
        }
        return;
      }
      _probeTimer = Timer(acquireTimeout + recoveryHold, () {
        _cancelProbe();
        if (_isCurrent(generation)) {
          _scheduleRecovery(generation);
        }
      });
      _probeSub = sources.first.start().listen(
        (HeadingSample sample) {
          if (!_isCurrent(generation)) {
            return;
          }
          if (lastProbeAt != null && !sample.timestamp.isAfter(lastProbeAt!)) {
            return;
          }
          if (lastProbeAt != null &&
              sample.timestamp.difference(lastProbeAt!) >
                  const Duration(milliseconds: 500)) {
            healthySince = null;
          }
          if (!_fresh(sample) ||
              !sample.headingDeg.isFinite ||
              !sample.assessment.isUsable ||
              sample.isProvisional ||
              (sample.assessment.issue != HeadingIssue.none &&
                  sample.assessment.issue != HeadingIssue.accuracyUnknown)) {
            healthySince = null;
            return;
          }
          lastProbeAt = sample.timestamp;
          healthySince ??= _now();
          if (_now().difference(healthySince!) >= recoveryHold) {
            restart();
          }
        },
        onError: (Object _, StackTrace __) {
          _cancelProbe();
          if (_isCurrent(generation)) {
            _scheduleRecovery(generation);
          }
        },
        onDone: () {
          _cancelProbe();
          if (_isCurrent(generation)) {
            _scheduleRecovery(generation);
          }
        },
        cancelOnError: true,
      );
    } catch (_) {
      _cancelProbe();
      if (_isCurrent(generation)) {
        _scheduleRecovery(generation);
      }
    }
  }

  void _queueCancel(StreamSubscription<HeadingSample>? subscription) {
    if (subscription != null) {
      // Issue every cancellation immediately. One stuck sensor must not keep
      // another sensor running or prevent the next lifecycle session.
      final Future<void> pending = subscription
          .cancel()
          .timeout(const Duration(seconds: 1))
          .catchError((Object _) {});
      _cancellation = Future.wait<void>(<Future<void>>[
        _cancellation,
        pending,
      ]).then((_) {});
    }
  }

  void _cancelProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _queueCancel(_probeSub);
    _probeSub = null;
  }

  void _teardown() {
    _generation++;
    _acquireTimer?.cancel();
    _acquireTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _qualityTimer?.cancel();
    _qualityTimer = null;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _cancelProbe();
    _queueCancel(_subscription);
    _subscription = null;
    _acquired = false;
    _lastSampleAt = null;
    _healthySince = null;
    _restartingAfterStale = false;
  }

  void _emitStatus(LadderStatus status) {
    if (_disposed || status == _current) {
      return;
    }
    _current = status;
    _status.add(status);
  }
}
