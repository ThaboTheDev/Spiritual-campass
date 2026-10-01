import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../membership_controller.dart';
import '../membership_models.dart';
import '../screens/account_screen.dart';

/// The Guide tab's way into the account.
///
/// Since the whole app sits behind the gate, there is nothing to sign in to
/// here any more: the card shows who is signed in and how long the
/// membership runs, and opens [AccountScreen] for everything else.
class MembershipCard extends ConsumerWidget {
  const MembershipCard({super.key});

  static const Key cardKey = Key('guide.membershipCard');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final Entitlement? e = m.entitlement;
    if (!m.isSignedIn) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      key: cardKey,
      onTap: () => AccountScreen.open(context),
      semanticLabel: S.accountOpen.text,
      child: Row(
        children: <Widget>[
          const Icon(Icons.card_membership_outlined, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LocalizedText(
                  S.membershipTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  m.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                if (e != null) ...<Widget>[
                  const SizedBox(height: 2),
                  LocalizedText(
                    _summary(e, access: m.hasAccess),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: m.hasAccess
                          ? AppColors.textMuted
                          : AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  static Bi _summary(Entitlement e, {required bool access}) {
    if (!access) {
      return S.payExpired;
    }
    switch (e.state) {
      case EntitlementState.trial:
        return S.trialLeft(e.daysLeft());
      case EntitlementState.grace:
        return S.payPastDue;
      case EntitlementState.cancelled:
        final DateTime? end = e.endsAt;
        if (end != null) {
          final DateTime l = end.toLocal();
          String two(int v) => v.toString().padLeft(2, '0');
          return S.payCancelledUntil('${l.year}-${two(l.month)}-${two(l.day)}');
        }
        return S.payActive;
      case EntitlementState.active:
      case EntitlementState.expired:
      case EntitlementState.other:
        return S.payActive;
    }
  }
}
