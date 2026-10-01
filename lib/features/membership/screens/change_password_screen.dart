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

/// The forced password change, after an administrator used
/// "Auto-generate password".
///
/// There is deliberately **no** way out of this screen except setting a
/// password or logging out: no app bar, no back button, and `PopScope`
/// swallows the Android system back gesture. While the server reports
/// `must_change_password` every other `/api/*` call answers 403, so letting
/// the member wander off would only produce errors.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  static const Key newPasswordKey = Key('changePassword.new');
  static const Key confirmPasswordKey = Key('changePassword.confirm');
  static const Key submitKey = Key('changePassword.submit');
  static const Key logOutKey = Key('changePassword.logOut');

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

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
    final MembershipController c =
        ref.read(membershipControllerProvider.notifier);

    return PopScope<Object?>(
      // The only ways on are "Save password" and "Log out".
      canPop: false,
      child: AuthScaffold(
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const AuthHeading(S.pwTitle),
                const SizedBox(height: 12),
                LocalizedText(
                  S.pwBody,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                if (m.email.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    m.email,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                PasswordField(
                  key: ChangePasswordScreen.newPasswordKey,
                  controller: _password,
                  label: S.pwNew,
                  enabled: !m.busy,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                PasswordField(
                  key: ChangePasswordScreen.confirmPasswordKey,
                  controller: _confirmation,
                  label: S.pwConfirm,
                  enabled: !m.busy,
                  onSubmitted: (_) =>
                      c.changePassword(_password.text, _confirmation.text),
                ),
                const SizedBox(height: 6),
                const AuthNote(S.authShortPassword),
                const SizedBox(height: 14),
                AppButton(
                  key: ChangePasswordScreen.submitKey,
                  label: S.pwSave,
                  icon: Icons.lock_reset_outlined,
                  onPressed: m.busy
                      ? null
                      : () =>
                          c.changePassword(_password.text, _confirmation.text),
                  expand: true,
                ),
                if (m.fromCache) ...<Widget>[
                  const SizedBox(height: 12),
                  InfoBanner(
                    message: S.pwOffline,
                    icon: Icons.wifi_off_outlined,
                    color: AppColors.warning,
                  ),
                ],
                MembershipErrorBanner(
                  error: m.error,
                  onDismiss: c.dismissError,
                ),
                const SizedBox(height: 4),
                AppButton(
                  key: ChangePasswordScreen.logOutKey,
                  label: S.logOut,
                  variant: AppButtonVariant.text,
                  onPressed: m.busy ? null : c.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
