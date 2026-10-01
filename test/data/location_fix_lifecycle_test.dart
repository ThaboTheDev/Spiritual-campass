import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/data/repositories/location_repository.dart';

class ManagedFixRepository extends GeolocatorLocationRepository {
  final StreamController<GeoPoint> points =
      StreamController<GeoPoint>.broadcast();
  @override
  Stream<GeoPoint> get positionStream => points.stream;
}

void main() {
  test(
    'one-shot requests coalesce and stop cancels the owned native listener',
    () async {
      final ManagedFixRepository repository = ManagedFixRepository();
      final Future<GeoPoint?> first = repository.getCurrentPoint();
      expect(identical(first, repository.getCurrentPoint()), isTrue);
      expect(repository.points.hasListener, isTrue);
      repository.cancelPendingFixes();
      expect(await first, isNull);
      expect(repository.points.hasListener, isFalse);
      await repository.points.close();
    },
  );
  test('the first fix releases the temporary subscription', () async {
    final ManagedFixRepository repository = ManagedFixRepository();
    final Future<GeoPoint?> pending = repository.getCurrentPoint();
    const GeoPoint point = GeoPoint(latitude: -26, longitude: 28);
    repository.points.add(point);
    expect(await pending, point);
    expect(repository.points.hasListener, isFalse);
    await repository.points.close();
  });
  test('timeout cancels the subscription, not just its waiting future', () {
    fakeAsync((FakeAsync a) {
      final ManagedFixRepository repository = ManagedFixRepository();
      bool completed = false;
      repository.getCurrentPoint().then((GeoPoint? point) {
        expect(point, isNull);
        completed = true;
      });
      a.elapse(const Duration(seconds: 25));
      a.flushMicrotasks();
      expect(completed, isTrue);
      expect(repository.points.hasListener, isFalse);
      repository.points.close();
      a.flushMicrotasks();
    });
  });
}
