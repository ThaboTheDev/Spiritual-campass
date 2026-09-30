import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/town.dart';
import '../../data/repositories/towns_repository.dart';
import '../../widgets/localized_text.dart';
import '../../widgets/language_scope.dart';
import 'towns_providers.dart';

/// A searchable, grouped list of towns. Resolves with the chosen [Town] or
/// `null` when dismissed.
Future<Town?> showTownPicker(BuildContext context) {
  return showModalBottomSheet<Town>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (BuildContext sheetContext) => const TownPickerSheet(),
  );
}

/// The body of [showTownPicker].
class TownPickerSheet extends ConsumerStatefulWidget {
  const TownPickerSheet({super.key});

  @override
  ConsumerState<TownPickerSheet> createState() => _TownPickerSheetState();
}

class _TownPickerSheetState extends ConsumerState<TownPickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TownGroup>> towns = ref.watch(townsProvider);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController controller) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: LocalizedText(
                        S.pickTown,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: S.close.text,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: S.searchTown.text,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _query.clear,
                          ),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LocalizedText(
                  S.townNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: towns.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                  error: (Object error, StackTrace _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LocalizedText(
                        S.noTownMatch,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (List<TownGroup> groups) => _TownList(
                    groups: TownsRepository.filter(groups, _query.text),
                    controller: controller,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TownList extends StatelessWidget {
  const _TownList({required this.groups, required this.controller});

  final List<TownGroup> groups;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LocalizedText(
            S.noTownMatch,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Flatten to one list of headers + rows so the builder stays lazy.
    final List<Object> rows = <Object>[];
    for (final TownGroup group in groups) {
      rows.add(group);
      rows.addAll(group.towns);
    }

    return ListView.builder(
      controller: controller,
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final Object row = rows[index];
        if (row is TownGroup) {
          return Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              '${row.name.toUpperCase()} · ${row.towns.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          );
        }
        final Town town = row as Town;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.place_outlined, color: AppColors.accent),
          title: Text(
            town.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${town.latitude.toStringAsFixed(3)}, '
            '${town.longitude.toStringAsFixed(3)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          onTap: () => Navigator.of(context).pop(town),
        );
      },
    );
  }
}
