import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../centres/centres_screen.dart';
import '../compass/compass_screen.dart';
import '../guide/guide_screen.dart';
import '../location/location_screen.dart';
import '../msamo/msamo_screen.dart';

/// The five-tab shell that holds every screen.
///
/// An [IndexedStack] keeps all five screens alive, so the compass keeps running
/// (and scroll positions stay put) while the user moves between tabs.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<Widget> _screens = <Widget>[
    CompassScreen(),
    MsamoScreen(),
    LocationScreen(),
    CentresScreen(),
    GuideScreen(),
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    final int stored = ref.read(preferencesStoreProvider).lastTab;
    _index = stored.clamp(0, _screens.length - 1).toInt();
  }

  void _onTap(int index) {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
    ref.read(preferencesStoreProvider).saveLastTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onTap: _onTap,
      ),
    );
  }
}
