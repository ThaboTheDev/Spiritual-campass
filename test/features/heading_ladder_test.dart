import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';
import 'package:tshk_compass/features/compass/engine/heading_ladder.dart';
import 'package:tshk_compass/features/compass/engine/heading_source.dart';

class ScriptSource implements HeadingSource {
  ScriptSource(
    this.kind,
    this.now, {
    this.silent = false,
    this.available = true,
    this.stopAfter,
    this.provisional = false,
  });
  @override
  final HeadingSourceKind kind;
  final DateTime Function() now;
  final bool silent;
  final bool available;
  final int? stopAfter;
  final bool provisional;
  Future<bool>? availability;
  HeadingAssessment assessment = HeadingAssessment.reliable;
  Future<void>? cancellation;
  int starts = 0;
  int cancels = 0;
  int emitted = 0;
  StreamController<HeadingSample>? controller;
  @override
  Future<bool> isAvailable() => availability ?? Future<bool>.value(available);
  @override
  Duration? get acquireTimeout => null;
  @override
  Duration? get staleTimeout => null;
  @override
  Stream<HeadingSample> start() {
    starts++;
    Timer? timer;
    late final StreamController<HeadingSample> c;
    c = StreamController<HeadingSample>(
      onListen: () {
        if (!silent) {
          timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
            if (stopAfter != null && emitted >= stopAfter!) {
              return;
            }
            emitted++;
            c.add(sample(45));
          });
        }
      },
      onCancel: () {
        cancels++;
        timer?.cancel();
        return cancellation;
      },
    );
    controller = c;
    return c.stream;
  }

  HeadingSample sample(double heading, {DateTime? at}) => HeadingSample(
    headingDeg: heading,
    isTrueNorth: false,
    timestamp: at ?? now(),
    isProvisional: provisional,
    assessment: assessment,
  );
  void emit(double heading, {DateTime? at}) =>
      controller!.add(sample(heading, at: at));
}

void main() {
  final DateTime origin = DateTime.utc(2026, 1, 1);
  test('uses a live healthy preferred sensor', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
      );
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
      );
      ladder.start();
      a.elapse(const Duration(seconds: 1));
      expect(ladder.current.phase, LadderPhase.active);
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);
      expect(raw.starts, 0);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test(
    'absent, silent and hung-availability sensors have bounded acquisition',
    () {
      fakeAsync((FakeAsync a) {
        final DateTime Function() now = a.getClock(origin).now;
        final ScriptSource absent = ScriptSource(
          HeadingSourceKind.fusedCompass,
          now,
          available: false,
        );
        final ScriptSource hung = ScriptSource(
          HeadingSourceKind.rawSensors,
          now,
        )..availability = Completer<bool>().future;
        final ScriptSource silent = ScriptSource(
          HeadingSourceKind.relativeCalibrated,
          now,
          silent: true,
        );
        final HeadingLadder ladder = HeadingLadder(
          sources: [absent, hung, silent],
          now: now,
        );
        ladder.start();
        a.elapse(const Duration(seconds: 7));
        expect(absent.starts, 0);
        expect(hung.starts, 0);
        expect(silent.starts, 1);
        expect(ladder.current.phase, LadderPhase.exhausted);
        ladder.dispose();
        a.flushMicrotasks();
      });
    },
  );
  test('bad quality is immediately visible and sustained failure demotes', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
      );
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
      );
      final List<HeadingSample> readings = [];
      ladder.samples.listen(readings.add);
      ladder.start();
      a.elapse(const Duration(milliseconds: 150));
      fused.assessment = const HeadingAssessment(
        HeadingConfidence.unreliable,
        HeadingIssue.magneticInterference,
      );
      a.elapse(const Duration(milliseconds: 100));
      expect(ladder.current.phase, LadderPhase.degraded);
      expect(readings.last.assessment.isUsable, isFalse);
      a.elapse(const Duration(milliseconds: 2200));
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      expect(fused.cancels, 1);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test(
    'a brief glitch requires sustained recovery without source flapping',
    () {
      fakeAsync((FakeAsync a) {
        final DateTime Function() now = a.getClock(origin).now;
        final ScriptSource fused = ScriptSource(
          HeadingSourceKind.fusedCompass,
          now,
          silent: true,
        );
        final ScriptSource raw = ScriptSource(
          HeadingSourceKind.rawSensors,
          now,
        );
        final HeadingLadder ladder = HeadingLadder(
          sources: [fused, raw],
          now: now,
        );
        ladder.start();
        a.flushMicrotasks();
        fused.emit(0);
        a.flushMicrotasks();
        a.elapse(const Duration(milliseconds: 50));
        fused.assessment = const HeadingAssessment(
          HeadingConfidence.unreliable,
          HeadingIssue.calibrationRequired,
        );
        fused.emit(0);
        a.flushMicrotasks();
        fused.assessment = HeadingAssessment.reliable;
        for (int i = 0; i < 12; i++) {
          a.elapse(const Duration(milliseconds: 100));
          fused.emit(0);
          a.flushMicrotasks();
        }
        expect(ladder.current.phase, LadderPhase.active);
        expect(raw.starts, 0);
        ladder.dispose();
        a.flushMicrotasks();
      });
    },
  );
  test('silence restarts once, then falls through', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
        stopAfter: 2,
      );
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
      );
      final List<LadderPhase> phases = [];
      ladder.status.listen((LadderStatus s) => phases.add(s.phase));
      ladder.start();
      a.elapse(const Duration(seconds: 6));
      expect(phases, contains(LadderPhase.stale));
      expect(fused.starts, 2);
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test('duplicate timestamps do not keep an old direction alive', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
        silent: true,
      );
      final HeadingLadder ladder = HeadingLadder(sources: [fused], now: now);
      ladder.start();
      a.flushMicrotasks();
      fused.emit(0);
      a.flushMicrotasks();
      a.elapse(const Duration(seconds: 1));
      fused.emit(90, at: origin);
      a.flushMicrotasks();
      a.elapse(const Duration(milliseconds: 1100));
      expect(ladder.current.phase, LadderPhase.stale);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test('old, future and non-finite samples cannot acquire a sensor', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource source = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
        silent: true,
      );
      final HeadingLadder ladder = HeadingLadder(sources: [source], now: now);
      ladder.start();
      a.flushMicrotasks();
      source.emit(0, at: origin.subtract(const Duration(minutes: 1)));
      a.flushMicrotasks();
      source.emit(0, at: origin.add(const Duration(minutes: 1)));
      a.flushMicrotasks();
      source.emit(double.nan);
      a.flushMicrotasks();
      expect(ladder.current.phase, isNot(LadderPhase.active));
      a.elapse(const Duration(seconds: 3));
      expect(ladder.current.phase, LadderPhase.exhausted);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test(
    'uncalibrated relative source remains available for explicit user anchoring',
    () {
      fakeAsync((FakeAsync a) {
        final DateTime Function() now = a.getClock(origin).now;
        final ScriptSource relative = ScriptSource(
          HeadingSourceKind.relativeCalibrated,
          now,
          provisional: true,
        );
        final HeadingLadder ladder = HeadingLadder(
          sources: [relative],
          now: now,
        );
        ladder.start();
        a.elapse(const Duration(seconds: 10));
        expect(ladder.current.phase, LadderPhase.active);
        expect(ladder.current.source, HeadingSourceKind.relativeCalibrated);
        ladder.dispose();
        a.flushMicrotasks();
      });
    },
  );
  test('native fusion is restored by a bounded healthy background probe', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused =
          ScriptSource(HeadingSourceKind.fusedCompass, now)
            ..assessment = const HeadingAssessment(
              HeadingConfidence.unreliable,
              HeadingIssue.magneticInterference,
            );
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
        recoveryInterval: const Duration(seconds: 2),
      );
      ladder.start();
      a.elapse(const Duration(milliseconds: 2500));
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      fused.assessment = HeadingAssessment.reliable;
      a.elapse(const Duration(seconds: 4));
      expect(ladder.current.source, HeadingSourceKind.fusedCompass);
      expect(fused.starts, greaterThanOrEqualTo(3));
      expect(raw.cancels, 1);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test('late availability after stop cannot resurrect sensors', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final Completer<bool> availability = Completer<bool>();
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
      )..availability = availability.future;
      final HeadingLadder ladder = HeadingLadder(sources: [fused], now: now);
      ladder.start();
      a.flushMicrotasks();
      ladder.stop();
      availability.complete(true);
      a.flushMicrotasks();
      expect(fused.starts, 0);
      expect(ladder.current.phase, LadderPhase.idle);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test('repeated timestamps cannot satisfy preferred-source recovery', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
        silent: true,
      );
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
        recoveryInterval: const Duration(seconds: 2),
      );
      ladder.start();
      a.elapse(const Duration(milliseconds: 5300));
      expect(fused.starts, 2);
      final DateTime at = now();
      fused.emit(45, at: at);
      a.flushMicrotasks();
      a.elapse(const Duration(seconds: 1));
      fused.emit(45, at: at);
      a.flushMicrotasks();
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      for (int i = 0; i < 12; i++) {
        a.elapse(const Duration(milliseconds: 100));
        fused.emit(45);
        a.flushMicrotasks();
      }
      expect(fused.starts, 3);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
  test('hung cancellation cannot block every lower rung', () {
    fakeAsync((FakeAsync a) {
      final DateTime Function() now = a.getClock(origin).now;
      final ScriptSource fused = ScriptSource(
        HeadingSourceKind.fusedCompass,
        now,
        silent: true,
      )..cancellation = Completer<void>().future;
      final ScriptSource raw = ScriptSource(HeadingSourceKind.rawSensors, now);
      final HeadingLadder ladder = HeadingLadder(
        sources: [fused, raw],
        now: now,
      );
      ladder.start();
      a.elapse(const Duration(milliseconds: 4300));
      expect(ladder.current.source, HeadingSourceKind.rawSensors);
      expect(ladder.current.phase, LadderPhase.active);
      ladder.dispose();
      a.flushMicrotasks();
    });
  });
}
