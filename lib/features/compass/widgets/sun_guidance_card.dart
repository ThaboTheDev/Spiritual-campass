import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/geo/coordinates.dart';
import '../../../core/geo/geo_math.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/sun/sun_position.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/localized_text.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';

/// Rung 5, "Sun guidance": how to face Ekuphumuleni with no heading sensor.
///
/// * the sun's azimuth and height right now;
/// * "Face the sun, then turn N° to the left/right" (or "turn until the sun is
///   on your left/right" for the msamo);
/// * the stick-shadow method;
/// * the hand-compass bearing (magnetic).
///
/// Everything here needs only a location and the clock, so it works with no
/// sensor at all.
class SunGuidanceCard extends StatelessWidget {
  const SunGuidanceCard({
    super.key,
    required this.sun,
    required this.target,
    required this.declinationDeg,
    this.reason,
    this.compact = false,
  });

  /// Sun position, or `null` without a location.
  final SunPosition? sun;

  /// Bearing / distance to Ekuphumuleni, or `null` without a location.
  final TargetReading? target;

  /// WMM declination for the hand-compass bearing, or `null`.
  final double? declinationDeg;

  /// Why the card is shown (no sensor / needs calibration).
  final Bi? reason;

  /// Fewer lines (Msamo screen).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Bearings below use language-specific compass letters.
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final TextStyle? body = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13,
      height: 1.45,
    );
    final SunPosition? sun = this.sun;
    final TargetReading? target = this.target;

    final List<Widget> lines = <Widget>[];

    if (target == null || sun == null) {
      lines.add(LocalizedText(S.notSetHint, style: body));
    } else if (sun.elevationDeg < -1) {
      lines.add(LocalizedText(S.sunNightLong, style: body));
    } else {
      final double delta = Angles.shortestDelta(sun.azimuthDeg, target.bearingDeg);
      final int turn = delta.abs().round();
      lines.add(
        LocalizedText(
          turn <= 3 ? S.sunAhead : S.sunTurn(turn, toRight: delta > 0),
          style: body?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      if (!compact && turn > 3) {
        // "Turn until the sun is on your left/right": the sun sits on the
        // side opposite to the turn.
        lines.add(const SizedBox(height: 6));
        lines.add(LocalizedText(S.sunOnSide(onRight: delta < 0), style: body));
      }
      if (!compact && sun.castsShadow) {
        final double shadow = sun.shadowBearingDeg;
        final double ds = Angles.shortestDelta(shadow, target.bearingDeg);
        lines.add(const SizedBox(height: 6));
        lines.add(
          LocalizedText(
            S.stickShadowGuide(
              Formatters.bearingWithCardinal(shadow),
              ds.abs().round(),
              toRight: ds > 0,
            ),
            style: body,
          ),
        );
      }
    }

    final double? magnetic = (target != null && declinationDeg != null)
        ? GeoMath.trueToMagnetic(target.bearingDeg, declinationDeg!)
        : null;

    return SectionCard(
      borderColor: AppColors.gold.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.wb_sunny_outlined,
                  size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  S.sunGuidanceTitle,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (reason != null) ...<Widget>[
            const SizedBox(height: 6),
            LocalizedText(
              reason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (sun != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: _Value(
                    label: S.sunNow,
                    value: Formatters.bearingWithCardinal(sun.azimuthDeg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Value(
                    label: S.sunHeight,
                    value: '${Formatters.elevation(sun.elevationDeg)}°',
                  ),
                ),
              ],
            ),
          if (sun != null) const SizedBox(height: 10),
          ...lines,
          if (magnetic != null) ...<Widget>[
            const SizedBox(height: 10),
            LocalizedText(
              S.handCompass(magnetic.round()),
              style: body?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

  final Bi label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LocalizedText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 11.5,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
