import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/cards.dart';
import 'admin_controller.dart';

/// The message for an [AdminError], or `null` when there is nothing to say.
Bi? adminErrorText(AdminError error) {
  switch (error) {
    case AdminError.none:
      return null;
    case AdminError.forbidden:
      return S.adminForbidden;
    case AdminError.offline:
      return S.payOffline;
    case AdminError.duplicateCentre:
      return S.adminDuplicateCentre;
    case AdminError.invalidCentre:
      return S.adminInvalidCentre;
    case AdminError.cannotDeleteSelf:
      return S.adminCannotDeleteSelf;
    case AdminError.payfastCancelFailed:
      return S.adminPayfastFailed;
    case AdminError.failed:
      return S.adminFailed;
  }
}

/// The red banner shown under an admin form.
class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({
    super.key,
    required this.error,
    required this.onDismiss,
  });

  final AdminError error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Bi? message = adminErrorText(error);
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoBanner(
        message: message,
        icon: Icons.error_outline,
        color: error == AdminError.offline
            ? AppColors.warning
            : AppColors.danger,
        actionLabel: S.close,
        onTap: onDismiss,
      ),
    );
  }
}

/// A plain single-line text field styled like the rest of the app.
class AdminField extends StatelessWidget {
  const AdminField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final Bi label;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final String? errorText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label.text,
        errorText: errorText,
        isDense: true,
      ),
    );
  }
}
