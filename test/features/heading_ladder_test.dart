import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/features/compass/engine/heading_ladder.dart';
import 'package:tshk_compass/features/compass/engine/heading_source.dart';

/// A scripted rung: optionally unavailable, optionally silent, otherwise
/// emitting one sample every 100 ms until [stopAfter] samples.
class _FakeSource implements HeadingSource {
  _FakeSource(
    this.kind, {
    this.available = true,
    this.silent = false,
    this.stopAfter,
    this.isTrue = false,
    this.provisional = false,
  });

  @override
  final HeadingSourceKind kind;
  final bool available;
  final bool silent;
  final int? stopAfter;
  final bool isTrue;
  final bool provisional;

  int starts = 0;
  int cancels = 0;
  int emitted = 0;
  Timer? _timer;
  StreamController<HeadingSample>? _controller;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Duration? get acquireTimeout => null;

  @override
  Duration? get staleTimeout => null;

  @override
  Stream<HeadingSample> start() {
    starts++;
    late final StreamController<HeadingSample> controller;
    controller = StreamController<HeadingSample>(
      onListen: () {
        if (silent || (stopAfter != null && emitted >= stopAfter!)) {
          return;
        }
        _timer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
          if (stopAfter != null && emitted >= stopAfter!) {
            t.cancel();
            return; // go quiet: the ladder must notice staleness
          }
          emitted++;
          controller.add(
            HeadingSample(
              headingDeg: 45,
              isTrueNorth: isTrue,
              timestamp: DateTime.now(),
              isProvisional: provisional,
            ),
          );
        });
      },
      onCancel: () {
        cancels++;
        _timer?.cancel();
      },
    );
    _controller = controller;
    return controller.stream;
  }

  /// Emits one sample on demand (only when [silent]).
  void emit(double heading) {
    _controller?.add(
      HeadingSample(headingDeg: heading, isTrueNorth: isTrue, timestamp: DateTime.now()),
    );
  }
}

void main() {
  const Duration acquire = Duration(seconds: 3);
  const Duration stale = Duration(seconds: 3);

  test('uses the first rung when it delivers samples', () {
    fakeAsync((FakeAsync async) {
      final _FakeSource fused = _FakeSource(HeadingSourceKind.fusedCompass);
      final _FakeSource raw = _FakeSource(HeadingSourceKind.rawSensors);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[fused, raw],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      final List<LadderStatus> statuses = <LadderStatus>[];
      final List<HeadingSample> samples = <HeadingSample>[];
      ladder.status.listen(statuses.add);
      ladder.samples.listen(samples.add);

      ladder.start();
      async.elapse(const Duration(seconds: 1));

      expect(ladder.current.phase, LadderPhase.active);
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);
      expect(samples, isNotEmpty);
      expect(raw.starts, 0);
      ladder.dispose();
    });
  });

  test('falls through a silent rung after the acquire timeout', () {
    fakeAsync((FakeAsync async) {
      final _FakeSource fused =
          _FakeSource(HeadingSourceKind.fusedCompass, silent: true);
      final _FakeSource raw = _FakeSource(HeadingSourceKind.rawSensors);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[fused, raw],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      ladder.status.listen((_) {});
      ladder.samples.listen((_) {});

      ladder.start();
      async.elapse(const Duration(milliseconds: 2900));
      expect(ladder.current.phase, LadderPhase.trying);
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);

      async.elapse(const Duration(milliseconds: 400));
      expect(fused.cancels, 1, reason: 'the silent sensor must be released');
      expect(ladder.current.phase, LadderPhase.active);
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      ladder.dispose();
    });
  });

  test('skips rungs whose sensor is absent without waiting', () {
    fakeAsync((FakeAsync async) {
      final _FakeSource fused =
          _FakeSource(HeadingSourceKind.fusedCompass, available: false);
      final _FakeSource raw =
          _FakeSource(HeadingSourceKind.rawSensors, available: false);
      final _FakeSource gps =
          _FakeSource(HeadingSourceKind.gpsCourse, isTrue: true);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[fused, raw, gps],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      final List<HeadingSample> samples = <HeadingSample>[];
      ladder.status.listen((_) {});
      ladder.samples.listen(samples.add);

      ladder.start();
      async.elapse(const Duration(milliseconds: 300));
      expect(fused.starts, 0);
      expect(raw.starts, 0);
      expect(ladder.current.source, HeadingSourceKind.gpsCourse);
      expect(samples.first.isTrueNorth, isTrue);
      ladder.dispose();
    });
  });

  test('reports exhausted when every rung fails', () {
    fakeAsync((FakeAsync async) {
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[
          _FakeSource(HeadingSourceKind.fusedCompass, silent: true),
          _FakeSource(HeadingSourceKind.rawSensors, available: false),
          _FakeSource(HeadingSourceKind.relativeCalibrated, silent: true),
        ],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      ladder.status.listen((_) {});
      ladder.samples.listen((_) {});

      ladder.start();
      async.elapse(const Duration(seconds: 7));
      expect(ladder.current.phase, LadderPhase.exhausted);
      expect(ladder.current.source, isNull);
      ladder.dispose();
    });
  });

  test('a rung that goes quiet is flagged stale, restarted, then abandoned',
      () {
    fakeAsync((FakeAsync async) {
      final _FakeSource fused =
          _FakeSource(HeadingSourceKind.fusedCompass, stopAfter: 3);
      final _FakeSource raw = _FakeSource(HeadingSourceKind.rawSensors);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[fused, raw],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      final List<LadderPhase> phases = <LadderPhase>[];
      ladder.status.listen((LadderStatus s) => phases.add(s.phase));
      ladder.samples.listen((_) {});

      ladder.start();
      // 3 samples in 300 ms, then silence: stale after 3 s more.
      async.elapse(const Duration(milliseconds: 3400));
      expect(phases, contains(LadderPhase.stale));
      expect(fused.starts, 2, reason: 'restarted once after going stale');
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);

      // Still silent after the restart: down the ladder.
      async.elapse(const Duration(milliseconds: 3200));
      expect(ladder.current.phase, LadderPhase.active);
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      ladder.dispose();
    });
  });

  test('provisional samples (uncalibrated turn sensor) keep the rung', () {
    fakeAsync((FakeAsync async) {
      final _FakeSource relative = _FakeSource(
        HeadingSourceKind.relativeCalibrated,
        provisional: true,
      );
      final _FakeSource gps = _FakeSource(HeadingSourceKind.gpsCourse);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[relative, gps],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      final List<HeadingSample> samples = <HeadingSample>[];
      ladder.status.listen((_) {});
      ladder.samples.listen(samples.add);

      ladder.start();
      async.elapse(const Duration(seconds: 10));
      expect(ladder.current.source, HeadingSourceKind.relativeCalibrated);
      expect(ladder.current.phase, LadderPhase.active);
      expect(samples.every((HeadingSample s) => s.isProvisional), isTrue);
      expect(gps.starts, 0);
      ladder.dispose();
    });
  });

  test('restart goes back to the top of the ladder', () {
    fakeAsync((FakeAsync async) {
      final _FakeSource fused =
          _FakeSource(HeadingSourceKind.fusedCompass, silent: true);
      final _FakeSource raw = _FakeSource(HeadingSourceKind.rawSensors);
      final HeadingLadder ladder = HeadingLadder(
        sources: <HeadingSource>[fused, raw],
        acquireTimeout: acquire,
        staleTimeout: stale,
      );
      ladder.status.listen((_) {});
      ladder.samples.listen((_) {});

      ladder.start();
      async.elapse(const Duration(seconds: 4));
      expect(ladder.current.source, HeadingSourceKind.rawSensors);

      ladder.restart();
      async.elapse(const Duration(milliseconds: 10));
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);
      expect(fused.starts, 2);
      // The fused sensor wakes up this time.
      fused.emit(120);
      async.elapse(const Duration(milliseconds: 10));
      expect(ladder.current.phase, LadderPhase.active);
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);
      ladder.dispose();
    });
  });
}
