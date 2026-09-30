import 'dart:async';

import '../../../core/l10n/strings.dart';

/// Which rung of the failover ladder a heading came from.
enum HeadingSourceKind {
  /// Platform-fused compass (flutter_compass). Magnetic.
  fusedCompass,

  /// Magnetometer + accelerometer, tilt compensated in Dart. Magnetic.
  rawSensors,

  /// Gyroscope turn tracking plus a one-tap "Set" calibration. Magnetic when
  /// calibrated to north, true when calibrated to the sun.
  relativeCalibrated,

  /// GPS course over ground while walking. Already true north.
  gpsCourse,

  /// Nothing usable: sun guidance and hand-compass bearings only.
  sunOnly,
}

extension HeadingSourceKindX on HeadingSourceKind {
  /// Localised name for the status chip.
  Bi get label => switch (this) {
        HeadingSourceKind.fusedCompass => S.srcFused,
        HeadingSourceKind.rawSensors => S.srcRaw,
        HeadingSourceKind.relativeCalibrated => S.srcRelative,
        HeadingSourceKind.gpsCourse => S.srcGps,
        HeadingSourceKind.sunOnly => S.srcSun,
      };
}

/// One heading sample from a [HeadingSource].
class HeadingSample {
  const HeadingSample({
    required this.headingDeg,
    required this.isTrueNorth,
    required this.timestamp,
    this.accuracyDeg,
    this.isProvisional = false,
  });

  /// Heading in degrees, 0 .. 360, clockwise. Magnetic unless [isTrueNorth].
  final double headingDeg;

  /// `true` when the heading is already referenced to true north (GPS course,
  /// sun calibration) and must *not* have declination added.
  final bool isTrueNorth;

  /// When the underlying sensor sample was taken.
  final DateTime timestamp;

  /// Estimated error in degrees (±), when known.
  final double? accuracyDeg;

  /// A sample that keeps the source alive but is not yet an absolute heading
  /// — the uncalibrated relative source. The UI shows the "Set" controls
  /// instead of moving the dial.
  final bool isProvisional;

  @override
  String toString() =>
      'HeadingSample(${headingDeg.toStringAsFixed(1)}°, true: $isTrueNorth, '
      'provisional: $isProvisional, ±$accuracyDeg)';
}

/// A rung of the ladder: something that can produce headings.
///
/// Implementations must never throw synchronously from [isAvailable] or
/// [start]; a missing sensor is reported either as `false` from
/// [isAvailable] or as an error / silence on the stream (the ladder times
/// out and moves on).
abstract class HeadingSource {
  /// Which rung this is.
  HeadingSourceKind get kind;

  /// Cheap check for "this platform / device can have this sensor at all".
  /// Returning `true` is only a hint; the ladder still waits for samples.
  Future<bool> isAvailable();

  /// Opens the sensor and streams samples until the subscription is
  /// cancelled. Each call is a fresh start (used for retries).
  Stream<HeadingSample> start();

  /// Per-rung override of the ladder's acquire timeout, or `null` for the
  /// default. GPS course needs the user to walk first, so it waits longer.
  Duration? get acquireTimeout => null;

  /// Per-rung override of the ladder's stale timeout, or `null`.
  Duration? get staleTimeout => null;
}
