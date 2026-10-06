import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../membership_controller.dart';
import '../membership_models.dart';
import '../widgets/auth_scaffold.dart';
import 'trial_intro_screen.dart';

/// Shown when the server says there is no access: the trial is over, the
/// membership expired, or the three days of grace after a missed payment
/// have run out.
///
/// The server decides; this screen only mirrors it.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.storeBuild = kStoreBuild});

  /// Overridable for tests; the app always uses [kStoreBuild].
  final bool storeBuild;

  static const Key payKey = Key('paywall.pay');
  static const Key retryKey = Key('paywall.retry');
  static const Key logOutKey = Key('paywall.logOut');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c =
        ref.read(membershipControllerProvider.notifier);
    final Entitlement? e = m.entitlement;
    final String price = e?.priceLabel ?? 'R100';

    return AuthScaffold(
      children: <Widget>[
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthHeading(S.paywallTitle),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LocalizedText(
                      _reason(e),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (m.email.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  m.email,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
              if (e?.state == EntitlementState.grace) ...<Widget>[
                const SizedBox(height: 10),
                const AuthNote(S.payGraceNote),
              ],
              const SizedBox(height: 14),
              if (storeBuild)
                const AuthNote(S.payStore)
              else ...<Widget>[
                AuthNote(S.payOffer(price)),
                const SizedBox(height: 10),
                AppButton(
                  key: PaywallScreen.payKey,
                  label: S.payNow,
                  icon: Icons.credit_card_outlined,
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
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      key: PaywallScreen.retryKey,
                      label: S.retry,
                      icon: Icons.refresh,
                      variant: AppButtonVariant.outlined,
                      onPressed:
                          m.busy ? null : () => c.refreshEntitlement(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    key: PaywallScreen.logOutKey,
                    label: S.logOut,
                    variant: AppButtonVariant.text,
                    onPressed: m.busy ? null : c.signOut,
                  ),
                ],
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
      ],
    );
  }

  static Bi _reason(Entitlement? e) {
    switch (e?.state) {
      case EntitlementState.trial:
        return S.trialEnded;
      case EntitlementState.grace:
        return S.payPastDue;
      case EntitlementState.cancelled:
      case EntitlementState.expired:
      case EntitlementState.active:
        return S.payExpired;
      case EntitlementState.other:
      case null:
        return S.payNone;
    }
  }
}

/// Signed in, offline, and the cached entitlement cannot vouch for the
/// member. Not a paywall: nothing is known, so nothing is claimed.
class OfflineLockedScreen extends ConsumerWidget {
  const OfflineLockedScreen({super.key});

  static const Key retryKey = Key('offline.retry');
  static const Key logOutKey = Key('offline.logOut');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c =
        ref.read(membershipControllerProvider.notifier);

    return AuthScaffold(
      children: <Widget>[
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthHeading(S.offlineTitle),
              const SizedBox(height: 12),
              LocalizedText(
                S.payOffline,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              if (m.email.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  m.email,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      key: OfflineLockedScreen.retryKey,
                      label: S.retry,
                      icon: Icons.refresh,
                      variant: AppButtonVariant.outlined,
                      onPressed:
                          m.busy ? null : () => c.refreshEntitlement(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    key: OfflineLockedScreen.logOutKey,
                    label: S.logOut,
                    variant: AppButtonVariant.text,
                    onPressed: m.busy ? null : c.signOut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
