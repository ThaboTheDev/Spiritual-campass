import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/nine_pointed_star.dart';
import '../compass/compass_controller.dart';
import '../shell/app_shell.dart';
import 'membership_controller.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/trial_intro_screen.dart';

/// The one door into the app.
///
/// Nothing below [AuthPhase.ready] is built: no [AppShell], so no compass,
/// no sensors, no location stream and no wake lock. When access ends
/// mid-session the compass is stopped and the paywall takes over, from
/// wherever in the app the member happened to be.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.recheckInterval = const Duration(minutes: 15)});

  /// How often to ask the server again while the app is open.
  final Duration recheckInterval;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.recheckInterval, (_) => _recheck());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheck();
    }
  }

  void _recheck() {
    final MembershipState state = ref.read(membershipControllerProvider);
    if (!state.isSignedIn || state.busy) {
      return;
    }
    unawaited(ref.read(membershipControllerProvider.notifier).recheckAccess());
  }

  @override
  Widget build(BuildContext context) {
    final AuthPhase phase = ref.watch(
      membershipControllerProvider.select((MembershipState s) => s.phase),
    );

    // Access ended (or a password change became due) while the app was open:
    // stop the sensors and drop any pushed route, so the gate's screen is
    // what the member sees.
    ref.listen<AuthPhase>(
      membershipControllerProvider.select((MembershipState s) => s.phase),
      (AuthPhase? before, AuthPhase after) {
        if (before == AuthPhase.ready && after != AuthPhase.ready) {
          ref.read(compassControllerProvider.notifier).stop();
          final NavigatorState navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.popUntil((Route<dynamic> route) => route.isFirst);
          }
        }
      },
    );

    return switch (phase) {
      AuthPhase.loading => const _Splash(),
      AuthPhase.signedOut => const LoginScreen(),
      AuthPhase.mustChangePassword => const ChangePasswordScreen(),
      AuthPhase.trialIntro => const TrialIntroScreen(),
      AuthPhase.paywall => const PaywallScreen(),
      AuthPhase.offlineLocked => const OfflineLockedScreen(),
      AuthPhase.ready => const AppShell(),
    };
  }
}

/// Shown while the stored session is restored and `/api/me` is asked.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NinePointedStar(size: 72, color: AppColors.gold),
            SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
