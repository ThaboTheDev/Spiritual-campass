import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/heading_math.dart';
import 'package:tshk_compass/core/geo/heading_quality.dart';
import 'package:tshk_compass/core/wmm/wmm.dart';

void main() {
  final DateTime at = DateTime.utc(2026, 1, 1);
  HeadingAssessment assess({
    SensorReliability status = SensorReliability.high,
    double? accuracy,
    Vector3? magnetic,
    Vector3? acceleration,
    bool modelValid = true,
  }) => MagneticQualityMonitor().assess(
    timestamp: at,
    headingDeg: 0,
    reliability: status,
    accuracyDeg: accuracy,
    magneticMicrotesla: magnetic,
    linearAcceleration: acceleration,
    modelValid: modelValid,
  );

  test('HIGH status is not an invented degree estimate', () {
    expect(assess().confidence, HeadingConfidence.uncertain);
    expect(assess().issue, HeadingIssue.accuracyUnknown);
    expect(assess(accuracy: 0).confidence, HeadingConfidence.uncertain);
    expect(assess(accuracy: 5).confidence, HeadingConfidence.reliable);
    expect(
      assess(status: SensorReliability.unknown, accuracy: 5).confidence,
      HeadingConfidence.uncertain,
    );
  });
  test('unreliable / negative / excessive error is rejected', () {
    expect(assess(status: SensorReliability.unreliable).isUsable, isFalse);
    expect(assess(accuracy: -1).isUsable, isFalse);
    expect(assess(accuracy: double.nan).isUsable, isFalse);
    expect(assess(accuracy: 45).isUsable, isFalse);
    expect(
      assess(status: SensorReliability.medium, accuracy: 5).confidence,
      HeadingConfidence.uncertain,
    );
  });
  test('strong fields and excessive acceleration remove direction', () {
    expect(
      assess(accuracy: 5, magnetic: const Vector3(0, 120, 0)).issue,
      HeadingIssue.magneticInterference,
    );
    expect(
      assess(accuracy: 5, magnetic: const Vector3(0, 0, 0)).isUsable,
      isFalse,
    );
    expect(
      assess(accuracy: 5, acceleration: const Vector3(0, 4, 0)).issue,
      HeadingIssue.excessiveMotion,
    );
  });
  test('compare microtesla measurements with WMM nanotesla predictions', () {
    final MagneticField field = Wmm2025.field(
      latitudeDeg: -26.2,
      longitudeDeg: 28,
      altitudeKm: 1.5,
      when: at,
    );
    final Vector3 normal = Vector3(
      0,
      field.horizontalIntensityNT / 1000,
      -field.verticalComponentNT / 1000,
    );
    final MagneticQualityMonitor m = MagneticQualityMonitor();
    expect(
      m
          .assess(
            timestamp: at,
            headingDeg: 0,
            reliability: SensorReliability.high,
            accuracyDeg: 5,
            magneticMicrotesla: normal,
            gravity: const Vector3(0, 0, 9.81),
            expectedField: field,
          )
          .isUsable,
      isTrue,
    );
    expect(
      m
          .assess(
            timestamp: at.add(const Duration(seconds: 1)),
            headingDeg: 0,
            reliability: SensorReliability.high,
            accuracyDeg: 5,
            magneticMicrotesla: normal * 1.8,
            expectedField: field,
          )
          .issue,
      HeadingIssue.magneticInterference,
    );
  });
  test('a heading jump without measured phone rotation is suspicious', () {
    final MagneticQualityMonitor m = MagneticQualityMonitor();
    m.assess(
      timestamp: at,
      headingDeg: 0,
      reliability: SensorReliability.high,
      accuracyDeg: 5,
    );
    expect(
      m
          .assess(
            timestamp: at.add(const Duration(milliseconds: 40)),
            headingDeg: 90,
            reliability: SensorReliability.high,
            accuracyDeg: 5,
            gyroscope: const Vector3(0, 0, 0),
          )
          .issue,
      HeadingIssue.magneticInterference,
    );
  });
  test('a genuine fast turn is not discarded as an outlier', () {
    final MagneticQualityMonitor m = MagneticQualityMonitor();
    m.assess(
      timestamp: at,
      headingDeg: 0,
      reliability: SensorReliability.high,
      accuracyDeg: 5,
    );
    expect(
      m
          .assess(
            timestamp: at.add(const Duration(milliseconds: 40)),
            headingDeg: 90,
            reliability: SensorReliability.high,
            accuracyDeg: 5,
            gyroscope: const Vector3(0, 0, 20),
          )
          .confidence,
      HeadingConfidence.reliable,
    );
  });
  test('a plausible, stable field is not proof against systematic bias', () {
    // Rotating the horizontal field preserves its magnitude. Diagnostics
    // cannot guarantee detection of every such external interference.
    expect(
      assess(accuracy: 5, magnetic: const Vector3(25, 0, -35)).isUsable,
      isTrue,
    );
  });
  test('expired model prevents a reliable true-north claim', () {
    expect(
      assess(accuracy: 5, modelValid: false).issue,
      HeadingIssue.modelExpired,
    );
    expect(
      assess(accuracy: 5, modelValid: false).confidence,
      HeadingConfidence.uncertain,
    );
  });
}
