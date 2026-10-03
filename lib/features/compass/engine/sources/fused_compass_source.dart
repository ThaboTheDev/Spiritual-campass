import 'dart:async';

import '../../../../services/compass_service.dart';
import '../heading_source.dart';

/// Rung 1: the platform's fused compass heading via flutter_compass.
///
/// This is exactly what the app did before the ladder existed: magnetic
/// heading, with the platform's own tilt compensation and fusion. Android
/// delivers `null` headings on phones without a magnetometer (or before the
/// sensor has calibrated); those are dropped, so a phone that only ever sends
/// nulls simply times out and the ladder moves on to raw sensors.
class FusedCompassSource implements HeadingSource {
  FusedCompassSource(this._service);

  final CompassService _service;

  @override
  HeadingSourceKind get kind => HeadingSourceKind.fusedCompass;

  @override
  Duration? get acquireTimeout => null;

  @override
  Duration? get staleTimeout => null;

  @override
  Future<bool> isAvailable() async {
    try {
      return _service.isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<HeadingSample> start() {
    final Stream<CompassReading>? readings = _service.readings;
    if (readings == null) {
      return Stream<HeadingSample>.error(StateError('No compass on this platform'));
    }
    return readings
        .where((CompassReading reading) => reading.hasHeading)
        .map<HeadingSample>(
          (CompassReading reading) => HeadingSample(
            headingDeg: reading.headingDeg!,
            isTrueNorth: false,
            accuracyDeg: reading.accuracyDeg,
            timestamp: DateTime.now(),
          ),
        );
  }
}
