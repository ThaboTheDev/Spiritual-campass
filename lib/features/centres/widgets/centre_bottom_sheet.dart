import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/geo/coordinates.dart';
import '../../../core/geo/geo_math.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/centre.dart';
import '../../../services/navigation_launcher.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/bilingual_text.dart';

/// Shows a centre's details after a map pin is tapped.
Future<void> showCentreSheet({
  required BuildContext context,
  required Centre centre,
  GeoPoint? userPoint,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: false,
    builder: (BuildContext context) => _CentreSheet(
      centre: centre,
      userPoint: userPoint,
    ),
  );
}

class _CentreSheet extends StatelessWidget {
  const _CentreSheet({required this.centre, this.userPoint});

  final Centre centre;
  final GeoPoint? userPoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? distanceKm = (userPoint != null && centre.hasCoordinates)
        ? GeoMath.distanceBetweenKm(userPoint!, centre.point!)
        : null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    centre.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    centre.region,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (centre.hasAddress)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.place_outlined,
                        size: 16, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      centre.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            if (centre.hasPhone) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.call_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      centre.phone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (distanceKm != null) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Icon(Icons.straighten_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.distanceKm(distanceKm),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: S.directionsButton,
                    icon: Icons.directions_outlined,
                    onPressed: centre.hasCoordinates
                        ? () => NavigationLauncher.openDirections(
                              latitude: centre.lat!,
                              longitude: centre.lng!,
                              label: centre.hasAddress
                                  ? centre.address
                                  : centre.name,
                            )
                        : null,
                    expand: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: S.callButton,
                    icon: Icons.call_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: centre.hasPhone
                        ? () => NavigationLauncher.call(centre.phone)
                        : null,
                    expand: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BilingualText(
              S.mapCaption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
