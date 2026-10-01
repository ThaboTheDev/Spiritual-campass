import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tshk_compass/data/local/centres_cache.dart';
import 'package:tshk_compass/data/models/centre.dart';
import 'package:tshk_compass/data/repositories/centres_repository.dart';
import 'package:tshk_compass/features/membership/membership_api.dart';

/// `GET /api/centres` answers with the terse wire format; the list, the
/// sorting and the offline cache are all tested from it.
const Map<String, dynamic> _body = <String, dynamic>{
  'regions': <String>['Gauteng', 'KwaZulu-Natal', 'Free State'],
  'centres': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'gauteng-pretoria',
      'r': 'Gauteng',
      'n': 'Pretoria',
      'a': 'Cnr Bloed & Bosman Street, Pretoria',
      'p': '+27 81 032 3331',
      'la': -25.7461,
      'lo': 28.1881,
    },
    <String, dynamic>{
      'id': 'gauteng-ebhubesini',
      'r': 'Gauteng',
      'n': 'eBhubesini',
      'a': '10 Small Street, Marshalltown, Johannesburg',
      'p': '+27 67 300 3886',
      'la': -26.2056,
      'lo': 28.0456,
    },
    <String, dynamic>{
      'id': 'kzn-durban',
      'r': 'KwaZulu-Natal',
      'n': 'Durban',
      'a': '1 Point Road, Durban',
      'p': '+27 31 000 0000',
      'la': -29.8579,
      'lo': 31.0292,
    },
    <String, dynamic>{
      'id': 'fs-bloem',
      'r': 'Free State',
      'n': 'Bloemfontein',
      'a': '',
      'p': '',
      'la': null,
      'lo': null,
    },
  ],
};

CentresRepository repositoryWith({
  required http.Response Function(http.Request request) handler,
  CentresCache? cache,
}) =>
    CentresRepository(
      api: MembershipApiClient(
        client: MockClient((http.Request request) async => handler(request)),
        baseUrl: 'https://api.example.org',
      ),
      cache: cache ?? MemoryCentresCache(),
    );

void main() {
  group('parseRemote', () {
    test('reads every centre and maps the short field names', () {
      final CentresData data = CentresRepository.parseRemote(_body);

      expect(data.centres, hasLength(4));
      final Centre centre = data.centres
          .firstWhere((Centre c) => c.id == 'gauteng-ebhubesini');
      expect(centre.name, 'eBhubesini');
      expect(centre.region, 'Gauteng');
      expect(centre.address, '10 Small Street, Marshalltown, Johannesburg');
      expect(centre.phone, '+27 67 300 3886');
      expect(centre.lat, -26.2056);
      expect(centre.lng, 28.0456);
      expect(centre.hasCoordinates, isTrue);
      expect(centre.point!.latitude, -26.2056);
    });

    test('sorts by region then name', () {
      final List<Centre> centres = CentresRepository.parseRemote(_body).centres;

      expect(centres.first.region, 'Free State');
      expect(centres[1].name, 'eBhubesini');
      expect(centres[2].name, 'Pretoria');
      expect(centres.last.region, 'KwaZulu-Natal');
    });

    test('keeps the regions the server sent', () {
      expect(
        CentresRepository.parseRemote(_body).regions,
        <String>['Free State', 'Gauteng', 'KwaZulu-Natal'],
      );
    });

    test('falls back to the regions found in the list', () {
      final CentresData data =
          CentresRepository.parseRemote(<String, dynamic>{
        'centres': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'a', 'r': 'Limpopo', 'n': 'A'},
        ],
      });

      expect(data.regions, <String>['Limpopo']);
    });

    test('a centre without coordinates still lists', () {
      final Centre centre = CentresRepository.parseRemote(_body)
          .centres
          .firstWhere((Centre c) => c.id == 'fs-bloem');

      expect(centre.hasCoordinates, isFalse);
      expect(centre.point, isNull);
      expect(centre.hasAddress, isFalse);
      expect(centre.hasPhone, isFalse);
    });

    test('an unreadable row is skipped, the rest still show', () {
      final CentresData data =
          CentresRepository.parseRemote(<String, dynamic>{
        'centres': <Object>[
          'rubbish',
          <String, dynamic>{'id': 'x', 'r': 'Gauteng'},
          <String, dynamic>{'id': 'y', 'r': 'Gauteng', 'n': 'Good'},
        ],
      });

      expect(data.centres, hasLength(1));
      expect(data.centres.single.name, 'Good');
    });

    test('a missing id is derived from the region and the name', () {
      final CentresData data =
          CentresRepository.parseRemote(<String, dynamic>{
        'centres': <Map<String, dynamic>>[
          <String, dynamic>{'r': 'KwaZulu-Natal', 'n': 'New Place'},
        ],
      });

      expect(data.centres.single.id, 'kwazulu-natal-new-place');
    });

    test('an empty body is an empty list, not a crash', () {
      final CentresData data =
          CentresRepository.parseRemote(const <String, dynamic>{});

      expect(data.centres, isEmpty);
      expect(data.regions, isEmpty);
      expect(data.isEmpty, isTrue);
    });

    test('string coordinates are accepted', () {
      final CentresData data =
          CentresRepository.parseRemote(<String, dynamic>{
        'centres': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'a',
            'r': 'Gauteng',
            'n': 'A',
            'la': '-26.1',
            'lo': '28.2',
          },
        ],
      });

      expect(data.centres.single.lat, -26.1);
      expect(data.centres.single.lng, 28.2);
    });
  });

  group('fetchRemote', () {
    test('calls /api/centres with the bearer token and caches the body',
        () async {
      late final http.Request seen;
      final MemoryCentresCache cache = MemoryCentresCache();
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) {
          seen = request;
          return http.Response(jsonEncode(_body), 200);
        },
        cache: cache,
      );

      final CentresData data = await repository.fetchRemote('token-abc');

      expect(seen.url.toString(), 'https://api.example.org/api/centres');
      expect(seen.headers['Authorization'], 'Bearer token-abc');
      expect(data.centres, hasLength(4));
      expect(data.fromCache, isFalse);
      expect(cache.value, isNotNull);
      expect(jsonDecode(cache.value!), isA<Map<String, dynamic>>());
    });

    test('an unreachable server throws MembershipOffline', () async {
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) => throw http.ClientException('down'),
      );

      await expectLater(
        repository.fetchRemote('token'),
        throwsA(isA<MembershipOffline>()),
      );
    });

    test('402 subscription_required surfaces for the gate', () async {
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) => http.Response(
          jsonEncode(<String, dynamic>{'error': 'subscription_required'}),
          402,
        ),
      );

      await expectLater(
        repository.fetchRemote('token'),
        throwsA(
          isA<MembershipApiException>().having(
            (MembershipApiException e) => e.isSubscriptionRequired,
            'isSubscriptionRequired',
            isTrue,
          ),
        ),
      );
    });

    test('a failed fetch leaves the previous cache alone', () async {
      final MemoryCentresCache cache =
          MemoryCentresCache(jsonEncode(_body));
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) => throw http.ClientException('down'),
        cache: cache,
      );

      await expectLater(
        repository.fetchRemote('token'),
        throwsA(isA<MembershipOffline>()),
      );
      expect(cache.value, isNotNull);

      final CentresData? cached = await repository.readCache();
      expect(cached!.centres, hasLength(4));
      expect(cached.fromCache, isTrue);
    });
  });

  group('cache', () {
    test('nothing cached reads as null', () async {
      final CentresRepository repository =
          repositoryWith(handler: (http.Request request) => fail('no call'));

      expect(await repository.readCache(), isNull);
    });

    test('a corrupt cache reads as null instead of crashing', () async {
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) => fail('no call'),
        cache: MemoryCentresCache('} not json {'),
      );

      expect(await repository.readCache(), isNull);
    });

    test('clearing removes the cached list', () async {
      final MemoryCentresCache cache = MemoryCentresCache(jsonEncode(_body));
      final CentresRepository repository = repositoryWith(
        handler: (http.Request request) => fail('no call'),
        cache: cache,
      );

      await repository.clearCache();

      expect(cache.value, isNull);
      expect(await repository.readCache(), isNull);
    });
  });

  group('grouping', () {
    test('groups by region and counts', () {
      final List<RegionGroup> groups = CentresRepository.groupByRegion(
        CentresRepository.parseRemote(_body).centres,
      );

      expect(groups, hasLength(3));
      expect(groups.first.region, 'Free State');
      expect(groups.first.count, 1);
      final RegionGroup gauteng =
          groups.firstWhere((RegionGroup g) => g.region == 'Gauteng');
      expect(gauteng.count, 2);
      expect(gauteng.centres.first.name, 'eBhubesini');
    });
  });

  group('Centre.matches', () {
    final List<Centre> centres = CentresRepository.parseRemote(_body).centres;
    Centre ebhubesini() =>
        centres.firstWhere((Centre c) => c.name == 'eBhubesini');

    test('matches the name, case-insensitively', () {
      expect(ebhubesini().matches('BHUBE'), isTrue);
    });

    test('matches the address and the region', () {
      expect(ebhubesini().matches('small street'), isTrue);
      expect(ebhubesini().matches('gauteng'), isTrue);
    });

    test('an empty query matches everything', () {
      for (final Centre centre in centres) {
        expect(centre.matches('   '), isTrue);
      }
    });

    test('a miss returns false', () {
      expect(ebhubesini().matches('Cape Town'), isFalse);
    });
  });

  group('Centre json round trip', () {
    test('toJson keeps the fields the UI needs', () {
      final Centre centre = CentresRepository.parseRemote(_body)
          .centres
          .firstWhere((Centre c) => c.id == 'kzn-durban');
      final Map<String, dynamic> json = centre.toJson();

      expect(json['id'], 'kzn-durban');
      expect(json['name'], 'Durban');
      expect(json['region'], 'KwaZulu-Natal');
      expect(json['lat'], -29.8579);
      expect(json['lng'], 31.0292);
    });
  });
}
