import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/sun/sun_position.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/localized_text.dart';
import '../compass_controller.dart';
import '../compass_providers.dart';

/// The one-tap "Set" controls of the relative (gyroscope) source.
///
/// Shown while [CompassState.awaitingCalibration]; hidden once calibrated
/// (a small "Set again" link remains).
class CalibrationControls extends ConsumerWidget {
  const CalibrationControls({super.key, required this.compass});

  final CompassState compass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SunPosition? sun = ref.watch(sunPositionProvider).valueOrNull;
    final bool sunUp = sun != null && sun.canAnchorHeading;

    if (!compass.awaitingCalibration) {
      if (compass.source != HeadingSourceKind.relativeCalibrated ||
          compass.calibrationAnchor == null) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: LocalizedText(
              compass.calibrationAnchor == CalibrationAnchor.sun
                  ? S.calibratedToSun
                  : S.calibratedToNorth,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton(
            label: S.recalibrate,
            variant: AppButtonVariant.text,
            onPressed: () =>
                ref.read(compassControllerProvider.notifier).clearCalibration(),
          ),
        ],
      );
    }

    return SectionCard(
      borderColor: AppColors.warning.withValues(alpha: 0.45),
      color: AppColors.warning.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LocalizedText(S.calibrationTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          LocalizedText(
            S.calibrationBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(S.sunSafety, style: theme.textTheme.bodySmall),
          if (!sunUp) ...<Widget>[
            const SizedBox(height: 6),
            LocalizedText(
              S.sunAnchorUnavailable,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: S.setToSun,
            icon: Icons.wb_sunny_outlined,
            onPressed: sunUp ? () => _set(context, ref, toSun: true) : null,
            expand: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: S.setToNorth,
            icon: Icons.north_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: () => _set(context, ref, toSun: false),
            expand: true,
          ),
        ],
      ),
    );
  }

  void _set(BuildContext context, WidgetRef ref, {required bool toSun}) {
    final CompassController controller = ref.read(
      compassControllerProvider.notifier,
    );
    final bool ok = toSun
        ? controller.calibrateToSun()
        : controller.calibrateToNorth();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              S.headingCalibrationFailed.text,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
    }
  }
}
