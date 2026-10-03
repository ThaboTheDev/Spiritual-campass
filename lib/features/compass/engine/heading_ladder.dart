import 'dart:async';

import 'heading_source.dart';

/// What the ladder is doing right now.
enum LadderPhase {
  /// Not started / stopped.
  idle,

  /// Waiting for the first sample of [LadderStatus.source].
  trying,

  /// Receiving samples from [LadderStatus.source].
  active,

  /// [LadderStatus.source] was active but has gone quiet; it is being
  /// restarted ("Move the phone to wake the compass").
  stale,

  /// Every rung failed: sun-only guidance.
  exhausted,
}

/// A snapshot of the ladder's state for the UI.
class LadderStatus {
  const LadderStatus(this.phase, this.source);

  /// The phase.
  final LadderPhase phase;

  /// The rung in play, or `null` when idle / exhausted.
  final HeadingSourceKind? source;

  /// Whether a rung is delivering samples (including provisional ones).
  bool get isActive => phase == LadderPhase.active;

  @override
  bool operator ==(Object other) =>
      other is LadderStatus && other.phase == phase && other.source == source;

  @override
  int get hashCode => Object.hash(phase, source);

  @override
  String toString() => 'LadderStatus($phase, $source)';
}

/// Tries heading sources best-first and falls through when one is silent.
///
/// Rules (from the web edition, generalised to N rungs):
///
/// * a rung is *acquired* on its first valid sample; until then a timer of
///   [acquireTimeout] runs and, on expiry, the next rung is tried;
/// * a rung whose [HeadingSource.isAvailable] is `false`, or whose stream
///   errors before delivering anything, is skipped immediately;
/// * an acquired rung that stays silent for [staleTimeout] is reported
///   [LadderPhase.stale] and restarted; if the restart produces nothing within
///   [acquireTimeout] the ladder moves on to the next rung;
/// * when the last rung fails the ladder is [LadderPhase.exhausted] and stays
///   there until [restart] is called (app resume, "Retry").
///
/// Pure Dart: only `Timer`s, no platform code, so it runs under `fake_async`.
class HeadingLadder {
  HeadingLadder({
    required this.sources,
    this.acquireTimeout = const Duration(seconds: 3),
    this.staleTimeout = const Duration(seconds: 3),
  });

  /// Rungs, best first.
  final List<HeadingSource> sources;

  /// How long a rung may stay silent before it is skipped.
  final Duration acquireTimeout;

  /// How long an acquired rung may stay silent before it is restarted.
  final Duration staleTimeout;

  final StreamController<HeadingSample> _samples =
      StreamController<HeadingSample>.broadcast();
  final StreamController<LadderStatus> _status =
      StreamController<LadderStatus>.broadcast();

  LadderStatus _current = const LadderStatus(LadderPhase.idle, null);
  int _index = -1;
  int _generation = 0;
  bool _acquired = false;
  bool _restartingAfterStale = false;
  StreamSubscription<HeadingSample>? _subscription;
  Timer? _acquireTimer;
  Timer? _staleTimer;
  bool _disposed = false;

  /// Valid samples from whichever rung is active.
  Stream<HeadingSample> get samples => _samples.stream;

  /// Phase / source changes.
  Stream<LadderStatus> get status => _status.stream;

  /// The latest status.
  LadderStatus get current => _current;

  /// Whether [start] has been called and [stop] has not.
  bool get isRunning => _current.phase != LadderPhase.idle;

  /// Starts from the best rung. Calling it while running restarts.
  void start() {
    if (_disposed) {
      return;
    }
    _teardownRung();
    _index = -1;
    _tryNext();
  }

  /// Alias of [start]: go back to the top of the ladder.
  void restart() => start();

  /// Stops every sensor and goes idle.
  void stop() {
    _teardownRung();
    _index = -1;
    _emitStatus(const LadderStatus(LadderPhase.idle, null));
  }

  /// Stops and closes the streams.
  void dispose() {
    stop();
    _disposed = true;
    _samples.close();
    _status.close();
  }

  // ---------------------------------------------------------------- internals

  void _tryNext() {
    _teardownRung();
    _index++;
    if (_index >= sources.length) {
      _emitStatus(const LadderStatus(LadderPhase.exhausted, null));
      return;
    }
    _openCurrent(afterStale: false);
  }

  void _openCurrent({required bool afterStale}) {
    final HeadingSource source = sources[_index];
    final int generation = ++_generation;
    _acquired = false;
    _restartingAfterStale = afterStale;
    if (!afterStale) {
      _emitStatus(LadderStatus(LadderPhase.trying, source.kind));
    }

    Future<bool> availability;
    try {
      availability = source.isAvailable();
    } catch (_) {
      availability = Future<bool>.value(false);
    }

    availability.then((bool available) {
      if (generation != _generation || _disposed) {
        return; // stopped or moved on while we were waiting
      }
      if (!available) {
        _tryNext();
        return;
      }
      _listen(source, generation);
    }).catchError((Object _) {
      if (generation == _generation && !_disposed) {
        _tryNext();
      }
    });
  }

  void _listen(HeadingSource source, int generation) {
    Stream<HeadingSample> stream;
    try {
      stream = source.start();
    } catch (_) {
      _tryNext();
      return;
    }
    _subscription = stream.listen(
      (HeadingSample sample) => _onSample(sample, source, generation),
      onError: (Object error, StackTrace stack) {
        if (generation != _generation) {
          return;
        }
        // A stream error before / after acquisition both mean "this sensor is
        // not going to work now"; move on rather than spin.
        _tryNext();
      },
      onDone: () {
        if (generation != _generation) {
          return;
        }
        _tryNext();
      },
      cancelOnError: true,
    );
    _acquireTimer?.cancel();
    _acquireTimer = Timer(source.acquireTimeout ?? acquireTimeout, () {
      if (generation != _generation) {
        return;
      }
      if (!_acquired) {
        _tryNext();
      }
    });
  }

  void _onSample(HeadingSample sample, HeadingSource source, int generation) {
    if (generation != _generation || _disposed) {
      return;
    }
    if (!sample.headingDeg.isFinite) {
      return; // not a valid sample: does not count towards acquisition
    }
    if (!_acquired) {
      _acquired = true;
      _acquireTimer?.cancel();
      _acquireTimer = null;
      _restartingAfterStale = false;
      _emitStatus(LadderStatus(LadderPhase.active, source.kind));
    } else if (_current.phase != LadderPhase.active) {
      _emitStatus(LadderStatus(LadderPhase.active, source.kind));
    }
    _armStaleTimer(source, generation);
    _samples.add(sample);
  }

  void _armStaleTimer(HeadingSource source, int generation) {
    _staleTimer?.cancel();
    _staleTimer = Timer(source.staleTimeout ?? staleTimeout, () {
      if (generation != _generation || _disposed) {
        return;
      }
      _emitStatus(LadderStatus(LadderPhase.stale, source.kind));
      // Restart the same rung once; if that also stays silent for
      // [acquireTimeout] the acquire timer moves us down the ladder.
      _subscription?.cancel();
      _subscription = null;
      _openCurrent(afterStale: true);
    });
  }

  void _teardownRung() {
    _generation++;
    _acquireTimer?.cancel();
    _acquireTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _acquired = false;
    _restartingAfterStale = false;
  }

  void _emitStatus(LadderStatus status) {
    if (_disposed) {
      return;
    }
    _current = status;
    _status.add(status);
  }

  /// Whether the current rung is being re-opened after going stale.
  bool get isRestartingAfterStale => _restartingAfterStale;
}
