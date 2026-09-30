import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import 'bilingual_text.dart';

/// A rounded card with a 1px border on the app's slightly lighter navy.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.semanticLabel,
  });

  /// Card contents.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Background colour; defaults to the card surface.
  final Color? color;

  /// Border colour; defaults to [AppColors.border] (or gold for highlights).
  final Color? borderColor;

  /// Border width in logical pixels.
  final double borderWidth;

  /// Optional tap handler; when set the card gets an ink well.
  final VoidCallback? onTap;

  /// Optional label for accessibility tools.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(AppLayout.cardRadius);
    final Widget card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, container: true, child: card);
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      container: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: card,
        ),
      ),
    );
  }
}

/// One readout: bilingual label, a value, and an optional caption.
///
/// Used for the compass grid (bearing, distance, declination, …).
class ReadoutCard extends StatelessWidget {
  const ReadoutCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.valueStyle,
    this.icon,
    this.alignment = CrossAxisAlignment.start,
  });

  /// Bilingual label above the value.
  final Bi label;

  /// The formatted value, e.g. "318° NW".
  final String value;

  /// Optional extra line under the value, e.g. the isiZulu for a value.
  final String? caption;

  /// Colour of the value text; defaults to primary text.
  final Color? valueColor;

  /// Full style override for the value.
  final TextStyle? valueStyle;

  /// Optional leading icon.
  final IconData? icon;

  /// Alignment of the contents.
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      semanticLabel: '${label.en}. ${label.secondary}. $value',
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(height: 6),
          ],
          BilingualText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: valueStyle ??
                theme.textTheme.headlineSmall?.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A short note with an icon, used for calibration hints, permission problems
/// and offline messages.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
    this.actionLabel,
  });

  /// The bilingual message.
  final Bi message;

  /// Leading icon; defaults to an information outline.
  final IconData? icon;

  /// Accent colour for the icon and border.
  final Color? color;

  /// Background colour; defaults to a tinted version of [color].
  final Color? backgroundColor;

  /// Tap handler for the whole banner.
  final VoidCallback? onTap;

  /// Optional action label shown at the end of the banner.
  final Bi? actionLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? AppColors.accent;
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon ?? Icons.info_outline_rounded,
              size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BilingualText(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(width: 8),
          BilingualInline(
            actionLabel!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
          ),
        ],
      ],
    );

    return SectionCard(
      padding: const EdgeInsets.all(12),
      color: backgroundColor ?? accent.withValues(alpha: 0.08),
      borderColor: accent.withValues(alpha: 0.35),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppLayout.cardRadius),
              child: content,
            ),
    );
  }
}

/// Uppercase, letter-spaced section header with an optional count, e.g.
/// "GAUTENG · 20".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.color,
  });

  /// Header text (already uppercase in most cases).
  final String title;

  /// Optional count appended after a middot.
  final int? count;

  /// Colour override.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final String text = count == null ? title : '$title · $count';
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: AppText.sectionHeader.copyWith(color: color),
      ),
    );
  }
}
