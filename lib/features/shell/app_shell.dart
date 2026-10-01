import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../centres/centres_screen.dart';
import '../compass/compass_controller.dart';
import '../compass/compass_screen.dart';
import '../guide/guide_screen.dart';
import '../location/location_controller.dart';
import '../location/location_screen.dart';
import '../msamo/msamo_screen.dart';

/// The five-tab shell that holds every screen.
///
/// An [IndexedStack] keeps visited screens alive, so the compass keeps running
/// (and scroll positions stay put) while the user moves between tabs — but a
/// tab is not *built* until it is first opened, so the map (the heaviest
/// screen) costs nothing until the user asks for Centres.
///
/// The shell also watches the app lifecycle: sensors and the wake lock are
/// released when the app goes to the background and restarted on resume.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const int _tabCount = 5;

  late int _index;
  bool _restoreLocationTracking = false;
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final int stored = ref.read(preferencesStoreProvider).lastTab;
    _index = stored.clamp(0, _tabCount - 1).toInt();
    _visited.add(_index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CompassController compass = ref.read(
      compassControllerProvider.notifier,
    );
    switch (state) {
      case AppLifecycleState.resumed:
        compass.onAppResumed();
        if (_restoreLocationTracking) {
          _restoreLocationTracking = false;
          unawaited(
            ref.read(locationControllerProvider.notifier).startTracking(),
          );
        }
      case AppLifecycleState.inactive:
        // Transient (notification shade, permission dialog): keep running.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        final LocationState location = ref.read(locationControllerProvider);
        _restoreLocationTracking =
            _restoreLocationTracking || location.tracking || location.loading;
        compass.onAppPaused();
        // Location can have been started from its own tab while Compass is off.
        ref.read(locationControllerProvider.notifier).stopTracking();
    }
  }

  void _onTap(int index) {
    if (index == _index) {
      return;
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
    ref.read(preferencesStoreProvider).saveLastTab(index);
  }

  Widget _screen(int index) {
    if (!_visited.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return const CompassScreen();
      case 1:
        return const MsamoScreen();
      case 2:
        return const LocationScreen();
      case 3:
        return const CentresScreen();
      default:
        return const GuideScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _index,
        children: <Widget>[for (int i = 0; i < _tabCount; i++) _screen(i)],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _onTap),
    );
  }
}
