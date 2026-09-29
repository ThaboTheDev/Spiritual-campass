import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/geo/coordinates.dart';
import '../../../core/theme/app_theme.dart';

/// The large circular compass dial.
///
/// A fixed gold marker sits at the top; the rose rotates with the phone's true
/// heading and the needle points at Ekuphumuleni. When the needle is within
/// ±3° of the marker the ring turns gold and a light haptic is fired once.
class CompassDial extends StatefulWidget {
  const CompassDial({
    super.key,
    required this.headingDeg,
    required this.targetBearingDeg,
    this.size = 288,
    this.aligned = false,
    this.active = true,
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
    final bool aligned = widget.aligned && widget.active;
    if (aligned && !_wasAligned) {
      // One light tap as the needle reaches the marker.
      HapticFeedback.lightImpact();
    }
    _wasAligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final double heading = widget.headingDeg ?? 0.0;
    final double bearing = widget.targetBearingDeg ?? 0.0;
    final bool hasSensorValue = widget.headingDeg != null;
    final bool aligned = widget.aligned && widget.active;

    final Color ringColor = aligned
        ? AppColors.gold
        : (widget.active ? AppColors.accent : AppColors.border);
    final Color needleColor = aligned ? AppColors.gold : AppColors.accent;

    final double headingRad = Angles.toRadians(heading);
    final double needleRad = Angles.toRadians(bearing - heading);

    return Semantics(
      label: 'Compass dial. Bearing to Ekuphumuleni '
          '${widget.targetBearingDeg?.round() ?? 0} degrees. '
          '${aligned ? 'You are facing Ekuphumuleni.' : 'Turn to bring the needle to the marker.'}',
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
                              label.text,
                              style: TextStyle(
                                fontSize: label.text == 'N' ? 15 : 12.5,
                                fontWeight: FontWeight.w700,
                                color: label.text == 'N'
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
              if (widget.targetBearingDeg != null)
                Transform.rotate(
                  angle: needleRad,
                  child: CustomPaint(
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
                painter: _MarkerPainter(color: ringColor, aligned: aligned),
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
    );
  }
}

const List<_CardinalLabel> _cardinals = <_CardinalLabel>[
  _CardinalLabel('N', Alignment.topCenter, EdgeInsets.only(top: 30)),
  _CardinalLabel('E', Alignment.centerRight, EdgeInsets.only(right: 30)),
  _CardinalLabel('S', Alignment.bottomCenter, EdgeInsets.only(bottom: 30)),
  _CardinalLabel('W', Alignment.centerLeft, EdgeInsets.only(left: 30)),
];

class _CardinalLabel {
  const _CardinalLabel(this.text, this.alignment, this.padding);

  final String text;
  final Alignment alignment;
  final EdgeInsets padding;
}

/// Ring, tick marks and the soft inner gradient.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.headingRad,
    required this.ringColor,
    required this.aligned,
  });

  final double headingRad;
  final Color ringColor;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.width / 2.0;

    // Face.
    canvas.drawCircle(
      centre,
      radius - 2,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            AppColors.surfaceAlt,
            AppColors.surface,
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

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
    final double tickOuter = radius - 12;
    for (int degrees = 0; degrees < 360; degrees += 5) {
      final bool isCardinal = degrees % 90 == 0;
      final bool isMajor = degrees % 45 == 0;
      final double length = isCardinal ? 13.0 : (isMajor ? 9.0 : 5.0);
      final Paint paint = Paint()
        ..strokeWidth = isCardinal ? 2.0 : 1.0
        ..color = isCardinal
            ? AppColors.textSecondary
            : AppColors.textMuted.withValues(alpha: 0.5);

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(Angles.toRadians(degrees.toDouble()) - headingRad);
      canvas.drawLine(
        Offset(0, -tickOuter),
        Offset(0, -(tickOuter - length)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.headingRad != headingRad ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.aligned != aligned;
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
  const _MarkerPainter({required this.color, required this.aligned});

  final Color color;
  final bool aligned;

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

    if (aligned) {
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
      oldDelegate.color != color || oldDelegate.aligned != aligned;
}
