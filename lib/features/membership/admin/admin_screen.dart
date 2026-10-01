import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/cards.dart';
import '../../../widgets/constrained_content.dart';
import '../../../widgets/language_scope.dart';
import '../../../widgets/localized_text.dart';
import 'add_centre_screen.dart';
import 'admin_users_screen.dart';

/// The admin hub: three tools, each on its own page.
///
/// Only reachable from the account screen when `/api/me` said `is_admin`.
/// Every call behind these pages is checked again by the server, so a
/// tampered client gains nothing.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  static const Key addCentreKey = Key('admin.addCentre');
  static const Key generatePasswordKey = Key('admin.generatePassword');
  static const Key deleteUserKey = Key('admin.deleteUser');

  /// Opens the hub as a full route.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LanguageScope.watch(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(S.adminTitle.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                const SectionCard(child: LocalizedText(S.adminNote)),
                const SizedBox(height: 12),
                _Tool(
                  toolKey: addCentreKey,
                  icon: Icons.add_location_alt_outlined,
                  label: S.adminAddCentre,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddCentreScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Tool(
                  toolKey: generatePasswordKey,
                  icon: Icons.password_outlined,
                  label: S.adminGenPassword,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AdminUsersScreen(task: AdminTask.password),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Tool(
                  toolKey: deleteUserKey,
                  icon: Icons.person_remove_outlined,
                  label: S.adminDeleteUser,
                  danger: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AdminUsersScreen(task: AdminTask.delete),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.toolKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final Key toolKey;
  final IconData icon;
  final Bi label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? AppColors.danger : AppColors.accent;
    return SectionCard(
      key: toolKey,
      onTap: onTap,
      semanticLabel: label.text,
      child: Row(
        children: <Widget>[
          Icon(icon, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: LocalizedText(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
