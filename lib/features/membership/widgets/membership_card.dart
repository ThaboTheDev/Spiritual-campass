import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/localized_text.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../membership_controller.dart';
import '../membership_models.dart';

/// Sign-in, membership status and (outside store builds) subscribe / cancel.
/// Renders nothing when [kMembershipEnabled] is `false`.
class MembershipCard extends ConsumerStatefulWidget {
  const MembershipCard({super.key});

  @override
  ConsumerState<MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends ConsumerState<MembershipCard>
    with WidgetsBindingObserver {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Back from the PayFast browser: confirm server-side via /api/me.
    if (lifecycle == AppLifecycleState.resumed &&
        kMembershipEnabled &&
        ref.read(membershipControllerProvider).awaitingPayment) {
      ref
          .read(membershipControllerProvider.notifier)
          .refreshEntitlement(afterPayment: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kMembershipEnabled) {
      return const SizedBox.shrink();
    }
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c = ref.read(membershipControllerProvider.notifier);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              S.membershipTitle.text.toUpperCase(),
              style: AppText.sectionHeader.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          ..._body(context, theme, m, c),
          if (_errorText(m.error) case final Bi message) ...<Widget>[
            const SizedBox(height: 10),
            InfoBanner(
              message: message,
              icon: Icons.error_outline,
              color: m.error == MembershipError.offline
                  ? AppColors.warning
                  : AppColors.danger,
              actionLabel: S.close,
              onTap: c.dismissError,
            ),
          ],
          if (m.cancelledNotice) ...<Widget>[
            const SizedBox(height: 10),
            InfoBanner(
              message: S.payCancelDone,
              icon: Icons.check_circle_outline,
              color: AppColors.gold,
              actionLabel: S.close,
              onTap: c.dismissError,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    ThemeData theme,
    MembershipState m,
    MembershipController c,
  ) {
    final TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 12,
    );

    switch (m.phase) {
      case MembershipPhase.idle:
        return const <Widget>[];

      case MembershipPhase.signedOut:
        return <Widget>[
          LocalizedText(S.authTitle, style: theme.textTheme.titleSmall),
          if (kStoreBuild) ...<Widget>[
            const SizedBox(height: 4),
            LocalizedText(S.payStore, style: note),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            enabled: !m.busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: S.authEmail.text, isDense: true),
            onSubmitted: (_) => c.sendCode(_email.text),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: S.authSend,
            icon: Icons.send_outlined,
            onPressed: m.busy ? null : () => c.sendCode(_email.text),
            expand: true,
          ),
        ];

      case MembershipPhase.codeSent:
        return <Widget>[
          LocalizedText(S.authCheck, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          LocalizedText(S.authCode(m.email), style: note),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            enabled: !m.busy,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              color: AppColors.textPrimary,
              letterSpacing: 4,
              fontSize: 18,
            ),
            decoration:
                InputDecoration(labelText: S.authCodeLabel.text, isDense: true),
            onSubmitted: (_) => c.verifyCode(_code.text),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: S.authVerify,
            icon: Icons.login_outlined,
            onPressed: m.busy ? null : () => c.verifyCode(_code.text),
            expand: true,
          ),
          AppButton(
            label: S.authChange,
            variant: AppButtonVariant.text,
            onPressed: m.busy ? null : c.changeEmail,
          ),
        ];

      case MembershipPhase.checking:
        return <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LocalizedText(
                  m.awaitingPayment ? S.payConfirming : S.payChecking,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LocalizedText(S.payWait, style: note),
        ];

      case MembershipPhase.offline:
        return <Widget>[
          Text(m.email, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          LocalizedText(S.payOffline, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: S.retry,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.outlined,
                  onPressed: m.busy ? null : () => c.refreshEntitlement(),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: S.signOut,
                variant: AppButtonVariant.text,
                onPressed: m.busy ? null : c.signOut,
              ),
            ],
          ),
        ];

      case MembershipPhase.ready:
        final Entitlement e = m.entitlement!;
        final bool access = m.hasAccess;
        final Bi statusText = _statusText(e, access: access);
        return <Widget>[
          Text(
            m.email,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                access ? Icons.verified_outlined : Icons.info_outline,
                size: 18,
                color: access ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (m.fromCache) ...<Widget>[
            const SizedBox(height: 4),
            LocalizedText(S.membershipCachedNote, style: note),
          ],
          if (m.awaitingPayment) ...<Widget>[
            const SizedBox(height: 8),
            LocalizedText(S.paySlow, style: note),
          ],
          const SizedBox(height: 10),
          if (!kStoreBuild && !access) ...<Widget>[
            LocalizedText(
              e.state == EntitlementState.trial
                  ? S.trialOffer(e.trialDays, e.priceLabel)
                  : S.payOffer(e.priceLabel),
              style: note,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: S.payButton(e.priceLabel),
              icon: Icons.credit_card_outlined,
              onPressed: m.busy ? null : c.startCheckout,
              expand: true,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: S.retry,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.outlined,
                  onPressed: m.busy ? null : () => c.refreshEntitlement(),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: S.signOut,
                variant: AppButtonVariant.text,
                onPressed: m.busy ? null : c.signOut,
              ),
            ],
          ),
          if (!kStoreBuild && e.canCancel) ...<Widget>[
            const SizedBox(height: 4),
            AppButton(
              label: m.confirmingCancel ? S.payCancelConfirm : S.payCancel,
              variant: AppButtonVariant.text,
              color: AppColors.danger,
              foregroundColor: AppColors.danger,
              onPressed: m.busy ? null : c.cancelSubscription,
            ),
          ],
        ];
    }
  }

  static Bi _statusText(Entitlement e, {required bool access}) {
    switch (e.state) {
      case EntitlementState.trial:
        return access ? S.trialLeft(e.daysLeft()) : S.trialEnded;
      case EntitlementState.active:
        return access ? S.payActive : S.payExpired;
      case EntitlementState.grace:
        return S.payPastDue;
      case EntitlementState.cancelled:
        final DateTime? end = e.endsAt;
        return (access && end != null)
            ? S.payCancelledUntil(_date(end))
            : S.payExpired;
      case EntitlementState.expired:
        return S.payExpired;
      case EntitlementState.other:
        return access ? S.payActive : S.payNone;
    }
  }

  static String _date(DateTime d) {
    final DateTime l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  /// The message for [error], or `null` when there is none.
  static Bi? _errorText(MembershipError error) {
    switch (error) {
      case MembershipError.none:
        return null;
      case MembershipError.badEmail:
        return S.authBadEmail;
      case MembershipError.sendFailed:
        return S.authSendFail;
      case MembershipError.badCode:
        return S.authBadCode;
      case MembershipError.wrongCode:
        return S.authWrongCode;
      case MembershipError.offline:
        return S.payOffline;
      case MembershipError.checkoutFailed:
      case MembershipError.openFailed:
        return S.payOpenFail;
      case MembershipError.alreadySubscribed:
        return S.payActive;
      case MembershipError.cancelFailed:
        return S.payCancelFail;
    }
  }
}
