import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/constrained_content.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../membership_controller.dart';

/// Shared layout for the screens the gate shows before the app itself.
///
/// Portrait, scrollable (so it still fits a 320 dp phone at 1.3× text scale)
/// and centred on wide screens, exactly like every other screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.showHeader = true,
  });

  /// Content under the header.
  final List<Widget> children;

  /// Whether the crest header is shown.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                if (showHeader) ...<Widget>[
                  const AppHeader(),
                  const SizedBox(height: 20),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An uppercase accent heading, matching the rest of the app.
class AuthHeading extends StatelessWidget {
  const AuthHeading(this.text, {super.key});

  final Bi text;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    return Semantics(
      header: true,
      child: Text(
        text.text.toUpperCase(),
        style: AppText.sectionHeader.copyWith(color: AppColors.accent),
      ),
    );
  }
}

/// A password field with a show / hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Bi label;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      style: const TextStyle(color: AppColors.textPrimary),
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label.text,
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
          tooltip: _obscure ? S.authShowPassword.text : S.authHidePassword.text,
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// The inline message for [error], or `null` when there is none.
Bi? membershipErrorText(MembershipError error) {
  switch (error) {
    case MembershipError.none:
      return null;
    case MembershipError.badEmail:
      return S.authBadEmail;
    case MembershipError.missingPassword:
      return S.authNoPassword;
    case MembershipError.shortPassword:
      return S.authShortPassword;
    case MembershipError.passwordMismatch:
      return S.pwMismatch;
    case MembershipError.invalidCredentials:
      return S.authInvalid;
    case MembershipError.alreadyRegistered:
      return S.authAlready;
    case MembershipError.weakPassword:
      return S.authWeak;
    case MembershipError.rateLimited:
      return S.authRateLimited;
    case MembershipError.offline:
      return S.payOffline;
    case MembershipError.authFailed:
      return S.authFailed;
    case MembershipError.changePasswordFailed:
      return S.pwFailed;
    case MembershipError.checkoutFailed:
    case MembershipError.openFailed:
      return S.payOpenFail;
    case MembershipError.alreadySubscribed:
      return S.payActive;
    case MembershipError.cancelFailed:
      return S.payCancelFail;
    case MembershipError.storeBillingFailed:
      return S.storeBillingFailed;
  }
}

/// The error banner shared by every gate screen; renders nothing when there
/// is no error.
class MembershipErrorBanner extends StatelessWidget {
  const MembershipErrorBanner({
    super.key,
    required this.error,
    required this.onDismiss,
  });

  final MembershipError error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Bi? message = membershipErrorText(error);
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoBanner(
        message: message,
        icon: Icons.error_outline,
        color: error == MembershipError.offline
            ? AppColors.warning
            : AppColors.danger,
        actionLabel: S.close,
        onTap: onDismiss,
      ),
    );
  }
}

/// A short note in the muted caption style.
class AuthNote extends StatelessWidget {
  const AuthNote(this.text, {super.key});

  final Bi text;

  @override
  Widget build(BuildContext context) {
    return LocalizedText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textMuted,
        fontSize: 12.5,
        height: 1.45,
      ),
    );
  }
}
