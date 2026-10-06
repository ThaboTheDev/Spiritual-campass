import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/constrained_content.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../admin/admin_screen.dart';
import '../membership_controller.dart';
import '../membership_models.dart';
import '../widgets/auth_scaffold.dart';

/// Account and membership: who is signed in, what the server says, cancel,
/// change password, log out — and the way into the admin area.
///
/// Pushed from the Guide tab, where the membership card used to be.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.storeBuild = kStoreBuild});

  /// Overridable for tests; the app always uses [kStoreBuild].
  final bool storeBuild;

  static const Key adminEntryKey = Key('account.admin');
  static const Key cancelKey = Key('account.cancel');
  static const Key manageStoreKey = Key('account.manageStore');
  static const Key restoreStoreKey = Key('account.restoreStore');
  static const Key logOutKey = Key('account.logOut');
  static const Key changePasswordKey = Key('account.changePassword');

  /// Opens the screen as a full route.
  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _changing = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c = ref.read(
      membershipControllerProvider.notifier,
    );
    final Entitlement? e = m.entitlement;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(S.accountOpen.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const AuthHeading(S.membershipTitle),
                      const SizedBox(height: 12),
                      _Row(label: S.accountSignedInAs, value: m.email),
                      const SizedBox(height: 10),
                      _Row(
                        label: S.accountStatusLabel,
                        value: _statusText(e, access: m.hasAccess).text,
                        valueColor: m.hasAccess
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      if (e?.endsAt != null) ...<Widget>[
                        const SizedBox(height: 10),
                        LocalizedText(
                          S.accountUntil(_date(e!.endsAt!)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (m.fromCache) ...<Widget>[
                        const SizedBox(height: 8),
                        const AuthNote(S.membershipCachedNote),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton(
                              label: S.retry,
                              icon: Icons.refresh,
                              variant: AppButtonVariant.outlined,
                              onPressed: m.busy
                                  ? null
                                  : () => c.refreshEntitlement(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            key: AccountScreen.logOutKey,
                            label: S.logOut,
                            variant: AppButtonVariant.text,
                            onPressed: m.busy ? null : c.signOut,
                          ),
                        ],
                      ),
                      if (!widget.storeBuild &&
                          (e?.canCancel ?? false)) ...<Widget>[
                        const SizedBox(height: 4),
                        AppButton(
                          key: AccountScreen.cancelKey,
                          label: m.confirmingCancel
                              ? S.payCancelConfirm
                              : S.payCancel,
                          variant: AppButtonVariant.text,
                          color: AppColors.danger,
                          foregroundColor: AppColors.danger,
                          onPressed: m.busy ? null : c.cancelSubscription,
                        ),
                      ],
                      if (widget.storeBuild) ...<Widget>[
                        const SizedBox(height: 4),
                        AppButton(
                          key: AccountScreen.manageStoreKey,
                          label: S.storeManage,
                          icon: Icons.manage_accounts_outlined,
                          variant: AppButtonVariant.outlined,
                          onPressed: m.busy ? null : c.openStoreCustomerCenter,
                          expand: true,
                        ),
                        const SizedBox(height: 4),
                        AppButton(
                          key: AccountScreen.restoreStoreKey,
                          label: S.storeRestore,
                          icon: Icons.restore,
                          variant: AppButtonVariant.text,
                          onPressed: m.busy ? null : c.restoreStorePurchases,
                          expand: true,
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
                      MembershipErrorBanner(
                        error: m.error,
                        onDismiss: c.dismissError,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Voluntary password change: the same endpoint the forced
                // screen uses.
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const AuthHeading(S.pwChange),
                      const SizedBox(height: 10),
                      if (!_changing)
                        AppButton(
                          key: AccountScreen.changePasswordKey,
                          label: S.pwChange,
                          icon: Icons.lock_reset_outlined,
                          variant: AppButtonVariant.outlined,
                          onPressed: () => setState(() => _changing = true),
                          expand: true,
                        )
                      else ...<Widget>[
                        PasswordField(
                          controller: _password,
                          label: S.pwNew,
                          enabled: !m.busy,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _confirmation,
                          label: S.pwConfirm,
                          enabled: !m.busy,
                        ),
                        const SizedBox(height: 6),
                        const AuthNote(S.authShortPassword),
                        const SizedBox(height: 12),
                        AppButton(
                          label: S.pwSave,
                          icon: Icons.check,
                          onPressed: m.busy
                              ? null
                              : () => c.changePassword(
                                  _password.text,
                                  _confirmation.text,
                                ),
                          expand: true,
                        ),
                        AppButton(
                          label: S.cancel,
                          variant: AppButtonVariant.text,
                          onPressed: m.busy
                              ? null
                              : () => setState(() {
                                  _changing = false;
                                  _password.clear();
                                  _confirmation.clear();
                                }),
                        ),
                      ],
                      if (m.passwordChanged) ...<Widget>[
                        const SizedBox(height: 10),
                        InfoBanner(
                          message: S.pwChanged,
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          actionLabel: S.close,
                          onTap: c.dismissError,
                        ),
                      ],
                    ],
                  ),
                ),

                // Admin area: only for admin accounts. The server checks it
                // again on every call.
                if (m.isAdmin) ...<Widget>[
                  const SizedBox(height: 16),
                  SectionCard(
                    key: AccountScreen.adminEntryKey,
                    onTap: () => AdminScreen.open(context),
                    semanticLabel: S.adminOpen.text,
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              LocalizedText(
                                S.adminOpen,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              const AuthNote(S.adminNote),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Bi _statusText(Entitlement? e, {required bool access}) {
    if (e == null) {
      return S.payNone;
    }
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
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final Bi label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LocalizedText(
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
