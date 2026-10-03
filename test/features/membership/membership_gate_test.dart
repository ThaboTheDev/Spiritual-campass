import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/data/local/centres_cache.dart';
import 'package:tshk_compass/data/local/preferences_store.dart';
import 'package:tshk_compass/features/membership/membership_api.dart';
import 'package:tshk_compass/features/membership/membership_controller.dart';
import 'package:tshk_compass/features/membership/membership_models.dart';
import 'package:tshk_compass/features/membership/session_store.dart';

/// One place decides what a member may see; these tests walk that state
/// machine through the paths that matter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A stored session that is still valid, so no refresh is attempted.
  AuthSession validSession({String userId = 'user-1'}) => AuthSession(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        email: 'member@example.org',
        userId: userId,
      );

  Map<String, dynamic> me({
    String state = 'active',
    bool access = true,
    bool isAdmin = false,
    bool mustChangePassword = false,
    DateTime? endsAt,
  }) =>
      <String, dynamic>{
        'email': 'member@example.org',
        'state': state,
        'access': access,
        'can_cancel': state == 'active',
        'price': 100,
        'currency': 'ZAR',
        'trial_days': 7,
        'ends_at': (endsAt ?? DateTime.now().toUtc().add(const Duration(days: 20)))
            .toIso8601String(),
        'is_admin': isAdmin,
        'must_change_password': mustChangePassword,
      };

  /// Builds a container with every outside edge faked.
  Future<(ProviderContainer, PreferencesStore)> harness({
    AuthSession? session,
    required http.Response Function(http.Request request) api,
    http.Response Function(http.Request request)? auth,
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final PreferencesStore store =
        PreferencesStore(await SharedPreferences.getInstance());
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        centresCacheProvider.overrideWithValue(MemoryCentresCache()),
        sessionStoreProvider
            .overrideWithValue(MemorySessionStore()..session = session),
        membershipApiClientProvider.overrideWithValue(
          MembershipApiClient(
            client: MockClient((http.Request request) async => api(request)),
            baseUrl: 'https://api.example.org',
          ),
        ),
        supabaseAuthClientProvider.overrideWithValue(
          SupabaseAuthClient(
            client: MockClient(
              (http.Request request) async =>
                  auth?.call(request) ?? http.Response('{}', 200),
            ),
            baseUrl: 'https://project.supabase.co',
            anonKey: 'anon',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, store);
  }

  /// Lets the controller's `build()` microtask, the fake HTTP answers and
  /// the mocked `SharedPreferences` writes all settle.
  Future<void> settle() async {
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('first run', () {
    test('no stored session → the login screen', () async {
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => http.Response('{}', 200),
      );

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.signedOut,
      );
    });

    test('stored session + active member → straight into the app', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => http.Response(jsonEncode(me()), 200),
      );

      container.read(membershipControllerProvider);
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.ready);
      expect(state.hasAccess, isTrue);
      expect(state.fromCache, isFalse);
      expect(state.email, 'member@example.org');
    });

    test('a trial member sees the trial page once, then never again',
        () async {
      final (ProviderContainer container, PreferencesStore prefs) =
          await harness(
        session: validSession(),
        api: (http.Request request) =>
            http.Response(jsonEncode(me(state: 'trial')), 200),
      );

      container.read(membershipControllerProvider);
      await settle();
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.trialIntro,
      );

      await container
          .read(membershipControllerProvider.notifier)
          .acknowledgeTrialIntro();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.ready,
      );
      expect(prefs.trialIntroSeen('user-1'), isTrue);

      // A later re-check must not show it again.
      await container
          .read(membershipControllerProvider.notifier)
          .refreshEntitlement();
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.ready,
      );
    });

    test('the trial flag is per account', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(userId: 'user-2'),
        api: (http.Request request) =>
            http.Response(jsonEncode(me(state: 'trial')), 200),
        prefs: const <String, Object>{'membership.trialIntro.user-1': true},
      );

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.trialIntro,
      );
    });
  });

  group('access', () {
    test('no access online → the paywall', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => http.Response(
          jsonEncode(me(state: 'expired', access: false)),
          200,
        ),
      );

      container.read(membershipControllerProvider);
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.paywall);
      expect(state.hasAccess, isFalse);
    });

    test('402 on /api/me without a cache → offline-locked, still signed in',
        () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'subscription_required'}),
          402,
        ),
      );

      container.read(membershipControllerProvider);
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.offlineLocked);
      expect(state.isSignedIn, isTrue);
    });

    test('access ending mid-session moves a ready member to the paywall',
        () async {
      bool expired = false;
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => http.Response(
          jsonEncode(
            expired ? me(state: 'expired', access: false) : me(),
          ),
          200,
        ),
      );

      container.read(membershipControllerProvider);
      await settle();
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.ready,
      );

      expired = true;
      await container
          .read(membershipControllerProvider.notifier)
          .recheckAccess();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.paywall,
      );
    });
  });

  group('403 password_change_required', () {
    test('sends the member to the change-password screen, never signs out',
        () async {
      final MemorySessionStore sessions = MemorySessionStore()
        ..session = validSession();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final PreferencesStore store =
          PreferencesStore(await SharedPreferences.getInstance());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          centresCacheProvider.overrideWithValue(MemoryCentresCache()),
          sessionStoreProvider.overrideWithValue(sessions),
          membershipApiClientProvider.overrideWithValue(
            MembershipApiClient(
              client: MockClient(
                (http.Request request) async => http.Response(
                  jsonEncode(
                    <String, dynamic>{'error': 'password_change_required'},
                  ),
                  403,
                ),
              ),
              baseUrl: 'https://api.example.org',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.mustChangePassword,
      );
      // Still signed in: the session is untouched.
      expect(sessions.session, isNotNull);
    });

    test('401 does sign out', () async {
      final MemorySessionStore sessions = MemorySessionStore()
        ..session = validSession();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final PreferencesStore store =
          PreferencesStore(await SharedPreferences.getInstance());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          centresCacheProvider.overrideWithValue(MemoryCentresCache()),
          sessionStoreProvider.overrideWithValue(sessions),
          membershipApiClientProvider.overrideWithValue(
            MembershipApiClient(
              client: MockClient(
                (http.Request request) async => http.Response('{}', 401),
              ),
              baseUrl: 'https://api.example.org',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.signedOut,
      );
      expect(sessions.session, isNull);
    });
  });

  group('offline', () {
    /// A cache body as the controller writes it.
    String cache(Map<String, dynamic> body, {DateTime? fetchedAt}) =>
        jsonEncode(<String, dynamic>{
          'me': body,
          'fetched_at': (fetchedAt ?? DateTime.now().toUtc())
              .millisecondsSinceEpoch,
        });

    test('a cached entitlement with a future date lets the member in',
        () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => throw http.ClientException('offline'),
        prefs: <String, Object>{
          'membership.entitlement': cache(me()),
          'membership.trialIntro.user-1': true,
        },
      );

      container.read(membershipControllerProvider);
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.ready);
      expect(state.fromCache, isTrue);
      expect(state.error, MembershipError.offline);
    });

    test('a cached entitlement whose date has passed does not', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => throw http.ClientException('offline'),
        prefs: <String, Object>{
          'membership.entitlement': cache(
            me(endsAt: DateTime.now().toUtc().subtract(const Duration(days: 1))),
            fetchedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          ),
        },
      );

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.offlineLocked,
      );
    });

    test('no cache at all → offline-locked, never signed out', () async {
      final MemorySessionStore sessions = MemorySessionStore()
        ..session = validSession();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final PreferencesStore store =
          PreferencesStore(await SharedPreferences.getInstance());
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          centresCacheProvider.overrideWithValue(MemoryCentresCache()),
          sessionStoreProvider.overrideWithValue(sessions),
          membershipApiClientProvider.overrideWithValue(
            MembershipApiClient(
              client: MockClient((http.Request request) async {
                throw http.ClientException('offline');
              }),
              baseUrl: 'https://api.example.org',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.offlineLocked,
      );
      expect(sessions.session, isNotNull);
    });

    test('a cached must_change_password is still a hard stop offline',
        () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) => throw http.ClientException('offline'),
        prefs: <String, Object>{
          'membership.entitlement': cache(me(mustChangePassword: true)),
          'membership.trialIntro.user-1': true,
        },
      );

      container.read(membershipControllerProvider);
      await settle();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.mustChangePassword,
      );
    });

    test('the server always overrides the cache', () async {
      bool offline = true;
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) {
          if (offline) {
            throw http.ClientException('offline');
          }
          return http.Response(
            jsonEncode(me(state: 'expired', access: false)),
            200,
          );
        },
        prefs: <String, Object>{
          'membership.entitlement': cache(me()),
          'membership.trialIntro.user-1': true,
        },
      );

      container.read(membershipControllerProvider);
      await settle();
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.ready,
      );

      offline = false;
      await container
          .read(membershipControllerProvider.notifier)
          .recheckAccess();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.paywall);
      expect(state.fromCache, isFalse);
    });
  });

  group('sign-in', () {
    test('a bad address never reaches the network', () async {
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => fail('must not call the API'),
        auth: (http.Request request) => fail('must not call Supabase'),
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .logIn('not-an-email', 'secret123');

      expect(
        container.read(membershipControllerProvider).error,
        MembershipError.badEmail,
      );
    });

    test('there is no confirmation screen: a refused login stays on this one',
        () async {
      // Confirmation is off in the project; a server that still asks for it
      // arrives as an invalid_grant and is shown as an ordinary failed login.
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => http.Response('{}', 200),
        auth: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'invalid_grant',
            'error_description': 'Email not confirmed',
          }),
          400,
        ),
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .logIn('member@example.org', 'secret123');

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.signedOut);
      expect(state.error, MembershipError.invalidCredentials);
      expect(state.busy, isFalse);
    });

    test('creating an account signs the member straight in', () async {
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            ...me(),
            'email': 'new@example.org',
          }),
          200,
        ),
        auth: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 3600,
            'user': <String, dynamic>{
              'id': 'user-9',
              'email': 'new@example.org',
            },
          }),
          200,
        ),
        prefs: <String, Object>{'membership.trialIntro.user-9': true},
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .signUp('new@example.org', 'secret123');
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.ready);
      expect(state.email, 'new@example.org');
      expect(state.busy, isFalse);
    });

    test('a sign-up answer without a session is an ordinary failure', () async {
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => http.Response('{}', 200),
        auth: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'id': 'u', 'email': 'new@example.org'}),
          200,
        ),
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .signUp('new@example.org', 'secret123');
      await settle();

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.phase, AuthPhase.signedOut);
      expect(state.error, MembershipError.authFailed);
      expect(state.busy, isFalse);
    });

    test('a short password is refused before the request', () async {
      final (ProviderContainer container, _) = await harness(
        api: (http.Request request) => http.Response('{}', 200),
        auth: (http.Request request) => fail('must not call Supabase'),
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .signUp('new@example.org', 'short');

      expect(
        container.read(membershipControllerProvider).error,
        MembershipError.shortPassword,
      );
    });

    test('logging out clears the session and the cached entitlement',
        () async {
      final MemorySessionStore sessions = MemorySessionStore()
        ..session = validSession();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'membership.entitlement': jsonEncode(<String, dynamic>{
          'me': me(),
          'fetched_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        }),
      });
      final PreferencesStore store =
          PreferencesStore(await SharedPreferences.getInstance());
      final MemoryCentresCache centres = MemoryCentresCache('{"centres":[]}');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          centresCacheProvider.overrideWithValue(centres),
          sessionStoreProvider.overrideWithValue(sessions),
          membershipApiClientProvider.overrideWithValue(
            MembershipApiClient(
              client: MockClient(
                (http.Request request) async =>
                    http.Response(jsonEncode(me()), 200),
              ),
              baseUrl: 'https://api.example.org',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(membershipControllerProvider);
      await settle();
      await container.read(membershipControllerProvider.notifier).signOut();

      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.signedOut,
      );
      expect(sessions.session, isNull);
      expect(store.cachedEntitlementJson, isNull);
      expect(centres.value, isNull);
    });
  });

  group('forced password change', () {
    test('a successful change logs back in and re-checks access', () async {
      bool changed = false;
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) {
          if (request.url.path == '/api/account/password') {
            changed = true;
            return http.Response(jsonEncode(<String, bool>{'ok': true}), 200);
          }
          return http.Response(
            jsonEncode(
              changed ? me() : me(mustChangePassword: true),
            ),
            200,
          );
        },
        auth: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'at2',
            'refresh_token': 'rt2',
            'expires_in': 3600,
            'user': <String, dynamic>{
              'id': 'user-1',
              'email': 'member@example.org',
            },
          }),
          200,
        ),
        prefs: const <String, Object>{'membership.trialIntro.user-1': true},
      );

      container.read(membershipControllerProvider);
      await settle();
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.mustChangePassword,
      );

      await container
          .read(membershipControllerProvider.notifier)
          .changePassword('brand-new-pass', 'brand-new-pass');

      expect(changed, isTrue);
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.ready,
      );
    });

    test('mismatched confirmation never calls the server', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) {
          if (request.url.path == '/api/account/password') {
            fail('must not call the password endpoint');
          }
          return http.Response(
            jsonEncode(me(mustChangePassword: true)),
            200,
          );
        },
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .changePassword('brand-new-pass', 'something-else');

      final MembershipState state =
          container.read(membershipControllerProvider);
      expect(state.error, MembershipError.passwordMismatch);
      expect(state.phase, AuthPhase.mustChangePassword);
    });

    test('weak_password from the server is its own message', () async {
      final (ProviderContainer container, _) = await harness(
        session: validSession(),
        api: (http.Request request) {
          if (request.url.path == '/api/account/password') {
            return http.Response(
              jsonEncode(<String, dynamic>{'error': 'weak_password'}),
              400,
            );
          }
          return http.Response(jsonEncode(me(mustChangePassword: true)), 200);
        },
      );

      container.read(membershipControllerProvider);
      await settle();
      await container
          .read(membershipControllerProvider.notifier)
          .changePassword('brand-new-pass', 'brand-new-pass');

      expect(
        container.read(membershipControllerProvider).error,
        MembershipError.weakPassword,
      );
      expect(
        container.read(membershipControllerProvider).phase,
        AuthPhase.mustChangePassword,
      );
    });
  });
}
