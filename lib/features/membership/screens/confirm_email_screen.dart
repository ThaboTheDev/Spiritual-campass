import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../membership_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Shown after a sign-up when the project has e-mail confirmation on: there
/// is no session yet, only a link waiting in the member's inbox.
class ConfirmEmailScreen extends ConsumerWidget {
  const ConfirmEmailScreen({super.key});

  static const Key resendKey = Key('confirm.resend');
  static const Key doneKey = Key('confirm.done');

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
              const AuthHeading(S.authCheck),
              const SizedBox(height: 12),
              LocalizedText(
                S.confirmBody(m.email),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              AppButton(
                key: ConfirmEmailScreen.doneKey,
                label: S.confirmDone,
                icon: Icons.login_outlined,
                onPressed: m.busy ? null : c.backToLogin,
                expand: true,
              ),
              const SizedBox(height: 8),
              AppButton(
                key: ConfirmEmailScreen.resendKey,
                label: S.confirmResend,
                icon: Icons.outgoing_mail,
                variant: AppButtonVariant.outlined,
                onPressed: m.busy ? null : c.resendConfirmation,
                expand: true,
              ),
              if (m.confirmationResent) ...<Widget>[
                const SizedBox(height: 12),
                InfoBanner(
                  message: S.confirmResent,
                  icon: Icons.mark_email_read_outlined,
                  color: AppColors.gold,
                  actionLabel: S.close,
                  onTap: c.dismissError,
                ),
              ],
              MembershipErrorBanner(error: m.error, onDismiss: c.dismissError),
            ],
          ),
        ),
      ],
    );
  }
}
