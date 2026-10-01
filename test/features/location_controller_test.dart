import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass/app_providers.dart';
import 'package:tshk_compass/core/geo/coordinates.dart';
import 'package:tshk_compass/data/repositories/location_repository.dart';
import 'package:tshk_compass/features/location/location_controller.dart';

import '../support/compass_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLocationRepository repository;
  late ProviderContainer container;
  late LocationController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    repository = FakeLocationRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        locationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    controller = container.read(locationControllerProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await flushStreams();
    await repository.controller.close();
  });
  LocationState state() => container.read(locationControllerProvider);
  final DateTime origin = DateTime.utc(2026, 1, 1);
  GeoPoint fix(int seconds) => GeoPoint(
    latitude: -26,
    longitude: 28,
    timestamp: origin.add(Duration(seconds: seconds)),
    accuracyMetres: 5,
  );

  test(
    'concurrent requests share permission and startup, including a pending first fix',
    () async {
      repository.permissionRequest = Completer<LocationAccess>();
      repository.currentRequest = Completer<GeoPoint?>();
      final Future<LocationAccess> first = controller.startTracking();
      expect(identical(first, controller.startTracking()), isTrue);
      expect(repository.accessRequests, 1);
      repository.permissionRequest!.complete(LocationAccess.whileInUse);
      await flushStreams();
      expect(state().tracking, isTrue);
      expect(identical(first, controller.startTracking()), isTrue);
      repository.currentRequest!.complete(fix(0));
      await first;
      expect(state().gpsPoint, fix(0));
    },
  );
  test(
    'stop during permission acquisition cannot subscribe after the answer arrives',
    () async {
      repository.permissionRequest = Completer<LocationAccess>();
      final Future<LocationAccess> pending = controller.startTracking();
      controller.stopTracking();
      repository.permissionRequest!.complete(LocationAccess.whileInUse);
      await pending;
      await flushStreams();
      expect(state().tracking, isFalse);
      expect(state().loading, isFalse);
      expect(repository.controller.hasListener, isFalse);
    },
  );
  test(
    'an old one-shot result never overwrites a newer streamed fix',
    () async {
      repository.currentRequest = Completer<GeoPoint?>();
      final Future<LocationAccess> pending = controller.startTracking();
      await flushStreams();
      repository.controller.add(fix(10));
      await flushStreams();
      repository.currentRequest!.complete(fix(0));
      await pending;
      expect(state().gpsPoint, fix(10));
      controller.stopTracking();
      repository.controller.add(fix(20));
      await flushStreams();
      expect(state().gpsPoint, fix(10));
    },
  );
  test(
    'manual locations are explicitly approximate and stay in control of bearings',
    () async {
      repository.current = fix(0);
      await controller.startTracking();
      await controller.useManualLocation(
        const GeoPoint(latitude: -25, longitude: 27),
        label: 'Home',
      );
      repository.controller.add(fix(20));
      await flushStreams();
      expect(state().effectivePoint!.latitude, -25);
      expect(state().effectivePoint!.isApproximate, isTrue);
      expect(state().effectivePoint!.label, 'Home');
      await controller.useLiveGps();
      expect(state().effectivePoint, fix(20));
    },
  );
  test(
    'a failed one-shot refresh clears loading rather than leaking a future error',
    () async {
      repository.currentRequest = Completer<GeoPoint?>();
      final Future<LocationAccess> pending = controller.refreshOnce();
      await flushStreams();
      repository.currentRequest!.completeError(StateError('No fix'));
      await pending;
      expect(state().loading, isFalse);
      expect(state().errorMessage, contains('No fix'));
    },
  );
  test('disposal guards permission and location futures', () async {
    repository.currentRequest = Completer<GeoPoint?>();
    final Future<LocationAccess> pending = controller.startTracking();
    await flushStreams();
    container.dispose();
    repository.currentRequest!.complete(fix(0));
    await pending;
    expect(repository.controller.hasListener, isFalse);
    // tearDown should not attempt a second container disposal.
    container = ProviderContainer();
  });
}
