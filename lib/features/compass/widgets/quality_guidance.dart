import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/geo_math.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/localized_text.dart';
import '../compass_controller.dart';

/// Both screens use the same warnings and explicit mode selector.
class QualityGuidance extends ConsumerWidget {
  const QualityGuidance({
    super.key,
    required this.compass,
    required this.target,
    this.requiresPhoneHeading = false,
  });

  final CompassState compass;
  final TargetReading? target;
  final bool requiresPhoneHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<Bi> messages = <Bi>[];
    if (compass.isActive) {
      if (compass.isTravelDirection) {
        messages.add(
          requiresPhoneHeading
              ? S.phoneHeadingRequired
              : S.travelDirectionNotice,
        );
      }
      final Bi? issue = switch (compass.issue) {
        HeadingIssue.none => null,
        HeadingIssue.accuracyUnknown => S.accuracyUnknown,
        HeadingIssue.calibrationRequired =>
          compass.source == HeadingSourceKind.relativeCalibrated
              ? S.headingCalibrationFailed
              : S.calibrateHint,
        HeadingIssue.magneticInterference => S.magneticInterference,
        HeadingIssue.excessiveMotion => S.excessiveMotion,
        HeadingIssue.holdLevel => S.headingHoldLevel,
        HeadingIssue.stale => S.compassPaused,
        HeadingIssue.gyroDrift => S.gyroDriftWarning,
        HeadingIssue.weakMagneticField => S.weakMagneticField,
        HeadingIssue.modelExpired => S.magneticModelExpired,
        HeadingIssue.waitingForMovement => S.walkForDirection,
      };
      if (issue != null) {
        messages.add(issue);
      }
    }
    final TargetReading? reading = target;
    if (reading != null) {
      if (reading.isNearTarget) {
        messages.add(S.nearDestination);
      } else if (reading.isApproximate) {
        messages.add(S.locationApproximateDirection);
      } else if (!reading.locationReliable) {
        messages.add(S.locationStaleDirection);
      }
    }
    final Color color = compass.confidence == HeadingConfidence.reliable
        ? AppColors.success
        : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            AppButton(
              key: const ValueKey<String>('mode-phone'),
              label: S.phoneHeadingMode,
              icon: Icons.explore_outlined,
              variant: compass.isTravelDirection
                  ? AppButtonVariant.outlined
                  : AppButtonVariant.filled,
              onPressed: () => ref
                  .read(compassControllerProvider.notifier)
                  .setMode(CompassMode.phoneHeading),
            ),
            AppButton(
              key: const ValueKey<String>('mode-travel'),
              label: S.travelDirectionMode,
              icon: Icons.directions_walk,
              variant: compass.isTravelDirection
                  ? AppButtonVariant.filled
                  : AppButtonVariant.outlined,
              onPressed: () => ref
                  .read(compassControllerProvider.notifier)
                  .setMode(CompassMode.travelDirection),
            ),
          ],
        ),
        if (compass.isActive || messages.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SectionCard(
            borderColor: color.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (compass.isActive) ...<Widget>[
                  LocalizedText(
                    compass.confidence == HeadingConfidence.unreliable
                        ? S.directionUnreliable
                        : compass.confidence == HeadingConfidence.uncertain
                        ? S.directionApproximate
                        : S.headingAccuracy,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (compass.accuracyDeg != null &&
                      compass.accuracyDeg!.isFinite &&
                      compass.accuracyDeg! > 0)
                    Text(
                      '±${compass.accuracyDeg!.toStringAsFixed(1)}°',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
                for (final Bi message in messages) ...<Widget>[
                  const SizedBox(height: 6),
                  LocalizedText(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
