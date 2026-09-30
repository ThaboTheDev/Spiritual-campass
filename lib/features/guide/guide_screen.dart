import 'package:flutter/material.dart';

import '../../core/geo/coordinates.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bilingual_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/language_scope.dart';
import '../../widgets/nine_pointed_star.dart';
import '../membership/widgets/membership_card.dart';
import '../settings/widgets/settings_card.dart';

/// The Guide tab: what the app is for, how to use it, and how accurate it is.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);

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

              // Coordinates, framed in gold.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppLayout.cardRadius),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const NinePointedStar(
                          size: 16,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${S.ekuphumuleni.en} · ${S.spiritualCapital.en}',
                            style: AppText.sectionHeader.copyWith(
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _CoordinateRow(
                      label: S.dmsLabel,
                      value: Ekuphumuleni.dms,
                    ),
                    const SizedBox(height: 8),
                    const _CoordinateRow(
                      label: S.decimalLabel,
                      value: Ekuphumuleni.decimal,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Ekuphumuleni.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const _Heading(text: S.purposeHeading),
              const SizedBox(height: 10),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BilingualText(
                      S.purposeBody,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    BilingualText(
                      S.purposeBody2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const _Heading(text: S.howToUse),
              const SizedBox(height: 10),
              const SectionCard(
                child: Column(
                  children: <Widget>[
                    _NumberedStep(index: 1, text: S.step1),
                    _StepDivider(),
                    _NumberedStep(index: 2, text: S.step2),
                    _StepDivider(),
                    _NumberedStep(index: 3, text: S.step3),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const _Heading(text: S.accuracyHeading),
              const SizedBox(height: 10),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BilingualText(
                      S.accuracyBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.55,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BilingualText(
                      S.permissionsNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.55,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const _Heading(text: S.aboutHeading),
              const SizedBox(height: 10),
              SectionCard(
                child: BilingualText(
                  S.aboutBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.55,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Crest.
              Center(
                child: Semantics(
                  label: 'The Revelation Spiritual Home crest',
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 132,
                      height: 132,
                      fit: BoxFit.cover,
                      cacheWidth:
                          (132 * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) =>
                          Container(
                        width: 132,
                        height: 132,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              AppColors.accent,
                              AppColors.background,
                            ],
                          ),
                        ),
                        child: const Icon(Icons.explore_outlined,
                            size: 56, color: AppColors.gold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SettingsCard(),
              const SizedBox(height: 16),
              const MembershipCard(),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  S.crestCaption,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final Bi text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        '${text.en.toUpperCase()} · ${text.secondary.toUpperCase()}',
        style: AppText.sectionHeader.copyWith(color: AppColors.accent),
      ),
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({required this.label, required this.value});

  final Bi label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BilingualText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppText.mono(
            fontSize: 14.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// One of the three "how to use it" steps, with a circular numbered badge.
class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.index, required this.text});

  final int index;
  final Bi text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentDim,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55),
            ),
          ),
          child: Center(
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BilingualText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1),
      );
}
