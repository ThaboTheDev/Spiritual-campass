import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../language_controller.dart';

/// The language control that sits in `AppHeader`, so it is on screen from the
/// very first frame — including on the log in / paywall screens the gate shows
/// before the app itself.
///
/// It shows the code of the language in use (`EN`, `ZU`, `PT`, `NY`, `BEM`)
/// next to a globe, and opens [LanguageSheet] for the choice. The full
/// switcher still lives on the Guide tab (`SettingsCard`).
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  /// Key the widget tests tap.
  static const Key buttonKey = Key('header.language');

  /// Opens the language sheet.
  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        builder: (BuildContext sheetContext) => const LanguageSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final AppLanguage language = ref.watch(languageProvider);

    return Semantics(
      button: true,
      label: '${S.language.text}: ${language.nativeName}',
      // The pill paints its own Material so the ink splash is not hidden
      // behind its background (the same trap `SettingsCard` documents).
      child: Material(
        key: buttonKey,
        color: AppColors.surfaceAlt,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          onTap: () => open(context),
          customBorder: const StadiumBorder(),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.language,
                  size: 17,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  language.code.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The body of [LanguageButton.open]: the five languages, the active one
/// marked, and the choice applied (and persisted) as soon as it is tapped.
class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  /// Key of the sheet itself.
  static const Key sheetKey = Key('language.sheet');

  /// Key of one language row.
  static Key optionKey(AppLanguage language) =>
      Key('language.option.${language.code}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = ref.watch(languageProvider);

    // `showModalBottomSheet(useSafeArea: true)` already keeps the sheet clear
    // of the system bars, and `SingleChildScrollView` prevents a bottom
    // overflow on short screens or large text scales.
    return SingleChildScrollView(
      child: Column(
        key: sheetKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: LocalizedText(
                    S.language,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: S.close.text,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: LocalizedText(
              S.languageNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final AppLanguage option in AppLanguage.values)
            _LanguageRow(
              language: option,
              selected: option == language,
              onTap: () async {
                await ref.read(languageProvider.notifier).set(option);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// One row of [LanguageSheet]: the language's own name, ticked when active.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      key: LanguageSheet.optionKey(language),
      button: true,
      selected: selected,
      label: language.nativeName,
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.gold,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
