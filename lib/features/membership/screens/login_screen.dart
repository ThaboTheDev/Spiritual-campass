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

/// The first screen on a fresh install: log in, or create an account.
///
/// Nothing in the app — not even the compass — is reachable from here until
/// the server has confirmed who the member is and that they have access.
///
/// Creating an account signs the member in at once: there is no confirmation
/// e-mail. There is no password-recovery e-mail either — an administrator
/// issues a new password instead (see [adminHelpKey]).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// Keys the widget tests drive the form with.
  static const Key emailFieldKey = Key('login.email');
  static const Key passwordFieldKey = Key('login.password');
  static const Key submitKey = Key('login.submit');
  static const Key logInTabKey = Key('login.tab.logIn');
  static const Key createTabKey = Key('login.tab.create');

  /// The "an administrator can issue you a new password" note. There is no
  /// self-service password recovery.
  static const Key adminHelpKey = Key('login.adminHelp');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(MembershipState m, MembershipController c) {
    // The controller refuses a second call while it is busy, so a double tap
    // cannot send two requests.
    if (m.mode == AuthMode.createAccount) {
      c.signUp(_email.text, _password.text);
    } else {
      c.logIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final MembershipState m = ref.watch(membershipControllerProvider);
    final MembershipController c =
        ref.read(membershipControllerProvider.notifier);
    final bool creating = m.mode == AuthMode.createAccount;

    return AuthScaffold(
      children: <Widget>[
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthHeading(S.authTitle),
              const SizedBox(height: 14),

              // Log in / Create account.
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      key: LoginScreen.logInTabKey,
                      label: S.authLogIn,
                      variant: creating
                          ? AppButtonVariant.outlined
                          : AppButtonVariant.filled,
                      onPressed:
                          m.busy ? null : () => c.setMode(AuthMode.logIn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      key: LoginScreen.createTabKey,
                      label: S.authCreate,
                      variant: creating
                          ? AppButtonVariant.filled
                          : AppButtonVariant.outlined,
                      onPressed: m.busy
                          ? null
                          : () => c.setMode(AuthMode.createAccount),
                    ),
                  ),
                ],
              ),
              if (creating) ...<Widget>[
                const SizedBox(height: 12),
                const AuthNote(S.authCreateIntro),
              ],
              const SizedBox(height: 14),

              TextField(
                key: LoginScreen.emailFieldKey,
                controller: _email,
                enabled: !m.busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: S.authEmail.text,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              PasswordField(
                key: LoginScreen.passwordFieldKey,
                controller: _password,
                label: S.authPassword,
                enabled: !m.busy,
                onSubmitted: (_) => _submit(m, c),
              ),
              if (creating) ...<Widget>[
                const SizedBox(height: 6),
                const AuthNote(S.authShortPassword),
              ],
              const SizedBox(height: 14),

              AppButton(
                key: LoginScreen.submitKey,
                label: creating ? S.authCreate : S.authLogIn,
                icon: creating ? Icons.person_add_alt : Icons.login_outlined,
                onPressed: m.busy ? null : () => _submit(m, c),
                expand: true,
              ),
              if (m.busy) ...<Widget>[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (!creating) ...<Widget>[
                const SizedBox(height: 12),
                const AuthNote(
                  S.authContactAdmin,
                  key: LoginScreen.adminHelpKey,
                ),
              ],
              MembershipErrorBanner(error: m.error, onDismiss: c.dismissError),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LocalizedText(
          S.purposeBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
