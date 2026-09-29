import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/geo/coordinates.dart';
import '../../core/geo/geo_math.dart';
import '../../data/models/centre.dart';
import '../../data/repositories/centres_repository.dart';
import '../location/location_controller.dart';

/// The list of centres, loaded once from `assets/centres.json`.
final FutureProvider<List<Centre>> centresProvider =
    FutureProvider<List<Centre>>(
  (ref) => const CentresRepository().load(),
);

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
        CentreSearchController.new);

/// All centres, filtered by the search query.
final Provider<AsyncValue<List<Centre>>> filteredCentresProvider =
    Provider<AsyncValue<List<Centre>>>((ref) {
  final String query = ref.watch(centreSearchProvider);
  final AsyncValue<List<Centre>> async = ref.watch(centresProvider);
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
final Provider<NearestCentre?> nearestCentreProvider =
    Provider<NearestCentre?>((ref) {
  final GeoPoint? point = ref.watch(effectiveLocationProvider);
  final AsyncValue<List<Centre>> async = ref.watch(centresProvider);
  if (point == null) {
    return null;
  }
  return async.whenOrNull(data: (List<Centre> centres) {
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
  });
});

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
    final List<Centre> sorted = centres
        .where((Centre centre) => centre.hasCoordinates)
        .toList()
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
