import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/constrained_content.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import '../membership_models.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';
import 'temp_password_dialog.dart';

/// Which tool the page is serving.
enum AdminTask {
  /// Auto-generate a password for the chosen user.
  password,

  /// Delete the chosen user.
  delete,
}

/// Search for a user, pick one, then either generate a password or delete
/// the account.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key, required this.task});

  final AdminTask task;

  static const Key searchFieldKey = Key('admin.users.query');
  static const Key searchButtonKey = Key('admin.users.search');
  static const Key actionKey = Key('admin.users.action');
  static const Key confirmFieldKey = Key('admin.users.confirmEmail');

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _confirmEmail = TextEditingController();
  bool _mismatch = false;

  @override
  void dispose() {
    _query.dispose();
    _confirmEmail.dispose();
    super.dispose();
  }

  Future<void> _generate(AdminUser user) async {
    final AdminController c = ref.read(adminControllerProvider.notifier);
    final TemporaryPassword? temp = await c.generateTemporaryPassword();
    if (temp == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    // The password lives in the dialog's own state and nowhere else: it is
    // never written to the controller, to storage or to a log.
    await showTemporaryPasswordDialog(
      context: context,
      email: user.email,
      password: temp.password,
    );
  }

  Future<void> _delete(AdminUser user) async {
    final bool typedMatches =
        _confirmEmail.text.trim().toLowerCase() == user.email.toLowerCase();
    setState(() => _mismatch = !typedMatches);
    if (!typedMatches) {
      return;
    }
    final bool done =
        await ref.read(adminControllerProvider.notifier).deleteSelectedUser();
    if (done && mounted) {
      _confirmEmail.clear();
      setState(() => _mismatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final AdminState s = ref.watch(adminControllerProvider);
    final AdminController c = ref.read(adminControllerProvider.notifier);
    final AdminUser? selected = s.selected;
    final bool deleting = widget.task == AdminTask.delete;
    final String? deleted = s.deletedEmail;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          (deleting ? S.adminDeleteUser : S.adminGenPassword).text,
        ),
      ),
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
                      AdminField(
                        key: AdminUsersScreen.searchFieldKey,
                        controller: _query,
                        label: S.adminSearchUser,
                        enabled: !s.busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.search,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        key: AdminUsersScreen.searchButtonKey,
                        label: S.adminSearch,
                        icon: Icons.search,
                        variant: AppButtonVariant.outlined,
                        onPressed:
                            s.busy ? null : () => c.searchUsers(_query.text),
                        expand: true,
                      ),
                      if (s.busy) ...<Widget>[
                        const SizedBox(height: 12),
                        const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ],
                      if (s.searched && s.users.isEmpty && !s.busy) ...<Widget>[
                        const SizedBox(height: 12),
                        const LocalizedText(S.adminNoUsers),
                      ],
                      AdminErrorBanner(error: s.error, onDismiss: c.dismiss),
                    ],
                  ),
                ),
                if (s.users.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final AdminUser user in s.users)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _UserTile(
                        user: user,
                        selected: selected?.userId == user.userId,
                        onTap: () {
                          _confirmEmail.clear();
                          setState(() => _mismatch = false);
                          c.select(
                            selected?.userId == user.userId ? null : user,
                          );
                        },
                      ),
                    ),
                ],
                if (selected != null) ...<Widget>[
                  const SizedBox(height: 8),
                  SectionCard(
                    borderColor:
                        deleting ? AppColors.danger : AppColors.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        LocalizedText(
                          S.adminSelected(selected.email),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        LocalizedText(
                          deleting
                              ? S.adminDeleteConfirm(selected.email)
                              : S.adminGenConfirm(selected.email),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (deleting) ...<Widget>[
                          const SizedBox(height: 12),
                          AdminField(
                            key: AdminUsersScreen.confirmFieldKey,
                            controller: _confirmEmail,
                            label: S.adminSearchUser,
                            enabled: !s.busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            errorText:
                                _mismatch ? S.adminDeleteMismatch.text : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppButton(
                          key: AdminUsersScreen.actionKey,
                          label: deleting ? S.adminDelete : S.adminGenerate,
                          icon: deleting
                              ? Icons.delete_forever_outlined
                              : Icons.password_outlined,
                          color: deleting ? AppColors.danger : null,
                          foregroundColor: deleting ? Colors.white : null,
                          onPressed: s.busy
                              ? null
                              : () => deleting
                                  ? _delete(selected)
                                  : _generate(selected),
                          expand: true,
                        ),
                      ],
                    ),
                  ),
                ],
                if (deleted != null) ...<Widget>[
                  const SizedBox(height: 12),
                  InfoBanner(
                    message: S.adminDeleted(deleted),
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    actionLabel: S.close,
                    onTap: c.dismiss,
                  ),
                  const SizedBox(height: 8),
                  LocalizedText(
                    s.deletedSubscriptionCancelled
                        ? S.adminDeletedCancelled
                        : S.adminDeletedNoSub,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AdminUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      onTap: onTap,
      semanticLabel: user.email,
      borderColor: selected ? AppColors.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(user.email, style: theme.textTheme.bodyMedium),
                if (user.stateLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    user.stateLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
