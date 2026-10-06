import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/perf/performance_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../language_controller.dart';

/// Language switcher and the "Battery saver / Simple mode" switch.
///
/// Lives on the Guide tab so it needs no extra navigation. The same language
/// choice is also one tap away in the header's `LanguageButton`, which is the
/// one a member can reach before logging in.
class SettingsCard extends ConsumerWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final AppLanguage language = ref.watch(languageProvider);
    final bool simpleForced = ref.watch(simpleModeProvider);
    final DeviceClass device = ref.watch(deviceClassProvider);
    final bool autoLow = device.suggestedProfile == PerformanceProfile.low;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              S.settingsHeading.text.toUpperCase(),
              style: AppText.sectionHeader.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),

          // Language.
          LocalizedText(S.language, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          LocalizedText(
            S.languageNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final AppLanguage option in AppLanguage.values)
                ChoiceChip(
                  label: Text(option.nativeName),
                  selected: option == language,
                  onSelected: (bool selected) {
                    if (selected) {
                      ref.read(languageProvider.notifier).set(option);
                    }
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: option == language
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: option == language
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                  backgroundColor: AppColors.surfaceAlt,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Simple mode.
          // The tile needs its own Material: SectionCard paints its
          // background on a DecoratedBox that would otherwise sit between
          // the ListTile and the nearest Material, hiding the ink splash
          // (debug builds assert on this).
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: simpleForced,
              onChanged: (bool value) =>
                  ref.read(simpleModeProvider.notifier).set(value),
              activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
              title: LocalizedText(
                S.batterySaver,
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LocalizedText(
                  S.batterySaverNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          if (autoLow && !simpleForced)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LocalizedText(
                S.simpleModeAuto,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
