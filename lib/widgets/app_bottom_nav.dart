import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import 'language_scope.dart';

/// One tab of the bottom navigation.
class AppTab {
  const AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// Tab label.
  final Bi label;

  /// Icon shown when the tab is not selected.
  final IconData icon;

  /// Icon shown when the tab is selected.
  final IconData selectedIcon;
}

/// The five tabs of the app, in order.
const List<AppTab> kAppTabs = <AppTab>[
  AppTab(
    label: S.tabCompass,
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  AppTab(
    label: S.tabMsamo,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  AppTab(
    label: S.tabLocation,
    icon: Icons.my_location_outlined,
    selectedIcon: Icons.my_location,
  ),
  AppTab(
    label: S.tabCentres,
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
  ),
  AppTab(
    label: S.tabGuide,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
];

/// Bottom navigation with five tabs, each showing an icon and its label in
/// the chosen language. The selected tab gets a rounded blue-tinted
/// highlight.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = kAppTabs,
  });

  /// Index of the selected tab.
  final int currentIndex;

  /// Called with the index of the tapped tab.
  final ValueChanged<int> onTap;

  /// The tabs to show.
  final List<AppTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(top: 6, bottom: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: <Widget>[
                for (int index = 0; index < tabs.length; index++)
                  Expanded(
                    child: _AppTabButton(
                      tab: tabs[index],
                      selected: index == currentIndex,
                      onTap: () => onTap(index),
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

class _AppTabButton extends StatelessWidget {
  const _AppTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    LanguageScope.watch(context);
    final ThemeData theme = Theme.of(context);
    final Color foreground = selected ? AppColors.accent : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label.text,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 21,
                    color: foreground,
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label.text,
                        style: (theme.textTheme.labelSmall ?? const TextStyle())
                            .copyWith(
                              color: foreground,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: selected ? 12 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
