import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../core/l10n/strings.dart';
import '../../core/sun/facing_sun.dart';
import '../../core/sun/sun_position.dart';
import '../../app_providers.dart';
import '../../core/perf/performance_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/location_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bilingual_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/language_scope.dart';
import '../location/location_controller.dart';
import 'compass_controller.dart';
import 'compass_providers.dart';
import 'widgets/calibration_controls.dart';
import 'widgets/compass_dial.dart';
import 'widgets/level_bubble.dart';
import 'widgets/readout_grid.dart';
import 'widgets/source_chip.dart';
import 'widgets/sun_guidance_card.dart';

/// The Compass tab: the dial, the start button and the readout grid.
class CompassScreen extends ConsumerWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final CompassState compass = ref.watch(compassControllerProvider);
    final LocationState location = ref.watch(locationControllerProvider);
    final PerfSettings perf = ref.watch(perfSettingsProvider);
    final TargetReading? target = ref.watch(targetReadingProvider);
    final double? declination = ref.watch(declinationProvider);
    final double? magneticBearing = ref.watch(magneticBearingProvider);
    final SunPosition? sun = ref.watch(sunPositionProvider).valueOrNull;

    final double? heading = compass.trueHeadingDeg ?? compass.magneticHeadingDeg;
    final bool hasTarget = target != null;
    final bool aligned = hasTarget &&
        heading != null &&
        Angles.difference(heading, target.bearingDeg) <=
            CompassDial.alignmentToleranceDeg;

    final FacingSunResult facing = sun == null
        ? const FacingSunResult(
            facing: SunFacing.unknown, deltaDeg: 0, hasHeading: false)
        : FacingSun.evaluate(headingDeg: heading, sun: sun);

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

              // Status line.
              _StatusLine(location: location, compass: compass),
              const SizedBox(height: 10),

              // Which sensor is driving the dial, and the level bubble.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(child: SourceChip(compass: compass)),
                  if (compass.hasAttitude) ...<Widget>[
                    const SizedBox(width: 12),
                    LevelBubble(
                      attitude: compass.attitude!,
                      size: 36,
                      travel: 11,
                      animate: perf.animate,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Dial (+ start button when the compass is off).
              _DialSection(
                compass: compass,
                heading: heading,
                targetBearing: target?.bearingDeg,
                aligned: aligned,
                simple: !perf.useGradients,
                onStart: () => ref
                    .read(compassControllerProvider.notifier)
                    .start(),
              ),
              const SizedBox(height: 16),

              // Stale sensor: "Move the phone to wake the compass" + retry.
              if (compass.isStale && compass.isActive) ...<Widget>[
                InfoBanner(
                  message: S.compassPaused,
                  icon: Icons.vibration_outlined,
                  color: AppColors.warning,
                  actionLabel: S.retryCompass,
                  onTap: () =>
                      ref.read(compassControllerProvider.notifier).retry(),
                ),
                const SizedBox(height: 12),
              ],

              // GPS rung: needs a few steps.
              if (compass.waitingForWalk && !compass.isStale) ...<Widget>[
                const InfoBanner(
                  message: S.walkForDirection,
                  icon: Icons.directions_walk,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
              ],

              // Relative source: one-tap calibration.
              if (compass.isActive &&
                  (compass.awaitingCalibration ||
                      compass.source ==
                          HeadingSourceKind.relativeCalibrated)) ...<Widget>[
                CalibrationControls(compass: compass),
                const SizedBox(height: 12),
              ],

              if (compass.needsCalibration && compass.isRunning) ...<Widget>[
                const InfoBanner(
                  message: S.calibrateHint,
                  icon: Icons.screen_rotation_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
              ],

              // No usable sensor (or waiting for calibration): use the sun.
              if (compass.isSunOnly || compass.awaitingCalibration) ...<Widget>[
                SunGuidanceCard(
                  sun: sun,
                  target: target,
                  declinationDeg: declination,
                  reason: compass.isSunOnly ? S.sunWhyNone : null,
                ),
                const SizedBox(height: 8),
                if (compass.isSunOnly)
                  AppButton(
                    label: S.retryCompass,
                    variant: AppButtonVariant.text,
                    icon: Icons.refresh,
                    onPressed: () =>
                        ref.read(compassControllerProvider.notifier).retry(),
                  ),
                const SizedBox(height: 8),
              ],

              if (_needsLocationHelp(location)) ...<Widget>[
                _LocationHelpBanner(location: location),
                const SizedBox(height: 12),
              ],

              if (compass.errorMessage != null) ...<Widget>[
                InfoBanner(
                  message: Bi(
                    compass.errorMessage!,
                    compass.errorMessage!,
                  ),
                  icon: Icons.error_outline,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
              ],

              // Readouts.
              ReadoutGrid(
                children: <Widget>[
                  ReadoutCard(
                    label: S.sunHeight,
                    value: sun == null
                        ? '—'
                        : '${Formatters.elevation(sun.elevationDeg)}°',
                    caption: sun == null
                        ? null
                        : (sun.isAboveHorizon
                            ? S.aboveHorizon.en
                            : S.belowHorizon.en),
                    icon: Icons.wb_sunny_outlined,
                  ),
                  ReadoutCard(
                    label: S.facingSun,
                    value: _facingSunValue(facing, sun, heading),
                    caption: _facingSunCaption(facing, sun),
                    icon: Icons.visibility_outlined,
                  ),
                  if (sun != null && sun.castsShadow)
                    ReadoutCard(
                      label: S.stickShadow,
                      value: Formatters.bearingWithCardinal(sun.shadowBearingDeg),
                      caption: S.shadowHint.en,
                      icon: Icons.north_east_outlined,
                    ),
                  ReadoutCard(
                    label: S.bearingTrue,
                    value: target == null
                        ? '—'
                        : Formatters.bearingWithCardinal(target.bearingDeg),
                    caption: target == null ? S.notSetHint.en : null,
                    valueColor: AppColors.accent,
                    icon: Icons.navigation_outlined,
                  ),
                  ReadoutCard(
                    label: S.distance,
                    value: target == null
                        ? '—'
                        : Formatters.distanceKm(target.distanceKm),
                    caption: S.ekuphumuleni.en,
                    icon: Icons.straighten_outlined,
                  ),
                  ReadoutCard(
                    label: S.magneticBearing,
                    value: magneticBearing == null
                        ? '—'
                        : Formatters.bearingWithCardinal(magneticBearing),
                    caption: magneticBearing == null ? S.notSetHint.en : null,
                    icon: Icons.explore_outlined,
                  ),
                  ReadoutCard(
                    label: S.declination,
                    value: declination == null
                        ? '—'
                        : Formatters.declination(declination),
                    caption: declination == null
                        ? S.notSetHint.en
                        : (declination < 0
                            ? 'magnetic north is west of true north'
                            : 'magnetic north is east of true north'),
                    icon: Icons.swap_horiz_outlined,
                  ),
                  ReadoutCard(
                    label: S.yourLocation,
                    value: location.hasPoint
                        ? Formatters.geoPoint(location.effectivePoint)
                        : '—',
                    caption: location.hasPoint
                        ? (location.isManual ? S.sourceManual.en : S.sourceGps.en)
                        : S.notSetHint.en,
                    icon: Icons.place_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SectionCard(
                child: BilingualText(
                  S.compassHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                ),
              ),

              if (compass.isActive) ...<Widget>[
                const SizedBox(height: 12),
                AppButton(
                  label: S.stopCompass,
                  variant: AppButtonVariant.outlined,
                  icon: Icons.stop_circle_outlined,
                  onPressed: () =>
                      ref.read(compassControllerProvider.notifier).stop(),
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _needsLocationHelp(LocationState location) {
    if (location.hasPoint) {
      return false;
    }
    return location.access == LocationAccess.denied ||
        location.access == LocationAccess.deniedForever ||
        location.access == LocationAccess.serviceDisabled;
  }

  String _facingSunValue(
      FacingSunResult facing, SunPosition? sun, double? heading) {
    if (sun == null) {
      return '—';
    }
    if (!facing.hasHeading) {
      return '—';
    }
    switch (facing.facing) {
      case SunFacing.ahead:
        return 'Yes · Yebo';
      case SunFacing.behind:
        return 'No · Cha';
      case SunFacing.right:
      case SunFacing.left:
        return Formatters.bearingWithCardinal(sun.azimuthDeg);
      case SunFacing.unknown:
        return '—';
    }
  }

  String _facingSunCaption(FacingSunResult facing, SunPosition? sun) {
    if (sun == null) {
      return S.notSetHint.en;
    }
    if (!facing.hasHeading) {
      return S.sunUnknown.en;
    }
    switch (facing.facing) {
      case SunFacing.ahead:
        return S.yesFacingSun.en;
      case SunFacing.behind:
        return S.sunBehind.en;
      case SunFacing.right:
        return '${S.noFacingSun.en} · ${facing.turnDeg.round()}° ${S.right.en}';
      case SunFacing.left:
        return '${S.noFacingSun.en} · ${facing.turnDeg.round()}° ${S.left.en}';
      case SunFacing.unknown:
        return S.sunUnknown.en;
    }
  }
}

/// "Location: not set · Compass: off", switching to live values as soon as the
/// compass is running.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.location, required this.compass});

  final LocationState location;
  final CompassState compass;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GeoPoint? point = location.effectivePoint;

    final Bi locationText = point == null
        ? S.locationNotSet
        : Bi(
            'Location: ${Formatters.geoPoint(point)}',
            'Indawo: ${Formatters.geoPoint(point)}',
          );

    final Bi compassText = switch (compass.status) {
      CompassStatus.off => S.compassOff,
      CompassStatus.starting => S.compassWaiting,
      CompassStatus.noSensor => S.compassNone,
      CompassStatus.locationRequired =>
        const Bi('Compass: needs location', 'Ikhompasi: idinga indawo'),
      CompassStatus.error =>
        const Bi('Compass: error', 'Ikhompasi: iphutha'),
      CompassStatus.running when compass.awaitingCalibration =>
        S.compassNeedsCal,
      CompassStatus.running when !compass.hasHeading => S.compassWaiting,
      CompassStatus.running => compass.trueHeadingDeg != null
          ? Bi(
              'Compass: ${Formatters.bearing(compass.trueHeadingDeg)} true',
              'Ikhompasi: ${Formatters.bearing(compass.trueHeadingDeg)} iqiniso',
            )
          : Bi(
              'Compass: ${Formatters.bearing(compass.magneticHeadingDeg)} magnetic',
              'Ikhompasi: ${Formatters.bearing(compass.magneticHeadingDeg)} kazibuthe',
            ),
    };

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            locationText.inline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            compassText.inline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dial, with the start button centred on it while the compass is off.
class _DialSection extends StatelessWidget {
  const _DialSection({
    required this.compass,
    required this.heading,
    required this.targetBearing,
    required this.aligned,
    required this.onStart,
    this.simple = false,
  });

  final CompassState compass;
  final double? heading;
  final double? targetBearing;
  final bool aligned;
  final VoidCallback onStart;
  final bool simple;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool active = compass.isRunning;

    return Column(
      children: <Widget>[
        SizedBox(
          height: 300,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CompassDial(
                  headingDeg: heading,
                  targetBearingDeg: targetBearing,
                  aligned: aligned,
                  active: active,
                  simple: simple,
                  size: 288,
                ),
                if (!compass.isActive) ...<Widget>[
                  Container(
                    width: 288,
                    height: 288,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background.withValues(alpha: 0.55),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      BilingualText(
                        S.startToBegin,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 190,
                        child: AppButton(
                          label: S.startCompass,
                          icon: Icons.play_arrow_rounded,
                          onPressed: onStart,
                          expand: true,
                        ),
                      ),
                    ],
                  ),
                ] else if (compass.status == CompassStatus.starting ||
                    compass.paused) ...<Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 10),
                      BilingualText(
                        S.waitingForHeading,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        BilingualText(
          aligned
              ? S.aligned
              : (targetBearing == null
                  ? S.notSetHint
                  : Bi(
                      'Bearing ${Formatters.bearingWithCardinal(targetBearing)}',
                      'Ukubheka ${Formatters.bearingWithCardinal(targetBearing)}',
                    )),
          style: theme.textTheme.titleSmall?.copyWith(
            color: aligned ? AppColors.gold : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Explains — and offers to fix — whatever is blocking location.
class _LocationHelpBanner extends ConsumerWidget {
  const _LocationHelpBanner({required this.location});

  final LocationState location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Bi message = switch (location.access) {
      LocationAccess.serviceDisabled => S.locationServicesOff,
      LocationAccess.deniedForever => S.permissionDeniedForever,
      LocationAccess.denied => S.permissionDenied,
      _ => S.permissionNeeded,
    };

    return InfoBanner(
      message: message,
      icon: Icons.location_off_outlined,
      color: AppColors.warning,
      actionLabel: S.openSettings,
      onTap: () =>
          ref.read(locationControllerProvider.notifier).openSettings(),
    );
  }
}
