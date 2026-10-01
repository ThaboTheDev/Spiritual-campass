import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../data/models/centre.dart';
import '../../data/repositories/centres_repository.dart';
import '../location/location_controller.dart';
import '../membership/membership_api.dart';
import '../membership/membership_controller.dart';

/// `GET /api/centres` plus the app-private offline cache.
final Provider<CentresRepository> centresRepositoryProvider =
    Provider<CentresRepository>(
      (ref) => CentresRepository(
        api: ref.watch(membershipApiClientProvider),
        cache: ref.watch(centresCacheProvider),
      ),
    );

/// The centres, downloaded after login and cached for offline use.
///
/// Rebuilds when the gate's phase changes, so logging out empties the list
/// and the next login downloads it again. The list is never bundled with the
/// app: that is the whole point of keeping it on the server.
class CentresController extends AsyncNotifier<CentresData> {
  @override
  Future<CentresData> build() {
    ref.watch(
      membershipControllerProvider.select((MembershipState s) => s.phase),
    );
    return _load();
  }

  /// Downloads the list again (after login, or after an admin added a centre).
  Future<void> refresh() async {
    state = const AsyncValue<CentresData>.loading();
    state = await AsyncValue.guard<CentresData>(_load);
  }

  Future<CentresData> _load() async {
    final CentresRepository repository = ref.read(centresRepositoryProvider);
    final MembershipController membership = ref.read(
      membershipControllerProvider.notifier,
    );

    final String? token = await membership.currentAccessToken();
    if (token == null) {
      // Signed out, or offline with an expired access token: the cache is
      // all we have.
      return await repository.readCache() ?? CentresData.empty;
    }

    try {
      return await repository.fetchRemote(token);
    } on MembershipOffline {
      final CentresData? cached = await repository.readCache();
      return (cached ?? CentresData.empty).copyWith(offline: true);
    } on MembershipApiException catch (error) {
      if (error.isUnauthorised || error.isSubscriptionRequired) {
        // The server has withdrawn the list: drop the copy on the device and
        // let the gate work out what to show. The re-check is deliberately
        // not awaited — it changes the phase this provider watches.
        await repository.clearCache();
        Future<void>.microtask(
          () => membership.refreshEntitlement(silent: true),
        );
        return const CentresData(blocked: true);
      }
      if (error.isPasswordChangeRequired) {
        Future<void>.microtask(
          () => membership.refreshEntitlement(silent: true),
        );
        return const CentresData(blocked: true);
      }
      final CentresData? cached = await repository.readCache();
      return (cached ?? CentresData.empty).copyWith(offline: true);
    }
  }
}

/// The centres (server or cache) for the Centres tab and the location picker.
final AsyncNotifierProvider<CentresController, CentresData> centresProvider =
    AsyncNotifierProvider<CentresController, CentresData>(
      CentresController.new,
    );

/// Just the list, for the many places that do not care where it came from.
final Provider<AsyncValue<List<Centre>>> centresListProvider =
    Provider<AsyncValue<List<Centre>>>((ref) {
      return ref
          .watch(centresProvider)
          .whenData((CentresData data) => data.centres);
    });

/// The search box text on the Centres tab.
class CentreSearchController extends Notifier<String> {
  @override
  String build() => '';

  /// Sets the query.
  void update(String value) => state = value;

  /// Clears the query.
  void clear() => state = '';
}

/// Current search query (name, town, address or region).
final NotifierProvider<CentreSearchController, String> centreSearchProvider =
    NotifierProvider<CentreSearchController, String>(
      CentreSearchController.new,
    );

/// All centres, filtered by the search query.
final Provider<AsyncValue<List<Centre>>> filteredCentresProvider =
    Provider<AsyncValue<List<Centre>>>((ref) {
      final String query = ref.watch(centreSearchProvider);
      final AsyncValue<List<Centre>> async = ref.watch(centresListProvider);
      final String needle = query.trim().toLowerCase();
      return async.whenData(
        (List<Centre> centres) => needle.isEmpty
            ? centres
            : centres
                  .where((Centre centre) => centre.matches(needle))
                  .toList(growable: false),
      );
    });

/// The filtered centres grouped by region, ready for the list view.
final Provider<AsyncValue<List<RegionGroup>>> regionGroupsProvider =
    Provider<AsyncValue<List<RegionGroup>>>((ref) {
      final AsyncValue<List<Centre>> async = ref.watch(filteredCentresProvider);
      return async.whenData(CentresRepository.groupByRegion);
    });

/// The centre closest to the user, with its distance, or `null`.
final Provider<NearestCentre?> nearestCentreProvider = Provider<NearestCentre?>(
  (ref) {
    final GeoPoint? point = ref.watch(effectiveLocationProvider);
    final AsyncValue<List<Centre>> async = ref.watch(centresListProvider);
    if (point == null) {
      return null;
    }
    return async.whenOrNull(
      data: (List<Centre> centres) {
        NearestCentre? best;
        for (final Centre centre in centres) {
          final GeoPoint? target = centre.point;
          if (target == null) {
            continue;
          }
          final double distance = GeoMath.distanceBetweenKm(point, target);
          if (best == null || distance < best.distanceKm) {
            best = NearestCentre(centre: centre, distanceKm: distance);
          }
        }
        return best;
      },
    );
  },
);

/// A centre and how far the user is from it.
class NearestCentre {
  const NearestCentre({required this.centre, required this.distanceKm});

  /// The centre.
  final Centre centre;

  /// Great-circle distance from the user, in kilometres.
  final double distanceKm;
}

/// Sorted "closest first" list, used when the Nearest button is pressed.
final Provider<AsyncValue<List<Centre>>> centresByDistanceProvider =
    Provider<AsyncValue<List<Centre>>>((ref) {
      final GeoPoint? point = ref.watch(effectiveLocationProvider);
      final AsyncValue<List<Centre>> async = ref.watch(filteredCentresProvider);
      if (point == null) {
        return async;
      }
      return async.whenData((List<Centre> centres) {
        final List<Centre> sorted =
            centres.where((Centre centre) => centre.hasCoordinates).toList()
              ..sort((Centre a, Centre b) {
                final double da = GeoMath.distanceBetweenKm(point, a.point!);
                final double db = GeoMath.distanceBetweenKm(point, b.point!);
                return da.compareTo(db);
              });
        // Centres without coordinates stay at the end, in name order.
        final List<Centre> withoutCoordinates = centres
            .where((Centre centre) => !centre.hasCoordinates)
            .toList();
        return <Centre>[...sorted, ...withoutCoordinates];
      });
    });

/// Whether the map can reach the internet for its tiles.
final FutureProvider<bool> onlineProvider = FutureProvider<bool>((ref) {
  return ref.watch(connectivityProbeProvider).check();
});
