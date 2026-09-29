import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';

/// How an [AppButton] is styled.
enum AppButtonVariant {
  /// Solid accent button (the main action on a screen).
  filled,

  /// Outlined button on the card surface.
  outlined,

  /// Text-only button.
  text,
}

/// A button with a bilingual label: English on top, isiZulu underneath.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.expand = false,
    this.color,
    this.foregroundColor,
    this.semanticLabel,
  });

  /// Bilingual label.
  final Bi label;

  /// Tap handler; when `null` the button is disabled automatically.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Visual style.
  final AppButtonVariant variant;

  /// Whether to fill the available width.
  final bool expand;

  /// Overrides the background (filled) or foreground (others) colour.
  final Color? color;

  /// Overrides the text colour.
  final Color? foregroundColor;

  /// Overrides the spoken label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final Color accent = color ?? AppColors.accent;
    final Color textColor = foregroundColor ??
        (variant == AppButtonVariant.filled
            ? const Color(0xFF08101F)
            : AppColors.textPrimary);

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: enabled ? textColor : AppColors.textMuted),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  label.en,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: enabled ? textColor : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  label.zu,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: enabled
                        ? textColor.withValues(alpha: 0.72)
                        : AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final ButtonStyle style = switch (variant) {
      AppButtonVariant.filled => ElevatedButton.styleFrom(
          backgroundColor: enabled ? accent : AppColors.surfaceAlt,
          foregroundColor: textColor,
          elevation: 0,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      AppButtonVariant.outlined => OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? textColor,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: BorderSide(
            color: enabled ? accent.withValues(alpha: 0.55) : AppColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      AppButtonVariant.text => TextButton.styleFrom(
          foregroundColor: foregroundColor ?? accent,
          minimumSize: const Size(0, AppLayout.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
    };

    final Widget button = switch (variant) {
      AppButtonVariant.filled => ElevatedButton(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: onPressed,
          style: style,
          child: content,
        ),
    };

    final Widget sized = expand
        ? SizedBox(width: double.infinity, child: button)
        : button;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? '${label.en}. ${label.zu}',
      child: sized,
    );
  }
}
