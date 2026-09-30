import 'package:flutter/material.dart';

import '../../../core/geo/heading_math.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';

/// A small spirit level: a bubble that drifts towards the raised side of the
/// phone, with "Flat" / "Tilted" (in the app language) beside it.
///
/// Shown only while a motion sensor is active. The bubble moves ±[travel]
/// pixels for ±30° of tilt, like the web edition's `drawBubble`.
class LevelBubble extends StatelessWidget {
  const LevelBubble({
    super.key,
    required this.attitude,
    this.size = 44,
    this.travel = 14,
    this.animate = true,
  });

  /// Pitch / roll from the accelerometer.
  final Attitude attitude;

  /// Diameter of the level.
  final double size;

  /// Maximum bubble offset from the centre, in logical pixels.
  final double travel;

  /// Whether the bubble eases (off in the low performance profile).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bool flat = attitude.isFlat;
    final double dx = (attitude.rollDeg / 30).clamp(-1.0, 1.0) * travel;
    final double dy = -(attitude.pitchDeg / 30).clamp(-1.0, 1.0) * travel;
    final Color colour = flat ? AppColors.success : AppColors.warning;
    final ThemeData theme = Theme.of(context);
    LanguageScope.watch(context);

    return Semantics(
      label: flat ? S.flat.text : S.tilted.text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RepaintBoundary(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceAlt,
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  // Target ring.
                  Container(
                    width: size * 0.42,
                    height: size * 0.42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colour.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                  ),
                  // Bubble.
                  AnimatedContainer(
                    duration: animate
                        ? const Duration(milliseconds: 90)
                        : Duration.zero,
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(dx, dy, 0),
                    width: size * 0.3,
                    height: size * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colour,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          LocalizedText(
            flat ? S.flat : S.tilted,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colour,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
