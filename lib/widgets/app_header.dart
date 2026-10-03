import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/widgets/language_button.dart';
import 'language_scope.dart';

/// The header shown at the top of every screen: eyebrow, serif title, the
/// language button and the round blue-and-gold crest.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.logoSize = 46,
    this.showLogo = true,
    this.showLanguageButton = true,
    this.title = S.appTitle,
  });

  /// Size of the crest.
  final double logoSize;

  /// Whether to show the crest (it is hidden on the Guide screen, which ends
  /// with the large crest instead).
  final bool showLogo;

  /// Whether to show the language control. It is on by default so the choice
  /// is reachable from every screen, the gate's included.
  final bool showLanguageButton;

  /// Title text; only the Guide screen overrides it.
  final String title;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  S.eyebrow.text.toUpperCase(),
                  style: AppText.eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showLanguageButton) ...<Widget>[
            const SizedBox(width: 10),
            const LanguageButton(),
          ],
          if (showLogo) ...<Widget>[
            const SizedBox(width: 12),
            Semantics(
              label: S.crestLabel.text,
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                  // Decode at display size: keeps the image cache small.
                  cacheWidth: (logoSize *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) =>
                      Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[AppColors.accent, AppColors.background],
                      ),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
