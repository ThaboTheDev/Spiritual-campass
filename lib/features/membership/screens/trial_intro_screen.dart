import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../../../widgets/nine_pointed_star.dart';
import '../membership_controller.dart';
import '../membership_models.dart';
import '../widgets/auth_scaffold.dart';

/// Shown once per account, right after the first login of a free trial:
/// what the trial includes, how long is left, and (outside store builds)
/// the chance to pay for the month straight away.
class TrialIntroScreen extends ConsumerWidget {
  const TrialIntroScreen({super.key, this.storeBuild = kStoreBuild});

  /// Overridable so the "no purchase controls in a store build" rule can be
  /// tested; in the app it is always the compile-time [kStoreBuild].
  final bool storeBuild;

  static const Key startKey = Key('trial.start');
  static const Key payKey = Key('trial.pay');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c =
        ref.read(membershipControllerProvider.notifier);
    final Entitlement? e = m.entitlement;
    final int trialDays = e?.trialDays ?? 7;
    final int daysLeft = e?.daysLeft() ?? trialDays;

    return AuthScaffold(
      children: <Widget>[
        SectionCard(
          borderColor: AppColors.gold.withValues(alpha: 0.55),
          borderWidth: 1.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const NinePointedStar(size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.trialTitle(trialDays).text,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LocalizedText(
                S.trialLeft(daysLeft),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AuthHeading(S.trialWhat),
              SizedBox(height: 12),
              FeatureList(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          key: TrialIntroScreen.startKey,
          label: S.trialStart,
          icon: Icons.explore_outlined,
          onPressed: m.busy ? null : c.acknowledgeTrialIntro,
          expand: true,
        ),
        if (!storeBuild) ...<Widget>[
          const SizedBox(height: 12),
          AuthNote(S.trialOffer(trialDays, e?.priceLabel ?? 'R100')),
          const SizedBox(height: 8),
          AppButton(
            key: TrialIntroScreen.payKey,
            label: S.payNow,
            icon: Icons.credit_card_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: m.busy ? null : c.startCheckout,
            expand: true,
          ),
        ],
        if (m.awaitingPayment) ...<Widget>[
          const SizedBox(height: 12),
          const InfoBanner(
            message: S.paySlow,
            icon: Icons.hourglass_bottom,
            color: AppColors.warning,
          ),
        ],
        MembershipErrorBanner(error: m.error, onDismiss: c.dismissError),
      ],
    );
  }
}

/// The five things a membership includes, shown on the trial page and the
/// paywall.
class FeatureList extends StatelessWidget {
  const FeatureList({super.key});

  static const List<Bi> features = <Bi>[
    S.featCompass,
    S.featMsamo,
    S.featSun,
    S.featCentres,
    S.featLanguages,
  ];

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Bi feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    feature,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
