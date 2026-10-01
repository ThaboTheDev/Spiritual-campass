import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/formatters.dart';
import '../../../core/geo/coordinates.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/language_scope.dart';

/// The large circular compass dial.
///
/// A fixed gold marker sits at the top; the rose rotates with the phone's true
/// heading and the needle points at Ekuphumuleni in the same north frame.
/// Gold/haptics require the shared uncertainty policy, not just a ±3° arrow.
class CompassDial extends StatefulWidget {
  const CompassDial({
    super.key,
    required this.headingDeg,
    required this.targetBearingDeg,
    this.size = 288,
    this.aligned = false,
    this.active = true,
    this.simple = false,
    this.travelDirection = false,
  });

  /// True heading of the device in degrees, or `null` when the sensor has not
  /// produced a value yet (the rose then sits at north).
  final double? headingDeg;

  /// True bearing to Ekuphumuleni in degrees.
  final double? targetBearingDeg;

  /// Outer size of the dial in logical pixels.
  final double size;

  /// Whether the needle is within the alignment tolerance.
  final bool aligned;

  /// Whether the compass has been started (a stopped dial is dimmed).
  final bool active;

  /// Low performance profile: no gradient face, no halo, flat colours.
  final bool simple;
  final bool travelDirection;

  /// How close to the marker counts as "facing Ekuphumuleni".
  static const double alignmentToleranceDeg = 3.0;

  @override
  State<CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<CompassDial> {
  bool _wasAligned = false;

  @override
  void didUpdateWidget(CompassDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool aligned =
        widget.aligned &&
        widget.active &&
        !widget.travelDirection &&
        widget.headingDeg != null &&
        widget.headingDeg!.isFinite &&
        widget.targetBearingDeg != null &&
        widget.targetBearingDeg!.isFinite;
    if (aligned && !_wasAligned) {
      // One light tap as the needle reaches the marker.
      HapticFeedback.lightImpact();
    }
    _wasAligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final double size = widget.size;
    final bool hasSensorValue =
        widget.headingDeg != null && widget.headingDeg!.isFinite;
    final bool hasTarget =
        widget.targetBearingDeg != null && widget.targetBearingDeg!.isFinite;
    final double heading = hasSensorValue ? widget.headingDeg! : 0;
    final double bearing = hasTarget ? widget.targetBearingDeg! : 0;
    final bool aligned =
        widget.aligned &&
        widget.active &&
        !widget.travelDirection &&
        widget.headingDeg != null &&
        widget.headingDeg!.isFinite &&
        widget.targetBearingDeg != null &&
        widget.targetBearingDeg!.isFinite;

    final Color ringColor = aligned
        ? AppColors.gold
        : (widget.active ? AppColors.accent : AppColors.border);
    final Color needleColor = aligned ? AppColors.gold : AppColors.accent;

    final double headingRad = Angles.toRadians(heading);
    final double needleRad = Angles.toRadians(bearing - heading);

    return Semantics(
      label: widget.travelDirection
          ? S.travelDirectionNotice.text
          : !hasSensorValue
          ? S.directionUnreliable.text
          : !hasTarget
          ? '${S.phoneHeadingMode.text} ${Formatters.bearing(heading)}. ${S.targetDirectionUnavailable.text}'
          : '${S.dialLabel(widget.targetBearingDeg?.round() ?? 0).text} '
                '${aligned ? '${S.aligned.text}.' : S.dialTurnHint.text}',
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Opacity(
            opacity: widget.active ? 1.0 : 0.45,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Ring, ticks and cardinal letters.
                CustomPaint(
                  size: Size(size, size),
                  painter: _DialPainter(
                    headingRad: headingRad,
                    ringColor: ringColor,
                    aligned: aligned,
                    simple: widget.simple,
                  ),
                ),
                Transform.rotate(
                  angle: -headingRad,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      children: <Widget>[
                        for (final _CardinalLabel label in _cardinals)
                          Align(
                            alignment: label.alignment,
                            child: Padding(
                              padding: label.padding,
                              child: Text(
                                Formatters.cardinal(
                                  label.bearingDeg,
                                  sixteenPoint: false,
                                ),
                                style: TextStyle(
                                  fontSize: label.isNorth ? 15 : 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: label.isNorth
                                      ? AppColors.gold
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // The needle pointing at Ekuphumuleni.
                if (hasTarget && hasSensorValue)
                  Transform.rotate(
                    angle: needleRad,
                    child: CustomPaint(
                      key: const ValueKey<String>('compass-target-needle'),
                      size: Size(size, size),
                      painter: _NeedlePainter(
                        color: needleColor,
                        dimmed: !hasSensorValue,
                      ),
                    ),
                  ),
                // Fixed marker at the top.
                CustomPaint(
                  size: Size(size, size),
                  painter: _MarkerPainter(
                    color: ringColor,
                    aligned: aligned,
                    simple: widget.simple,
                  ),
                ),
                // Centre hub.
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: ringColor, width: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const List<_CardinalLabel> _cardinals = <_CardinalLabel>[
  _CardinalLabel(0, Alignment.topCenter, EdgeInsets.only(top: 30)),
  _CardinalLabel(90, Alignment.centerRight, EdgeInsets.only(right: 30)),
  _CardinalLabel(180, Alignment.bottomCenter, EdgeInsets.only(bottom: 30)),
  _CardinalLabel(270, Alignment.centerLeft, EdgeInsets.only(left: 30)),
];

/// A cardinal letter on the rose; the letter itself follows the app language
/// (see `Formatters.compassPoints`).
class _CardinalLabel {
  const _CardinalLabel(this.bearingDeg, this.alignment, this.padding);

  final double bearingDeg;
  final Alignment alignment;
  final EdgeInsets padding;

  bool get isNorth => bearingDeg == 0;
}

/// Ring, tick marks and the soft inner gradient.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.headingRad,
    required this.ringColor,
    required this.aligned,
    this.simple = false,
  });

  final double headingRad;
  final Color ringColor;
  final bool aligned;
  final bool simple;

  /// Tick marks are the same for every frame at a given size, so the paths
  /// are built once per size and only rotated. Three paths: minor, major,
  /// cardinal (different stroke widths / colours).
  static final Map<double, List<Path>> _tickCache = <double, List<Path>>{};

  static List<Path> _ticksFor(double radius) {
    return _tickCache.putIfAbsent(radius, () {
      final Path minor = Path();
      final Path major = Path();
      final Path cardinal = Path();
      final double tickOuter = radius - 12;
      for (int degrees = 0; degrees < 360; degrees += 5) {
        final bool isCardinal = degrees % 90 == 0;
        final bool isMajor = degrees % 45 == 0;
        final double length = isCardinal ? 13.0 : (isMajor ? 9.0 : 5.0);
        final double a = Angles.toRadians(degrees.toDouble());
        final double sa = math.sin(a), ca = math.cos(a);
        final Offset from = Offset(sa * tickOuter, -ca * tickOuter);
        final Offset to = Offset(
          sa * (tickOuter - length),
          -ca * (tickOuter - length),
        );
        final Path target = isCardinal ? cardinal : (isMajor ? major : minor);
        target
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
      return <Path>[minor, major, cardinal];
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.width / 2.0;

    // Face.
    if (simple) {
      canvas.drawCircle(centre, radius - 2, Paint()..color = AppColors.surface);
    } else {
      canvas.drawCircle(
        centre,
        radius - 2,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[AppColors.surfaceAlt, AppColors.surface],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Outer ring.
    canvas.drawCircle(
      centre,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = aligned ? 3.0 : 1.5
        ..color = ringColor,
    );

    // Faint inner ring.
    canvas.drawCircle(
      centre,
      radius * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border.withValues(alpha: 0.75),
    );

    // Tick marks: every 5°, longer every 45°, longest at the cardinals.
    // Pre-built paths, rotated as a whole.
    final List<Path> ticks = _ticksFor(radius);
    final Paint minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.textMuted.withValues(alpha: 0.5);
    final Paint cardinalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = AppColors.textSecondary;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(-headingRad);
    canvas.drawPath(ticks[0], minorPaint);
    canvas.drawPath(ticks[1], minorPaint);
    canvas.drawPath(ticks[2], cardinalPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.headingRad != headingRad ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.aligned != aligned ||
      oldDelegate.simple != simple;
}

/// The needle that points at Ekuphumuleni.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({required this.color, this.dimmed = false});

  final Color color;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.width / 2.0;
    final double tip = radius * 0.80;
    final double tail = radius * 0.30;
    final double halfWidth = radius * 0.075;
    final Color paint = dimmed ? color.withValues(alpha: 0.55) : color;

    // Pointing half.
    final Path head = Path()
      ..moveTo(centre.dx, centre.dy - tip)
      ..lineTo(centre.dx - halfWidth, centre.dy - tip + halfWidth * 3.2)
      ..lineTo(centre.dx + halfWidth, centre.dy - tip + halfWidth * 3.2)
      ..close();
    canvas.drawPath(head, Paint()..color = paint);

    // Shaft.
    canvas.drawLine(
      centre,
      Offset(centre.dx, centre.dy - tip + halfWidth * 3.0),
      Paint()
        ..color = paint.withValues(alpha: 0.85)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    // Counterweight tail.
    canvas.drawLine(
      centre,
      Offset(centre.dx, centre.dy + tail),
      Paint()
        ..color = AppColors.textMuted.withValues(alpha: 0.6)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(centre.dx, centre.dy + tail),
      4.5,
      Paint()..color = AppColors.textMuted.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dimmed != dimmed;
}

/// The fixed marker at the top of the dial, where the needle should end up.
class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.color,
    required this.aligned,
    this.simple = false,
  });

  final Color color;
  final bool aligned;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    final double centreX = size.width / 2.0;
    const double top = 2.0;
    final double width = aligned ? 13.0 : 11.0;
    final double height = aligned ? 15.0 : 12.0;

    final Path triangle = Path()
      ..moveTo(centreX - width, top)
      ..lineTo(centreX + width, top)
      ..lineTo(centreX, top + height)
      ..close();

    canvas.drawPath(triangle, Paint()..color = color);
    canvas.drawPath(
      triangle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.background.withValues(alpha: 0.8),
    );

    if (aligned && !simple) {
      // A soft gold halo when the needle is on target.
      canvas.drawCircle(
        Offset(centreX, top + height + 6),
        14,
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.aligned != aligned ||
      oldDelegate.simple != simple;
}
