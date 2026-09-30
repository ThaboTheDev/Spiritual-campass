import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/centre.dart';
import '../../../services/navigation_launcher.dart';
import '../../../widgets/localized_text.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';

/// One centre in the grouped list: name, address, phone and the three actions.
class CentreCard extends StatelessWidget {
  const CentreCard({
    super.key,
    required this.centre,
    this.distanceKm,
    this.onShowOnMap,
    this.highlighted = false,
  });

  /// The centre to show.
  final Centre centre;

  /// Distance from the user, when known.
  final double? distanceKm;

  /// Called by the "Map" button: focus this centre on the map and scroll up.
  final VoidCallback? onShowOnMap;

  /// Whether this card is the one currently focused on the map.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      borderColor: highlighted ? AppColors.accent.withValues(alpha: 0.6) : null,
      color: highlighted ? AppColors.surfaceAlt : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  centre.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
              ),
              if (distanceKm != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} km',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            centre.hasAddress ? centre.address : S.noAddress.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: centre.hasAddress
                  ? AppColors.textSecondary
                  : AppColors.textMuted,
              fontSize: 12.5,
            ),
          ),
          if (centre.hasPhone) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              centre.phone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  label: S.mapButton,
                  icon: Icons.map_outlined,
                  enabled: centre.hasCoordinates && onShowOnMap != null,
                  onTap: onShowOnMap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: S.callButton,
                  icon: Icons.call_outlined,
                  enabled: centre.hasPhone,
                  onTap: () => NavigationLauncher.call(centre.phone),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: S.directionsButton,
                  icon: Icons.directions_outlined,
                  enabled: centre.hasCoordinates,
                  onTap: () => NavigationLauncher.openDirections(
                    latitude: centre.lat!,
                    longitude: centre.lng!,
                    label: centre.hasAddress ? centre.address : centre.name,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  final Bi label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final Color foreground =
        enabled ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label.text,
      child: Material(
        color: AppColors.surfaceAlt.withValues(alpha: enabled ? 1 : 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: AppLayout.minTapTarget,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 17, color: foreground),
                const SizedBox(height: 2),
                LocalizedText(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
