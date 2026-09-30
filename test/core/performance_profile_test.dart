import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass/core/perf/performance_profile.dart';

void main() {
  group('DeviceClass.suggestedProfile', () {
    test('unknown hardware is normal', () {
      expect(DeviceClass.unknown.suggestedProfile, PerformanceProfile.normal);
    });

    test('Android isLowRamDevice → low', () {
      const DeviceClass d = DeviceClass(
          isAndroid: true, androidSdkInt: 30, isLowRamDevice: true, totalRamMb: 3000);
      expect(d.suggestedProfile, PerformanceProfile.low);
    });

    test('Android with 2 GB or less → low', () {
      const DeviceClass d =
          DeviceClass(isAndroid: true, androidSdkInt: 29, totalRamMb: 2048);
      expect(d.suggestedProfile, PerformanceProfile.low);
    });

    test('Android 7 / 8.0 (API ≤ 26) → low even with more RAM', () {
      const DeviceClass d =
          DeviceClass(isAndroid: true, androidSdkInt: 26, totalRamMb: 3072);
      expect(d.suggestedProfile, PerformanceProfile.low);
    });

    test('modern Android with 4 GB → normal', () {
      const DeviceClass d =
          DeviceClass(isAndroid: true, androidSdkInt: 33, totalRamMb: 4096);
      expect(d.suggestedProfile, PerformanceProfile.normal);
    });

    test('iPhone 6s → low, iPhone 12 → normal', () {
      expect(
        const DeviceClass(isIos: true, iosMachine: 'iPhone8,1').suggestedProfile,
        PerformanceProfile.low,
      );
      expect(
        const DeviceClass(isIos: true, iosMachine: 'iPhone13,2').suggestedProfile,
        PerformanceProfile.normal,
      );
    });
  });

  group('resolveProfile', () {
    test('Simple mode forces low', () {
      expect(
        resolveProfile(device: DeviceClass.unknown, simpleModeForced: true),
        PerformanceProfile.low,
      );
    });

    test('otherwise follows the hardware', () {
      expect(
        resolveProfile(device: DeviceClass.unknown, simpleModeForced: false),
        PerformanceProfile.normal,
      );
    });
  });

  group('PerfSettings', () {
    test('low profile: 15 fps arrow, no gradients/shadows, smaller caches', () {
      final PerfSettings low = PerfSettings.of(PerformanceProfile.low);
      final PerfSettings normal = PerfSettings.of(PerformanceProfile.normal);
      expect(low.arrowFrameInterval.inMilliseconds, greaterThanOrEqualTo(60));
      expect(normal.arrowFrameInterval.inMilliseconds, lessThanOrEqualTo(40));
      expect(low.useGradients, isFalse);
      expect(low.useShadows, isFalse);
      expect(low.animate, isFalse);
      expect(low.tileCacheEnabled, isFalse);
      expect(normal.tileCacheEnabled, isTrue);
      expect(low.imageCacheMaxBytes, lessThan(normal.imageCacheMaxBytes));
      expect(low.imageCacheMaxImages, lessThan(normal.imageCacheMaxImages));
      expect(low.clusterRadius, lessThan(normal.clusterRadius));
      expect(low.clusterMaxZoom, lessThan(normal.clusterMaxZoom));
    });
  });
}
