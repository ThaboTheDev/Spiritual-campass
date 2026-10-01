import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/data/local/centres_cache.dart';
import 'package:tshk_compass/data/local/preferences_store.dart';
import 'package:tshk_compass/features/membership/admin/admin_controller.dart';
import 'package:tshk_compass/features/membership/membership_api.dart';
import 'package:tshk_compass/features/membership/membership_controller.dart';
import 'package:tshk_compass/features/membership/membership_models.dart';
import 'package:tshk_compass/features/membership/session_store.dart';

/// The admin tools: the server is the authority, and the generated password
/// must never be kept anywhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AuthSession session() => AuthSession(
        accessToken: 'at',
        refreshToken: 'rt',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        email: 'admin@example.org',
        userId: 'admin-1',
      );

  Future<(ProviderContainer, SharedPreferences)> harness(
    http.Response Function(http.Request request) api,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SharedPreferences raw = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(PreferencesStore(raw)),
        centresCacheProvider.overrideWithValue(MemoryCentresCache()),
        sessionStoreProvider
            .overrideWithValue(MemorySessionStore()..session = session()),
        membershipApiClientProvider.overrideWithValue(
          MembershipApiClient(
            client: MockClient((http.Request request) async => api(request)),
            baseUrl: 'https://api.example.org',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Let the membership controller restore its session first: the admin
    // controller asks it for the access token.
    container.read(membershipControllerProvider);
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return (container, raw);
  }

  Map<String, dynamic> me() => <String, dynamic>{
        'email': 'admin@example.org',
        'state': 'active',
        'access': true,
        'is_admin': true,
      };

  test('search returns the users the server sent', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'u1',
                'email': 'someone@example.org',
                'status': 'active',
                'state': 'active',
              },
            ],
          }),
          200,
        );
      },
    );

    await container.read(adminControllerProvider.notifier).searchUsers('some');

    final AdminState state = container.read(adminControllerProvider);
    expect(state.users.single.email, 'someone@example.org');
    expect(state.searched, isTrue);
    expect(state.error, AdminError.none);
  });

  test('403 admin_required is reported, not swallowed', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'admin_required'}),
          403,
        );
      },
    );

    await container.read(adminControllerProvider.notifier).searchUsers('x');

    expect(
      container.read(adminControllerProvider).error,
      AdminError.forbidden,
    );
  });

  test('a duplicate centre is its own message', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'duplicate_centre'}),
          409,
        );
      },
    );

    final bool added =
        await container.read(adminControllerProvider.notifier).addCentre(
              region: 'Gauteng',
              name: 'Pretoria',
              address: 'Somewhere',
              phone: '',
              lat: -25.7,
              lng: 28.1,
            );

    expect(added, isFalse);
    expect(
      container.read(adminControllerProvider).error,
      AdminError.duplicateCentre,
    );
  });

  test('invalid_centre keeps the fields the server flagged', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'invalid_centre',
            'fields': <String>['address'],
          }),
          400,
        );
      },
    );

    await container.read(adminControllerProvider.notifier).addCentre(
          region: 'Gauteng',
          name: 'Pretoria',
          address: '',
          phone: '',
          lat: -25.7,
          lng: 28.1,
        );

    final AdminState state = container.read(adminControllerProvider);
    expect(state.error, AdminError.invalidCentre);
    expect(state.invalidFields, <String>['address']);
  });

  test('a generated password is returned but never stored', () async {
    const String secret = 'Tmp-9f2k-Pass';
    final (ProviderContainer container, SharedPreferences prefs) =
        await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        if (request.url.path == '/api/admin/users') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'users': <Map<String, dynamic>>[
                <String, dynamic>{
                  'user_id': 'u1',
                  'email': 'someone@example.org',
                  'status': 'active',
                  'state': 'active',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'email': 'someone@example.org',
            'temporary_password': secret,
          }),
          200,
        );
      },
    );

    final AdminController admin = container.read(adminControllerProvider.notifier);
    await admin.searchUsers('someone');
    admin.select(container.read(adminControllerProvider).users.single);

    final TemporaryPassword? temp = await admin.generateTemporaryPassword();

    expect(temp, isNotNull);
    expect(temp!.password, secret);
    // Nothing in the state and nothing on disk may hold it.
    for (final String key in prefs.getKeys()) {
      expect(prefs.get(key).toString(), isNot(contains(secret)));
    }
    expect(
      jsonEncode(<String, dynamic>{
        'error': container.read(adminControllerProvider).error.name,
        'users': container
            .read(adminControllerProvider)
            .users
            .map((AdminUser u) => u.email)
            .toList(),
        'selected': container.read(adminControllerProvider).selected?.email,
      }),
      isNot(contains(secret)),
    );
  });

  test('deleting a user removes them from the list', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        if (request.url.path == '/api/admin/users') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'users': <Map<String, dynamic>>[
                <String, dynamic>{
                  'user_id': 'u1',
                  'email': 'someone@example.org',
                  'status': 'active',
                  'state': 'active',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'ok': true,
            'subscription_cancelled': true,
          }),
          200,
        );
      },
    );

    final AdminController admin =
        container.read(adminControllerProvider.notifier);
    await admin.searchUsers('someone');
    admin.select(container.read(adminControllerProvider).users.single);

    final bool deleted = await admin.deleteSelectedUser();

    final AdminState state = container.read(adminControllerProvider);
    expect(deleted, isTrue);
    expect(state.users, isEmpty);
    expect(state.deletedEmail, 'someone@example.org');
    expect(state.deletedSubscriptionCancelled, isTrue);
    expect(state.selected, isNull);
  });

  test('cannot_delete_self stops the delete', () async {
    final (ProviderContainer container, _) = await harness(
      (http.Request request) {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(me()), 200);
        }
        if (request.url.path == '/api/admin/users') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'users': <Map<String, dynamic>>[
                <String, dynamic>{
                  'user_id': 'admin-1',
                  'email': 'admin@example.org',
                  'status': 'active',
                  'state': 'active',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'error': 'cannot_delete_self'}),
          409,
        );
      },
    );

    final AdminController admin =
        container.read(adminControllerProvider.notifier);
    await admin.searchUsers('admin');
    admin.select(container.read(adminControllerProvider).users.single);

    final bool deleted = await admin.deleteSelectedUser();

    final AdminState state = container.read(adminControllerProvider);
    expect(deleted, isFalse);
    expect(state.error, AdminError.cannotDeleteSelf);
    expect(state.users, hasLength(1));
  });
}
