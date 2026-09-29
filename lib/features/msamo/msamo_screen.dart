import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bilingual_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/constrained_content.dart';
import '../compass/compass_controller.dart';
import '../compass/compass_providers.dart';
import '../compass/widgets/compass_dial.dart';
import 'msamo_controller.dart';

/// The Msamo tab: turn the msamo until it faces Ekuphumuleni, then freeze the
/// direction so the spot can be marked.
class MsamoScreen extends ConsumerWidget {
  const MsamoScreen({super.key});

  /// How close counts as "facing Ekuphumuleni".
  static const double alignmentToleranceDeg = CompassDial.alignmentToleranceDeg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CompassState compass = ref.watch(compassControllerProvider);
    final MsamoState msamo = ref.watch(msamoControllerProvider);
    final TargetReading? target = ref.watch(targetReadingProvider);
    final double? declination = ref.watch(declinationProvider);

    final double? heading = compass.trueHeadingDeg ?? compass.magneticHeadingDeg;
    final double? liveBearing = target?.bearingDeg;

    // A locked direction wins over the live bearing.
    final double? bearing = msamo.lockedBearingDeg ?? liveBearing;
    final bool locked = msamo.isLocked && bearing != null;

    final double? delta = (bearing == null || heading == null)
        ? null
        : Angles.shortestDelta(heading, bearing);
    final bool aligned = delta != null && delta.abs() <= alignmentToleranceDeg;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              const AppHeader(),
              const SizedBox(height: 16),

              SectionCard(
                child: BilingualText(
                  S.msamoIntro,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live turn instruction.
              _TurnInstruction(
                deltaDeg: delta,
                aligned: aligned,
                hasBearing: bearing != null,
                hasHeading: heading != null,
                locked: locked,
                onStart: () =>
                    ref.read(compassControllerProvider.notifier).start(),
                active: compass.isActive,
              ),
              const SizedBox(height: 16),

              // Small dial so the user can see the needle as they turn.
              if (bearing != null)
                Center(
                  child: CompassDial(
                    headingDeg: heading,
                    targetBearingDeg: bearing,
                    aligned: aligned,
                    active: compass.isRunning,
                    size: 232,
                  ),
                ),
              if (bearing != null) const SizedBox(height: 16),

              // Required direction: true and magnetic.
              SectionCard(
                borderColor: aligned
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.border,
                color: aligned
                    ? AppColors.gold.withValues(alpha: 0.07)
                    : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BilingualText(
                      S.msamoRequired,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _BearingValue(
                            label: S.bearingTrue,
                            value: bearing == null
                                ? '—'
                                : Formatters.bearingWithCardinal(bearing),
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BearingValue(
                            label: S.magneticBearing,
                            value: (bearing == null || declination == null)
                                ? '—'
                                : Formatters.bearingWithCardinal(
                                    GeoMath.trueToMagnetic(
                                        bearing, declination)),
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (target != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        '${S.distance.en}: ${Formatters.distanceKm(target.distanceKm)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (locked)
                const InfoBanner(
                  message: S.lockedNote,
                  icon: Icons.lock_outline,
                  color: AppColors.gold,
                ),
              if (locked) const SizedBox(height: 12),

              AppButton(
                label: locked ? S.unlockDirection : S.lockDirection,
                icon: locked ? Icons.lock_open_outlined : Icons.lock_outline,
                variant: AppButtonVariant.outlined,
                color: AppColors.gold,
                foregroundColor: AppColors.gold,
                onPressed: bearing == null
                    ? null
                    : () {
                        if (locked) {
                          ref.read(msamoControllerProvider.notifier).unlock();
                        } else {
                          ref.read(msamoControllerProvider.notifier).lock(bearing);
                        }
                      },
                expand: true,
              ),

              if (compass.needsCalibration && compass.isRunning) ...<Widget>[
                const SizedBox(height: 12),
                const InfoBanner(
                  message: S.calibrateHint,
                  icon: Icons.screen_rotation_outlined,
                  color: AppColors.warning,
                ),
              ],
              if (compass.status == CompassStatus.noSensor) ...<Widget>[
                const SizedBox(height: 12),
                const InfoBanner(
                  message: S.noSensor,
                  icon: Icons.sensors_off_outlined,
                  color: AppColors.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The big "turn right by 32°" instruction, with a gold state when aligned.
class _TurnInstruction extends StatelessWidget {
  const _TurnInstruction({
    required this.deltaDeg,
    required this.aligned,
    required this.hasBearing,
    required this.hasHeading,
    required this.locked,
    required this.active,
    required this.onStart,
  });

  final double? deltaDeg;
  final bool aligned;
  final bool hasBearing;
  final bool hasHeading;
  final bool locked;
  final bool active;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!hasBearing) {
      return _Shell(
        color: AppColors.border,
        child: Column(
          children: <Widget>[
            BilingualText(
              S.msamoWaiting,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: S.startCompass,
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      );
    }

    if (!hasHeading) {
      return _Shell(
        color: AppColors.border,
        child: Column(
          children: <Widget>[
            BilingualText(
              S.waitingForHeading,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!active) ...<Widget>[
              const SizedBox(height: 12),
              AppButton(
                label: S.startCompass,
                icon: Icons.play_arrow_rounded,
                onPressed: onStart,
              ),
            ],
          ],
        ),
      );
    }

    final double delta = deltaDeg!;
    final int degrees = delta.abs().round();

    if (aligned) {
      return _Shell(
        color: AppColors.gold,
        fill: AppColors.gold.withValues(alpha: 0.12),
        child: Column(
          children: <Widget>[
            const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.gold, size: 34),
            const SizedBox(height: 8),
            BilingualText(
              S.msamoAligned,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final bool right = delta > 0;
    final bool around = degrees > 150;
    final Bi instruction = Bi(
      around
          ? S.turnAroundEn(degrees)
          : (right ? S.turnRightEn(degrees) : S.turnLeftEn(degrees)),
      around
          ? S.turnAroundZu(degrees)
          : (right ? S.turnRightZu(degrees) : S.turnLeftZu(degrees)),
    );

    return _Shell(
      color: AppColors.accent.withValues(alpha: 0.55),
      fill: AppColors.accent.withValues(alpha: 0.08),
      child: Column(
        children: <Widget>[
          Icon(
            around
                ? Icons.u_turn_right_rounded
                : (right ? Icons.turn_right_rounded : Icons.turn_left_rounded),
            color: AppColors.accent,
            size: 34,
          ),
          const SizedBox(height: 8),
          BilingualText(
            instruction,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          BilingualText(
            locked ? S.lockedNote : S.msamoNotAligned,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.color, required this.child, this.fill});

  final Color color;
  final Color? fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fill ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
        border: Border.all(color: color, width: 1.5),
      ),
      child: child,
    );
  }
}

class _BearingValue extends StatelessWidget {
  const _BearingValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final Bi label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BilingualText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
