import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tshk_compass/features/membership/membership_api.dart';
import 'package:tshk_compass/features/membership/membership_models.dart';

/// The auth layer is the one place a wrong answer locks a member out of the
/// whole app, so every error shape GoTrue has used is pinned here.
void main() {
  group('mapSupabaseAuthError', () {
    test('modern error_code wins', () {
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }),
        AuthErrorKind.invalidCredentials,
      );
    });

    test('email not confirmed is checked before the credentials case', () {
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'error': 'invalid_grant',
          'error_description': 'Email not confirmed',
        }),
        AuthErrorKind.emailNotConfirmed,
      );
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'error_code': 'email_not_confirmed',
        }),
        AuthErrorKind.emailNotConfirmed,
      );
    });

    test('older invalid_grant without a message is bad credentials', () {
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{'error': 'invalid_grant'}),
        AuthErrorKind.invalidCredentials,
      );
    });

    test('already registered, in both shapes', () {
      expect(
        mapSupabaseAuthError(422, <String, dynamic>{
          'error_code': 'user_already_exists',
        }),
        AuthErrorKind.alreadyRegistered,
      );
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'msg': 'User already registered',
        }),
        AuthErrorKind.alreadyRegistered,
      );
    });

    test('weak password, in both shapes', () {
      expect(
        mapSupabaseAuthError(422, <String, dynamic>{
          'error_code': 'weak_password',
        }),
        AuthErrorKind.weakPassword,
      );
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'msg': 'Password should be at least 8 characters',
        }),
        AuthErrorKind.weakPassword,
      );
    });

    test('429 and rate-limit texts', () {
      expect(
        mapSupabaseAuthError(429, const <String, dynamic>{}),
        AuthErrorKind.rateLimited,
      );
      expect(
        mapSupabaseAuthError(400, <String, dynamic>{
          'msg': 'Email rate limit exceeded',
        }),
        AuthErrorKind.rateLimited,
      );
    });

    test('5xx is a server error, anything else unknown', () {
      expect(
        mapSupabaseAuthError(503, const <String, dynamic>{}),
        AuthErrorKind.server,
      );
      expect(
        mapSupabaseAuthError(418, <String, dynamic>{'msg': 'teapot'}),
        AuthErrorKind.unknown,
      );
    });
  });

  group('SupabaseAuthClient', () {
    SupabaseAuthClient clientReturning(
      http.Response Function(http.Request request) handler,
    ) =>
        SupabaseAuthClient(
          client: MockClient((http.Request request) async => handler(request)),
          baseUrl: 'https://project.supabase.co',
          anonKey: 'anon-key',
          siteUrl: 'https://example.org',
        );

    test('sign-in returns a session and remembers the user id', () async {
      final SupabaseAuthClient auth = clientReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 3600,
            'user': <String, dynamic>{
              'id': 'user-1',
              'email': 'member@example.org',
            },
          }),
          200,
        ),
      );

      final AuthSession session =
          await auth.signInWithPassword('member@example.org', 'secret123');

      expect(session.accessToken, 'at');
      expect(session.refreshToken, 'rt');
      expect(session.userId, 'user-1');
      expect(session.email, 'member@example.org');
      expect(session.isValid, isTrue);
    });

    test('sign-in posts to the password grant with the anon key', () async {
      late final http.Request seen;
      final SupabaseAuthClient auth = clientReturning((http.Request request) {
        seen = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 60,
          }),
          200,
        );
      });

      await auth.signInWithPassword('member@example.org', 'secret123');

      expect(seen.url.path, '/auth/v1/token');
      expect(seen.url.queryParameters['grant_type'], 'password');
      expect(seen.headers['apikey'], 'anon-key');
    });

    test('bad credentials become an AuthException', () async {
      final SupabaseAuthClient auth = clientReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error_code': 'invalid_credentials'}),
          400,
        ),
      );

      await expectLater(
        auth.signInWithPassword('member@example.org', 'nope'),
        throwsA(
          isA<AuthException>().having(
            (AuthException e) => e.kind,
            'kind',
            AuthErrorKind.invalidCredentials,
          ),
        ),
      );
    });

    test('a network failure is MembershipOffline, not an auth failure', () async {
      final SupabaseAuthClient auth = SupabaseAuthClient(
        client: MockClient((http.Request request) async {
          throw http.ClientException('no route to host');
        }),
        baseUrl: 'https://project.supabase.co',
        anonKey: 'anon-key',
      );

      await expectLater(
        auth.signInWithPassword('member@example.org', 'secret123'),
        throwsA(isA<MembershipOffline>()),
      );
    });

    test('sign-up with confirmation on has no session', () async {
      final SupabaseAuthClient auth = clientReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'id': 'user-2',
            'email': 'new@example.org',
            'confirmation_sent_at': '2026-01-01T00:00:00Z',
          }),
          200,
        ),
      );

      final SignUpResult result =
          await auth.signUp('new@example.org', 'secret123');

      expect(result.needsConfirmation, isTrue);
      expect(result.session, isNull);
      expect(result.email, 'new@example.org');
    });

    test('sign-up with confirmation off returns the session', () async {
      final SupabaseAuthClient auth = clientReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 3600,
            'user': <String, dynamic>{'id': 'u', 'email': 'new@example.org'},
          }),
          200,
        ),
      );

      final SignUpResult result =
          await auth.signUp('new@example.org', 'secret123');

      expect(result.needsConfirmation, isFalse);
      expect(result.session!.accessToken, 'at');
    });

    test('resend asks for the signup mail again', () async {
      late final http.Request seen;
      final SupabaseAuthClient auth = clientReturning((http.Request request) {
        seen = request;
        return http.Response('{}', 200);
      });

      await auth.resendConfirmation('member@example.org');

      expect(seen.url.path, '/auth/v1/resend');
      expect(
        jsonDecode(seen.body),
        <String, dynamic>{'type': 'signup', 'email': 'member@example.org'},
      );
    });

    test('recover points at {siteUrl}/reset', () async {
      late final http.Request seen;
      final SupabaseAuthClient auth = clientReturning((http.Request request) {
        seen = request;
        return http.Response('{}', 200);
      });

      await auth.recover('member@example.org');

      expect(seen.url.path, '/auth/v1/recover');
      expect(
        seen.url.queryParameters['redirect_to'],
        'https://example.org/reset',
      );
    });

    test('a rejected refresh token surfaces its 4xx status', () async {
      final SupabaseAuthClient auth = clientReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'invalid_grant'}),
          400,
        ),
      );

      await expectLater(
        auth.refresh(
          AuthSession(
            accessToken: 'old',
            refreshToken: 'rt',
            expiresAt: DateTime.utc(2020),
            email: 'member@example.org',
          ),
        ),
        throwsA(
          isA<MembershipApiException>().having(
            (MembershipApiException e) => e.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });

    test('a refresh that times out stays offline (no sign-out)', () async {
      final SupabaseAuthClient auth = SupabaseAuthClient(
        client: MockClient((http.Request request) async {
          throw http.ClientException('timeout');
        }),
        baseUrl: 'https://project.supabase.co',
      );

      await expectLater(
        auth.refresh(
          AuthSession(
            accessToken: 'old',
            refreshToken: 'rt',
            expiresAt: DateTime.utc(2020),
            email: 'member@example.org',
          ),
        ),
        throwsA(isA<MembershipOffline>()),
      );
    });
  });

  group('MembershipApiClient', () {
    MembershipApiClient apiReturning(
      http.Response Function(http.Request request) handler,
    ) =>
        MembershipApiClient(
          client: MockClient((http.Request request) async => handler(request)),
          baseUrl: 'https://api.example.org',
        );

    test('/api/me carries the bearer token and parses the flags', () async {
      late final http.Request seen;
      final MembershipApiClient api = apiReturning((http.Request request) {
        seen = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'email': 'member@example.org',
            'state': 'trial',
            'access': true,
            'trial_days': 7,
            'ends_at': '2026-02-01T00:00:00Z',
            'is_admin': true,
            'must_change_password': false,
          }),
          200,
        );
      });

      final (Entitlement entitlement, Map<String, dynamic> raw) =
          await api.me('token-123');

      expect(seen.url.toString(), 'https://api.example.org/api/me');
      expect(seen.headers['Authorization'], 'Bearer token-123');
      expect(entitlement.state, EntitlementState.trial);
      expect(entitlement.isAdmin, isTrue);
      expect(entitlement.mustChangePassword, isFalse);
      expect(raw['email'], 'member@example.org');
    });

    test('403 password_change_required is recognised', () async {
      final MembershipApiClient api = apiReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'password_change_required'}),
          403,
        ),
      );

      try {
        await api.me('token');
        fail('expected a MembershipApiException');
      } on MembershipApiException catch (error) {
        expect(error.isPasswordChangeRequired, isTrue);
        expect(error.isUnauthorised, isFalse);
        expect(error.isAdminRequired, isFalse);
      }
    });

    test('403 admin_required is recognised separately', () async {
      final MembershipApiClient api = apiReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'admin_required'}),
          403,
        ),
      );

      try {
        await api.adminUsers('token', 'someone');
        fail('expected a MembershipApiException');
      } on MembershipApiException catch (error) {
        expect(error.isAdminRequired, isTrue);
        expect(error.isPasswordChangeRequired, isFalse);
      }
    });

    test('400 invalid_centre keeps the field list', () async {
      final MembershipApiClient api = apiReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'invalid_centre',
            'fields': <String>['lat', 'lng'],
          }),
          400,
        ),
      );

      try {
        await api.adminAddCentre(
          'token',
          region: 'Gauteng',
          name: 'Test',
          address: 'Somewhere',
          phone: '',
          lat: 999,
          lng: 999,
        );
        fail('expected a MembershipApiException');
      } on MembershipApiException catch (error) {
        expect(error.code, 'invalid_centre');
        expect(error.fields, <String>['lat', 'lng']);
      }
    });

    test('the admin search escapes the query', () async {
      late final http.Request seen;
      final MembershipApiClient api = apiReturning((http.Request request) {
        seen = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'users': <Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'u1',
                'email': 'a b@example.org',
                'status': 'active',
                'state': 'active',
              },
            ],
          }),
          200,
        );
      });

      final List<AdminUser> users = await api.adminUsers('token', 'a b@x');

      expect(seen.url.queryParameters['q'], 'a b@x');
      expect(users.single.userId, 'u1');
    });

    test('the reset-password body never leaks into toString', () async {
      final MembershipApiClient api = apiReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{
            'email': 'member@example.org',
            'temporary_password': 'Zx9-tmp-Pass',
          }),
          200,
        ),
      );

      final TemporaryPassword temp =
          await api.adminResetPassword('token', 'u1');

      expect(temp.password, 'Zx9-tmp-Pass');
      expect(temp.toString(), isNot(contains('Zx9-tmp-Pass')));
    });

    test('a 502 on delete is an exception, not a silent success', () async {
      final MembershipApiClient api = apiReturning(
        (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'payfast_cancel_failed'}),
          502,
        ),
      );

      await expectLater(
        api.adminDeleteUser('token', 'u1'),
        throwsA(
          isA<MembershipApiException>()
              .having((MembershipApiException e) => e.code, 'code',
                  'payfast_cancel_failed')
              .having((MembershipApiException e) => e.statusCode, 'status', 502),
        ),
      );
    });
  });
}
