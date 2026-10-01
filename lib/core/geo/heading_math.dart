import 'dart:math' as math;

import 'coordinates.dart';

/// A plain 3-vector in the device sensor frame.
///
/// Android / sensors_plus convention: x points to the right of the screen,
/// y to the top edge, z out of the screen towards the user. The accelerometer
/// reports the *reaction* to gravity, so a phone lying flat, screen up, reads
/// roughly (0, 0, +9.81).
class Vector3 {
  const Vector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  /// Euclidean length.
  double get length => math.sqrt(x * x + y * y + z * z);

  /// Whether every component is a finite number and the vector is not zero.
  bool get isUsable => x.isFinite && y.isFinite && z.isFinite && length > 1e-6;

  /// Unit vector in the same direction (the zero vector stays zero).
  Vector3 normalized() {
    final double n = length;
    if (n < 1e-9) {
      return this;
    }
    return Vector3(x / n, y / n, z / n);
  }

  /// Dot product.
  double dot(Vector3 o) => x * o.x + y * o.y + z * o.z;

  /// Cross product `this × o`.
  Vector3 cross(Vector3 o) =>
      Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  Vector3 operator -(Vector3 o) => Vector3(x - o.x, y - o.y, z - o.z);
  Vector3 operator +(Vector3 o) => Vector3(x + o.x, y + o.y, z + o.z);
  Vector3 operator *(double k) => Vector3(x * k, y * k, z * k);

  @override
  String toString() =>
      'Vector3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Pitch and roll of the phone, derived from the accelerometer.
class Attitude {
  const Attitude({required this.pitchDeg, required this.rollDeg});

  /// Rotation about the device x axis: positive when the top edge is raised.
  /// 0° flat, ±90° upright.
  final double pitchDeg;

  /// Rotation about the device y axis: positive when the right edge is raised.
  final double rollDeg;

  /// How flat the phone has to be to count as level.
  static const double flatThresholdDeg = 8.0;

  /// "Flat · Ithe bha": both angles within [flatThresholdDeg].
  bool get isFlat =>
      pitchDeg.abs() < flatThresholdDeg && rollDeg.abs() < flatThresholdDeg;

  /// Pitch / roll from a gravity (accelerometer) reading in the device frame.
  ///
  /// Uses the same convention as the web edition's `beta` / `gamma`: flat is
  /// (0, 0); raising the top edge towards you gives a positive pitch; raising
  /// the right edge gives a positive roll.
  static Attitude fromAccelerometer(Vector3 g) {
    final Vector3 n = g.normalized();
    // The accelerometer reads the reaction to gravity, i.e. the device-frame
    // "up" vector. Its y component grows as the top edge is raised, its x
    // component as the right edge is raised.
    final double pitch = Angles.toDegrees(math.atan2(n.y, n.z));
    final double roll = Angles.toDegrees(
      math.atan2(n.x, math.sqrt(n.y * n.y + n.z * n.z)),
    );
    return Attitude(pitchDeg: pitch, rollDeg: roll);
  }

  @override
  String toString() =>
      'Attitude(pitch: ${pitchDeg.toStringAsFixed(1)}°, roll: ${rollDeg.toStringAsFixed(1)}°)';
}

/// The heading maths of the compass engine, ported from the web edition.
///
/// "Heading" always means the direction the *user faces*: the top edge of the
/// screen when the phone lies flat, blending smoothly into the back of the
/// phone as it is raised upright. That is what [facing] computes; every source
/// that has a full orientation (rotation matrix, quaternion or Euler angles)
/// goes through it.
abstract final class HeadingMath {
  /// Facing direction from the device axes expressed in Earth coordinates
  /// (E, N, Up).
  ///
  /// `x*`, `y*`, `z*` are the device x (right), y (top) and z (out of the
  /// screen) axes in the Earth frame; [screenAngleRad] rotates the notion of
  /// "top edge" for a rotated UI (0 in a portrait-locked app).
  ///
  /// The weight `w = tU²` is 0 when the phone is flat (use the top edge) and 1
  /// when it is upright (use the back of the phone, `-z`).
  static double facing(
    double xE,
    double xN,
    double xU,
    double yE,
    double yN,
    double yU,
    double zE,
    double zN,
    double zU,
    double screenAngleRad,
  ) {
    final double st = math.sin(screenAngleRad);
    final double ct = math.cos(screenAngleRad);
    // The top edge of the screen.
    final double tE = st * xE + ct * yE;
    final double tN = st * xN + ct * yN;
    final double tU = st * xU + ct * yU;
    // 0 when flat, 1 when upright.
    final double w = tU * tU;
    // Add the back of the phone as it rises.
    final double east = tE - w * zE;
    final double north = tN - w * zN;
    // A nearly vertical / cancelling facing vector has no useful azimuth.
    // NaN is intentionally rejected by the sources, never converted to north.
    if (!east.isFinite ||
        !north.isFinite ||
        east * east + north * north < 0.04) {
      return double.nan;
    }
    return Angles.normalize360(Angles.toDegrees(math.atan2(east, north)));
  }

  /// Heading from W3C device-orientation Euler angles (degrees), as used by
  /// the web edition. [screenAngleDeg] is `screen.orientation.angle`.
  static double headingFromEuler(
    double alphaDeg,
    double betaDeg,
    double gammaDeg, {
    double screenAngleDeg = 0,
  }) {
    final double a = Angles.toRadians(alphaDeg);
    final double b = Angles.toRadians(betaDeg);
    final double g = Angles.toRadians(gammaDeg);
    final double ca = math.cos(a), sa = math.sin(a);
    final double cb = math.cos(b), sb = math.sin(b);
    final double cg = math.cos(g), sg = math.sin(g);
    return facing(
      ca * cg - sa * sb * sg,
      sa * cg + ca * sb * sg,
      -cb * sg,
      -sa * cb,
      ca * cb,
      sb,
      ca * sg + sa * sb * cg,
      sa * sg - ca * sb * cg,
      cb * cg,
      Angles.toRadians(screenAngleDeg),
    );
  }

  /// Heading from a device → Earth unit quaternion `(x, y, z, w)` with Earth
  /// x = east, y = north, z = up (the frame of a rotation-vector sensor).
  static double headingFromQuat(
    double x,
    double y,
    double z,
    double w, {
    double screenAngleDeg = 0,
  }) {
    final Quaternion q = Quaternion(x, y, z, w).normalized();
    x = q.x;
    y = q.y;
    z = q.z;
    w = q.w;
    return facing(
      1 - 2 * (y * y + z * z),
      2 * (x * y + w * z),
      2 * (x * z - w * y),
      2 * (x * y - w * z),
      1 - 2 * (x * x + z * z),
      2 * (y * z + w * x),
      2 * (x * z + w * y),
      2 * (y * z - w * x),
      1 - 2 * (x * x + y * y),
      Angles.toRadians(screenAngleDeg),
    );
  }

  /// Tilt-compensated *magnetic* heading from a raw accelerometer and
  /// magnetometer sample (device frame), or `null` when the vectors are
  /// degenerate (zero, parallel, or not finite).
  ///
  /// This is `SensorManager.getRotationMatrix` followed by [facing]:
  ///
  /// * `H = M × A` points east, `A` points up, `N = A × H` points north;
  /// * the rows `[H; N; A]` are the Earth axes in the device frame, so the
  ///   *columns* are the device axes in the Earth frame, which is exactly what
  ///   [facing] wants.
  static double? tiltCompensatedHeading(
    Vector3 accelerometer,
    Vector3 magnetometer, {
    double screenAngleDeg = 0,
  }) {
    if (!accelerometer.isUsable || !magnetometer.isUsable) {
      return null;
    }
    final Vector3 a = accelerometer.normalized();
    final Vector3 h = magnetometer.cross(a);
    if (h.length < 1e-6) {
      // Field parallel to gravity: no horizontal component to steer by.
      return null;
    }
    final Vector3 e = h.normalized();
    final Vector3 n = a.cross(e);
    // Device x axis in Earth coords: (Hx, Nx, Ax), and so on.
    final double result = facing(
      e.x,
      n.x,
      a.x, //
      e.y,
      n.y,
      a.y, //
      e.z,
      n.z,
      a.z, //
      Angles.toRadians(screenAngleDeg),
    );
    return result.isFinite ? result : null;
  }

  /// Yaw rate about the Earth-vertical axis from a gyroscope sample (rad/s)
  /// and the current gravity direction. Positive means the heading is
  /// increasing (turning clockwise seen from above).
  static double yawRateDegPerSec(Vector3 gyroscopeRadPerSec, Vector3 gravity) {
    if (!gravity.isUsable) {
      return 0;
    }
    final Vector3 up = gravity.normalized();
    // A right-handed rotation about "up" is anticlockwise seen from above.
    return -Angles.toDegrees(gyroscopeRadPerSec.dot(up));
  }

  /// The calibration offset that maps a relative heading onto a known
  /// absolute direction: `offset = target − relative`.
  static double calibrationOffset({
    required double targetHeadingDeg,
    required double relativeHeadingDeg,
  }) => Angles.normalize360(targetHeadingDeg - relativeHeadingDeg);

  /// Applies a calibration offset to a relative heading.
  static double applyOffset(double relativeHeadingDeg, double offsetDeg) =>
      Angles.normalize360(relativeHeadingDeg + offsetDeg);

  /// Converts a magnetic heading to true using the WMM declination
  /// (east-positive). GPS course and sun-calibrated headings are already true
  /// and must not go through here.
  static double magneticToTrue(double magneticDeg, double declinationDeg) =>
      Angles.normalize360(magneticDeg + declinationDeg);
}

/// Unit quaternion mapping device axes to an Earth / arbitrary level frame.
/// Relative turn tracking integrates all three axes, not only scalar yaw.
class Quaternion {
  const Quaternion(this.x, this.y, this.z, this.w);

  static const Quaternion identity = Quaternion(0, 0, 0, 1);
  final double x;
  final double y;
  final double z;
  final double w;

  Quaternion normalized() {
    final double n = math.sqrt(x * x + y * y + z * z + w * w);
    if (!n.isFinite || n < 1e-9) {
      return const Quaternion(double.nan, double.nan, double.nan, double.nan);
    }
    return Quaternion(x / n, y / n, z / n, w / n);
  }

  Quaternion get conjugate => Quaternion(-x, -y, -z, w);

  Quaternion operator *(Quaternion q) => Quaternion(
    w * q.x + x * q.w + y * q.z - z * q.y,
    w * q.y - x * q.z + y * q.w + z * q.x,
    w * q.z + x * q.y - y * q.x + z * q.w,
    w * q.w - x * q.x - y * q.y - z * q.z,
  );

  Vector3 rotate(Vector3 v) {
    final Quaternion r = this * Quaternion(v.x, v.y, v.z, 0) * conjugate;
    return Vector3(r.x, r.y, r.z);
  }

  static Quaternion rotation(Vector3 radians) {
    final double angle = radians.length;
    if (angle < 1e-9) {
      return identity;
    }
    final double scale = math.sin(angle / 2) / angle;
    return Quaternion(
      radians.x * scale,
      radians.y * scale,
      radians.z * scale,
      math.cos(angle / 2),
    );
  }

  /// Creates a level reference from gravity. Heading is deliberately arbitrary
  /// until the user anchors it; the matrix rows are east, north and up.
  static Quaternion fromUp(Vector3 gravity) {
    final Vector3 up = gravity.normalized();
    Vector3 north = const Vector3(0, 1, 0) - up * up.y;
    if (north.length < 0.2) {
      north = const Vector3(0, 0, -1) + up * up.z;
    }
    north = north.normalized();
    final Vector3 east = north.cross(up).normalized();
    return fromMatrix(<double>[
      east.x,
      east.y,
      east.z,
      north.x,
      north.y,
      north.z,
      up.x,
      up.y,
      up.z,
    ]);
  }

  /// Row-major device → Earth rotation matrix.
  static Quaternion fromMatrix(List<double> m) {
    if (m.length != 9 || m.any((double v) => !v.isFinite)) {
      return const Quaternion(double.nan, double.nan, double.nan, double.nan);
    }
    final double trace = m[0] + m[4] + m[8];
    if (trace > 0) {
      final double s = math.sqrt(trace + 1) * 2;
      return Quaternion(
        (m[7] - m[5]) / s,
        (m[2] - m[6]) / s,
        (m[3] - m[1]) / s,
        0.25 * s,
      ).normalized();
    }
    if (m[0] > m[4] && m[0] > m[8]) {
      final double s = math.sqrt(1 + m[0] - m[4] - m[8]) * 2;
      return Quaternion(
        0.25 * s,
        (m[1] + m[3]) / s,
        (m[2] + m[6]) / s,
        (m[7] - m[5]) / s,
      ).normalized();
    }
    if (m[4] > m[8]) {
      final double s = math.sqrt(1 + m[4] - m[0] - m[8]) * 2;
      return Quaternion(
        (m[1] + m[3]) / s,
        0.25 * s,
        (m[5] + m[7]) / s,
        (m[2] - m[6]) / s,
      ).normalized();
    }
    final double s = math.sqrt(1 + m[8] - m[0] - m[4]) * 2;
    return Quaternion(
      (m[2] + m[6]) / s,
      (m[5] + m[7]) / s,
      0.25 * s,
      (m[3] - m[1]) / s,
    ).normalized();
  }
}
