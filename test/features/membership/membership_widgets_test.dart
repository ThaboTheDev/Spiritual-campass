import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/core/l10n/strings.dart';
import 'package:tshk_compass/data/local/preferences_store.dart';
import 'package:tshk_compass/features/membership/admin/temp_password_dialog.dart';
import 'package:tshk_compass/features/membership/membership_controller.dart';
import 'package:tshk_compass/features/membership/membership_models.dart';
import 'package:tshk_compass/features/membership/screens/account_screen.dart';
import 'package:tshk_compass/features/membership/screens/change_password_screen.dart';
import 'package:tshk_compass/features/membership/screens/login_screen.dart';
import 'package:tshk_compass/features/membership/screens/paywall_screen.dart';
import 'package:tshk_compass/features/membership/screens/trial_intro_screen.dart';

/// A controller with a fixed state: the screens are tested, not the network.
///
/// The validation paths (`logIn`, `changePassword`) are deliberately **not**
/// overridden — they never touch the network when the input is wrong, which is
/// exactly what these tests check.
class FakeMembership extends MembershipController {
  FakeMembership(this.initial);

  final MembershipState initial;
  final List<String> calls = <String>[];

  @override
  MembershipState build() => initial;

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    state = const MembershipState(phase: AuthPhase.signedOut);
  }

  @override
  Future<void> startCheckout() async => calls.add('checkout');

  @override
  Future<void> acknowledgeTrialIntro() async => calls.add('trialIntro');

  @override
  Future<void> refreshEntitlement({
    bool afterPayment = false,
    bool silent = false,
  }) async =>
      calls.add('refresh');

  @override
  Future<void> cancelSubscription() async => calls.add('cancel');
}

Entitlement entitlement({
  EntitlementState state = EntitlementState.active,
  bool access = true,
  bool isAdmin = false,
  bool mustChangePassword = false,
  int trialDays = 7,
  DateTime? endsAt,
}) =>
    Entitlement(
      email: 'member@example.org',
      status: state.name,
      state: state,
      access: access,
      canCancel: state == EntitlementState.active,
      priceMinor: 100,
      currency: 'ZAR',
      trialDays: trialDays,
      endsAt: endsAt ?? DateTime.now().toUtc().add(const Duration(days: 5)),
      fetchedAt: DateTime.now().toUtc(),
      isAdmin: isAdmin,
      mustChangePassword: mustChangePassword,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The header's language button reads the persisted language choice, so
  /// every screen here needs a preferences store behind it.
  late SharedPreferences preferences;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  /// Taps a control that may be below the fold on a small test surface.
  Future<void> tapKey(WidgetTester tester, Key key) async {
    final Finder finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  /// Wraps a screen with the providers it reads.
  Widget host(Widget child, FakeMembership fake) => ProviderScope(
        overrides: <Override>[
          membershipControllerProvider.overrideWith(() => fake),
          preferencesStoreProvider
              .overrideWithValue(PreferencesStore(preferences)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: child,
        ),
      );

  group('login screen', () {
    testWidgets('a malformed address is refused without a request',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.signedOut),
      );
      await tester.pumpWidget(host(const LoginScreen(), fake));

      await tester.enterText(
        find.byKey(LoginScreen.emailFieldKey),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(LoginScreen.passwordFieldKey),
        'secret123',
      );
      await tapKey(tester, LoginScreen.submitKey);

      expect(find.text(S.authBadEmail.text), findsOneWidget);
    });

    testWidgets('a missing password is refused too',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.signedOut),
      );
      await tester.pumpWidget(host(const LoginScreen(), fake));

      await tester.enterText(
        find.byKey(LoginScreen.emailFieldKey),
        'member@example.org',
      );
      await tapKey(tester, LoginScreen.submitKey);

      expect(find.text(S.authNoPassword.text), findsOneWidget);
    });

    testWidgets('the password is hidden until the eye is tapped',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.signedOut),
      );
      await tester.pumpWidget(host(const LoginScreen(), fake));

      final Finder field = find.descendant(
        of: find.byKey(LoginScreen.passwordFieldKey),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).obscureText, isTrue);

      await tester.ensureVisible(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(tester.widget<TextField>(field).obscureText, isFalse);
    });

    testWidgets('switching to "create account" shows the length hint',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.signedOut),
      );
      await tester.pumpWidget(host(const LoginScreen(), fake));

      expect(find.text(S.authShortPassword.text), findsNothing);

      await tapKey(tester, LoginScreen.createTabKey);

      expect(find.text(S.authShortPassword.text), findsOneWidget);
      expect(find.byKey(LoginScreen.adminHelpKey), findsNothing);
    });

    testWidgets('the log in half points at an administrator for a password',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.signedOut),
      );
      await tester.pumpWidget(host(const LoginScreen(), fake));

      // No self-service recovery: no button and no request, only the note.
      await tester.ensureVisible(find.byKey(LoginScreen.adminHelpKey));
      await tester.pumpAndSettle();
      expect(find.text(S.authContactAdmin.text), findsOneWidget);
    });
  });

  group('forced password change', () {
    testWidgets('has no app bar, no back button and refuses to pop',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(
          phase: AuthPhase.mustChangePassword,
          email: 'member@example.org',
        ),
      );
      await tester.pumpWidget(host(const ChangePasswordScreen(), fake));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);

      final PopScope<Object?> scope =
          tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>));
      expect(scope.canPop, isFalse);
    });

    testWidgets('the Android back button does not escape the screen',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.mustChangePassword),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            membershipControllerProvider.overrideWith(() => fake),
            preferencesStoreProvider
                .overrideWithValue(PreferencesStore(preferences)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: Text('behind the gate')),
            routes: <String, WidgetBuilder>{
              '/change': (BuildContext context) => const ChangePasswordScreen(),
            },
          ),
        ),
      );

      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/change');
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      // The Android system back button ends in Navigator.maybePop, which
      // PopScope(canPop: false) intercepts (returning true to mark the back
      // event handled while refusing to pop the route).
      expect(navigator.canPop(), isFalse);
      await Navigator.maybePop(
        tester.element(find.byType(ChangePasswordScreen)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text('behind the gate'), findsNothing);
    });

    testWidgets('mismatched passwords are caught before any request',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.mustChangePassword),
      );
      await tester.pumpWidget(host(const ChangePasswordScreen(), fake));

      await tester.enterText(
        find.byKey(ChangePasswordScreen.newPasswordKey),
        'a-good-password',
      );
      await tester.enterText(
        find.byKey(ChangePasswordScreen.confirmPasswordKey),
        'a-different-one',
      );
      await tapKey(tester, ChangePasswordScreen.submitKey);

      expect(find.text(S.pwMismatch.text), findsOneWidget);
    });

    testWidgets('logging out is the only escape', (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        const MembershipState(phase: AuthPhase.mustChangePassword),
      );
      await tester.pumpWidget(host(const ChangePasswordScreen(), fake));

      await tapKey(tester, ChangePasswordScreen.logOutKey);

      expect(fake.calls, contains('signOut'));
    });
  });

  group('trial page', () {
    testWidgets('offers "Pay now" in a direct build',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.trialIntro,
          entitlement: entitlement(state: EntitlementState.trial),
        ),
      );
      await tester.pumpWidget(
        host(const TrialIntroScreen(storeBuild: false), fake),
      );

      expect(find.byKey(TrialIntroScreen.payKey), findsOneWidget);
      expect(find.byKey(TrialIntroScreen.startKey), findsOneWidget);
    });

    testWidgets('hides every purchase control in a store build',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.trialIntro,
          entitlement: entitlement(state: EntitlementState.trial),
        ),
      );
      await tester.pumpWidget(
        host(const TrialIntroScreen(storeBuild: true), fake),
      );

      expect(find.byKey(TrialIntroScreen.payKey), findsNothing);
      expect(find.text(S.payNow.text), findsNothing);
      expect(find.byKey(TrialIntroScreen.startKey), findsOneWidget);
    });

    testWidgets('"Start using the app" marks the page as seen',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.trialIntro,
          entitlement: entitlement(state: EntitlementState.trial),
        ),
      );
      await tester.pumpWidget(
        host(const TrialIntroScreen(storeBuild: true), fake),
      );

      await tapKey(tester, TrialIntroScreen.startKey);

      expect(fake.calls, contains('trialIntro'));
    });
  });

  group('paywall', () {
    testWidgets('a store build shows the notice instead of "Pay now"',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.paywall,
          entitlement: entitlement(
            state: EntitlementState.expired,
            access: false,
          ),
        ),
      );
      await tester.pumpWidget(
        host(const PaywallScreen(storeBuild: true), fake),
      );

      expect(find.byKey(PaywallScreen.payKey), findsNothing);
      expect(find.text(S.payStore.text), findsOneWidget);
    });

    testWidgets('a direct build can pay and log out',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.paywall,
          entitlement: entitlement(
            state: EntitlementState.expired,
            access: false,
          ),
        ),
      );
      await tester.pumpWidget(
        host(const PaywallScreen(storeBuild: false), fake),
      );

      await tapKey(tester, PaywallScreen.payKey);
      expect(fake.calls, contains('checkout'));

      await tapKey(tester, PaywallScreen.logOutKey);
      expect(fake.calls, contains('signOut'));
    });
  });

  group('account screen', () {
    testWidgets('hides the admin area for an ordinary member',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.ready,
          email: 'member@example.org',
          entitlement: entitlement(),
        ),
      );
      await tester.pumpWidget(host(const AccountScreen(), fake));

      expect(find.byKey(AccountScreen.adminEntryKey), findsNothing);
      expect(find.text(S.adminOpen.text), findsNothing);
    });

    testWidgets('shows the admin area for an administrator',
        (WidgetTester tester) async {
      final FakeMembership fake = FakeMembership(
        MembershipState(
          phase: AuthPhase.ready,
          email: 'admin@example.org',
          entitlement: entitlement(isAdmin: true),
        ),
      );
      await tester.pumpWidget(host(const AccountScreen(), fake));

      expect(find.byKey(AccountScreen.adminEntryKey), findsOneWidget);
    });
  });

  group('temporary password dialog', () {
    testWidgets('shows the password once and forgets it when closed',
        (WidgetTester tester) async {
      const String secret = 'Zx9-tmp-Pass';
      final List<MethodCall> platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showTemporaryPasswordDialog(
                  context: context,
                  email: 'member@example.org',
                  password: secret,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(secret), findsOneWidget);

      await tester.tap(find.byKey(TemporaryPasswordDialog.copyKey));
      await tester.pumpAndSettle();
      expect(
        platformCalls.any(
          (MethodCall call) =>
              call.method == 'Clipboard.setData' &&
              (call.arguments as Map<Object?, Object?>)['text'] == secret,
        ),
        isTrue,
      );
      expect(find.text(S.adminCopied.text), findsOneWidget);

      await tester.tap(find.byKey(TemporaryPasswordDialog.doneKey));
      await tester.pumpAndSettle();

      // Gone from the tree: there is no way back to it, only a new one.
      expect(find.text(secret), findsNothing);
      expect(find.byType(TemporaryPasswordDialog), findsNothing);
    });

    testWidgets('cannot be dismissed by tapping outside',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showTemporaryPasswordDialog(
                context: context,
                email: 'member@example.org',
                password: 'secret-temp-1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(TemporaryPasswordDialog), findsOneWidget);
    });
  });
}
