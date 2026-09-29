import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';

/// One raw sample from the device compass.
class CompassReading {
  const CompassReading({this.headingDeg, this.accuracyDeg});

  /// Magnetic heading in degrees, 0 = magnetic north, increasing clockwise.
  /// `null` when the sensor produced no usable value (no sensor, or a device
  /// that reports nothing until it has been calibrated).
  final double? headingDeg;

  /// Estimated error of the heading in degrees (±), or `null` when the platform
  /// does not report one.
  ///
  /// iOS reports the real deviation. The Android implementation of
  /// flutter_compass maps the sensor status to degrees: high = 15, medium = 30,
  /// low = 45, unreliable = null.
  final double? accuracyDeg;

  /// Whether this sample carries a usable heading.
  bool get hasHeading =>
      headingDeg != null && !headingDeg!.isNaN && !headingDeg!.isInfinite;

  @override
  String toString() => 'CompassReading($headingDeg°, ±$accuracyDeg°)';
}

/// Platform compass access, kept behind an interface so the controllers can be
/// unit tested.
abstract class CompassService {
  /// Live heading samples, or `null` when the platform has no compass at all
  /// (this is what flutter_compass returns on the web).
  Stream<CompassReading>? get readings;

  /// Whether the plugin exposes a compass stream on this platform.
  bool get isSupported;
}

/// `flutter_compass` implementation of [CompassService].
class FlutterCompassService implements CompassService {
  @override
  bool get isSupported => FlutterCompass.events != null;

  @override
  Stream<CompassReading>? get readings {
    final Stream<CompassEvent>? source = FlutterCompass.events;
    if (source == null) {
      return null;
    }
    return source.map<CompassReading>(
      (CompassEvent event) => CompassReading(
        headingDeg: event.heading,
        accuracyDeg: event.accuracy,
      ),
    );
  }
}
