import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/localized_text.dart';
import '../compass_controller.dart';

/// The small status chip under the dial: which rung of the ladder is driving
/// the compass ("Compass sensor", "Raw sensors", …), coloured by health.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.compass});

  final CompassState compass;

  @override
  Widget build(BuildContext context) {
    final (Bi text, Color colour, IconData icon) = _describe(compass);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colour.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: colour),
            const SizedBox(width: 6),
            Flexible(
              child: LocalizedText(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Bi, Color, IconData) _describe(CompassState compass) {
    if (compass.paused) {
      return (S.compassPaused, AppColors.warning, Icons.pause_circle_outline);
    }
    switch (compass.status) {
      case CompassStatus.off:
        return (S.compassOff, AppColors.textMuted, Icons.explore_off_outlined);
      case CompassStatus.starting:
        return (S.compassWaiting, AppColors.warning, Icons.sensors_outlined);
      case CompassStatus.error:
        return (S.compassError, AppColors.danger, Icons.error_outline);
      case CompassStatus.locationRequired:
        return (
          S.compassNeedsLocation,
          AppColors.warning,
          Icons.location_searching,
        );
      case CompassStatus.noSensor:
        return (S.srcSun, AppColors.warning, Icons.wb_sunny_outlined);
      case CompassStatus.running:
        break;
    }
    final HeadingSourceKind source =
        compass.source ?? HeadingSourceKind.fusedCompass;
    if (compass.isStale) {
      return (S.compassPaused, AppColors.warning, Icons.vibration_outlined);
    }
    if (compass.awaitingCalibration) {
      return (S.compassNeedsCal, AppColors.warning, Icons.adjust_outlined);
    }
    if (compass.waitingForWalk) {
      return (S.walkForDirection, AppColors.warning, Icons.directions_walk);
    }
    final IconData icon = switch (source) {
      HeadingSourceKind.fusedCompass => Icons.explore_outlined,
      HeadingSourceKind.rawSensors => Icons.sensors_outlined,
      HeadingSourceKind.relativeCalibrated => Icons.screen_rotation_alt_outlined,
      HeadingSourceKind.gpsCourse => Icons.directions_walk,
      HeadingSourceKind.sunOnly => Icons.wb_sunny_outlined,
    };
    return (source.label, AppColors.success, icon);
  }
}
