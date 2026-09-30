import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A 9-pointed star (nonagram/enneagram), the sacred emblem highlighting
/// Ekuphumuleni, the spiritual capital.
class NinePointedStar extends StatelessWidget {
  const NinePointedStar({
    super.key,
    this.size = 24.0,
    this.color = AppColors.gold,
    this.innerRadiusRatio = 0.46,
    this.shadowColor,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 1),
    this.strokeColor,
    this.strokeWidth = 0.0,
  });

  /// The width and height in logical pixels.
  final double size;

  /// Fill color of the star (defaults to Ekuphumuleni gold).
  final Color color;

  /// Ratio of inner valley radius to outer tip radius (0.46 gives sharp,
  /// well-balanced points).
  final double innerRadiusRatio;

  /// Shadow color drawn behind the star.
  final Color? shadowColor;

  /// Blur radius of the drop shadow.
  final double shadowBlurRadius;

  /// Offset of the drop shadow.
  final Offset shadowOffset;

  /// Optional outline stroke color.
  final Color? strokeColor;

  /// Width of the outline stroke if [strokeColor] is set.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _NinePointedStarPainter(
          color: color,
          innerRadiusRatio: innerRadiusRatio,
          shadowColor: shadowColor,
          shadowBlurRadius: shadowBlurRadius,
          shadowOffset: shadowOffset,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _NinePointedStarPainter extends CustomPainter {
  const _NinePointedStarPainter({
    required this.color,
    required this.innerRadiusRatio,
    this.shadowColor,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(0, 1),
    this.strokeColor,
    this.strokeWidth = 0.0,
  });

  final Color color;
  final double innerRadiusRatio;
  final Color? shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final Color? strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    // Inset slightly so tips and stroke do not clip at widget boundaries.
    final double inset = (strokeWidth > 0 ? strokeWidth / 2.0 : 0.0) + 1.0;
    final double outerRadius = math.max(0.0, math.min(cx, cy) - inset);
    final double innerRadius = outerRadius * innerRadiusRatio;

    final Path path = Path();
    const int numPoints = 9;
    const int totalVertices = numPoints * 2;
    const double step = math.pi / numPoints; // 20 degrees

    for (int i = 0; i < totalVertices; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double angle = -math.pi / 2.0 + i * step;
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Drop shadow.
    if (shadowColor != null && shadowBlurRadius > 0) {
      final Paint shadowPaint = Paint()
        ..color = shadowColor!
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlurRadius);
      canvas.save();
      canvas.translate(shadowOffset.dx, shadowOffset.dy);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    // Fill.
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Optional stroke.
    if (strokeColor != null && strokeWidth > 0) {
      final Paint strokePaint = Paint()
        ..color = strokeColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NinePointedStarPainter oldDelegate) {
    return color != oldDelegate.color ||
        innerRadiusRatio != oldDelegate.innerRadiusRatio ||
        shadowColor != oldDelegate.shadowColor ||
        shadowBlurRadius != oldDelegate.shadowBlurRadius ||
        shadowOffset != oldDelegate.shadowOffset ||
        strokeColor != oldDelegate.strokeColor ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
