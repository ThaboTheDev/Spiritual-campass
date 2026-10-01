import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/localized_text.dart';

/// Shows the generated password once.
///
/// The value is passed in, held only in this dialog's widget state and
/// dropped when the dialog closes: it is never put in a controller, in
/// `shared_preferences`, in secure storage, or in a log line. Reopening the
/// dialog is impossible — the admin must generate a new one.
Future<void> showTemporaryPasswordDialog({
  required BuildContext context,
  required String email,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => TemporaryPasswordDialog(
      email: email,
      password: password,
    ),
  );
}

/// The dialog itself; public so the widget test can pump it directly.
class TemporaryPasswordDialog extends StatefulWidget {
  const TemporaryPasswordDialog({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  static const Key passwordKey = Key('admin.temp.password');
  static const Key copyKey = Key('admin.temp.copy');
  static const Key doneKey = Key('admin.temp.done');

  @override
  State<TemporaryPasswordDialog> createState() =>
      _TemporaryPasswordDialogState();
}

class _TemporaryPasswordDialogState extends State<TemporaryPasswordDialog> {
  /// The only copy the app keeps, and only while the dialog is up.
  String? _password;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _password = widget.password;
  }

  @override
  void dispose() {
    // Forget it as soon as the dialog goes away.
    _password = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String password = _password ?? '';
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(S.adminTempTitle.text, style: theme.textTheme.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.email,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold),
            ),
            child: SelectableText(
              password,
              key: TemporaryPasswordDialog.passwordKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LocalizedText(
            S.adminTempWarning,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        AppButton(
          key: TemporaryPasswordDialog.copyKey,
          label: _copied ? S.adminCopied : S.adminCopy,
          icon: _copied ? Icons.check : Icons.copy_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: password.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: password));
                  if (mounted) {
                    setState(() => _copied = true);
                  }
                },
        ),
        AppButton(
          key: TemporaryPasswordDialog.doneKey,
          label: S.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
