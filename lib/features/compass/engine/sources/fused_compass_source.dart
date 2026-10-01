import 'dart:async';

import '../../../../core/geo/heading_quality.dart';
import '../../../../core/wmm/wmm.dart';
import '../../../../services/compass_service.dart';
import '../heading_source.dart';

/// Prefer OS fusion. Keep the measured timestamp, north reference, real
/// accuracy and calibration status; do not relabel vendor HIGH as ±15°.
class FusedCompassSource implements HeadingSource {
  FusedCompassSource(this._service, {this.expectedField, this.modelValid});

  final CompassService _service;
  final MagneticField? Function()? expectedField;
  final bool Function()? modelValid;

  @override
  HeadingSourceKind get kind => HeadingSourceKind.fusedCompass;
  @override
  Duration? get acquireTimeout => null;
  @override
  Duration? get staleTimeout => null;

  @override
  Future<bool> isAvailable() async {
    try {
      return _service.isSupported &&
          (await _service.capabilities()).absoluteOrientation;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<HeadingSample> start() {
    final Stream<CompassReading>? readings = _service.readings;
    if (readings == null) {
      return Stream<HeadingSample>.error(StateError('No native compass'));
    }
    final MagneticQualityMonitor monitor = MagneticQualityMonitor();
    return readings.map((CompassReading reading) {
      final double? heading = reading.facingHeadingDeg;
      final HeadingAssessment assessment;
      if (reading.reference == NorthReference.relative) {
        assessment = const HeadingAssessment(
          HeadingConfidence.unreliable,
          HeadingIssue.calibrationRequired,
        );
      } else {
        assessment = monitor.assess(
          timestamp: reading.timestamp,
          headingDeg: heading,
          accuracyDeg: reading.accuracyDeg,
          reliability: reading.reliability,
          magneticMicrotesla: reading.magneticMicrotesla,
          gravity: reading.gravity,
          linearAcceleration: reading.linearAcceleration,
          gyroscope: reading.gyroscope,
          expectedField: expectedField?.call(),
          modelValid:
              reading.reference == NorthReference.trueNorth ||
              (modelValid?.call() ?? true),
        );
      }
      return HeadingSample(
        headingDeg: heading ?? double.nan,
        isTrueNorth: reading.reference == NorthReference.trueNorth,
        accuracyDeg: reading.accuracyDeg == 0 ? null : reading.accuracyDeg,
        timestamp: reading.timestamp,
        assessment: assessment,
      );
    });
  }
}
