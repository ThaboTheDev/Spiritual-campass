/// How much rendering work the app allows itself.
enum PerformanceProfile {
  /// Android 7 era phones with 1 – 2 GB of RAM, `isLowRamDevice`, or the
  /// user's "Battery saver / Simple mode" switch.
  low,

  /// Everything else.
  normal,
}

/// What the app learnt about the hardware at startup (device_info_plus).
///
/// Immutable and trivially constructible so tests can describe any phone.
class DeviceClass {
  const DeviceClass({
    this.isAndroid = false,
    this.isIos = false,
    this.androidSdkInt,
    this.isLowRamDevice = false,
    this.totalRamMb,
    this.iosMachine,
  });

  /// Unknown hardware (tests, desktop): treated as normal.
  static const DeviceClass unknown = DeviceClass();

  final bool isAndroid;
  final bool isIos;

  /// `Build.VERSION.SDK_INT`, Android only.
  final int? androidSdkInt;

  /// `ActivityManager.isLowRamDevice()`, Android only.
  final bool isLowRamDevice;

  /// Physical RAM in MB when the platform reports it.
  final int? totalRamMb;

  /// e.g. `iPhone8,1` (iPhone 6s). iOS only.
  final String? iosMachine;

  /// Older iPhones / iPads that still run iOS 13 – 15 with 1 – 2 GB of RAM.
  static const Set<String> lowEndIosMachines = <String>{
    // iPhone 6s / 6s Plus / SE (1st gen) — 2 GB, iOS 15 max.
    'iPhone8,1', 'iPhone8,2', 'iPhone8,4',
    // iPhone 7 / 7 Plus — 2 / 3 GB, iOS 15 max.
    'iPhone9,1', 'iPhone9,3', 'iPhone9,2', 'iPhone9,4',
    // iPod touch 7 — 2 GB.
    'iPod9,1',
    // iPad mini 4, iPad Air 2, iPad 5 — 2 GB.
    'iPad5,1', 'iPad5,2', 'iPad5,3', 'iPad5,4', 'iPad6,11', 'iPad6,12',
  };

  /// The profile the hardware suggests.
  PerformanceProfile get suggestedProfile {
    if (isAndroid) {
      if (isLowRamDevice) {
        return PerformanceProfile.low;
      }
      final int? ram = totalRamMb;
      if (ram != null && ram > 0 && ram <= 2048) {
        return PerformanceProfile.low;
      }
      final int? sdk = androidSdkInt;
      // Android 7.x / 8.0 phones are almost all 1 – 2 GB devices by now.
      if (sdk != null && sdk <= 26) {
        return PerformanceProfile.low;
      }
      return PerformanceProfile.normal;
    }
    if (isIos) {
      final String? machine = iosMachine;
      if (machine != null && lowEndIosMachines.contains(machine)) {
        return PerformanceProfile.low;
      }
      return PerformanceProfile.normal;
    }
    return PerformanceProfile.normal;
  }

  @override
  String toString() =>
      'DeviceClass(android: $isAndroid sdk $androidSdkInt lowRam $isLowRamDevice '
      'ram ${totalRamMb}MB, ios: $isIos $iosMachine)';
}

/// Resolves the effective profile from the hardware and the user's switch.
///
/// The switch can only force *low*; it never overrides a low-end detection
/// upwards, because the point of the profile is to keep those phones usable.
PerformanceProfile resolveProfile({
  required DeviceClass device,
  required bool simpleModeForced,
}) {
  if (simpleModeForced) {
    return PerformanceProfile.low;
  }
  return device.suggestedProfile;
}

/// Concrete knobs derived from a [PerformanceProfile].
class PerfSettings {
  const PerfSettings._({
    required this.profile,
    required this.arrowFrameInterval,
    required this.useGradients,
    required this.useShadows,
    required this.animate,
    required this.imageCacheMaxBytes,
    required this.imageCacheMaxImages,
    required this.clusterRadius,
    required this.clusterMaxZoom,
    required this.tileCacheEnabled,
    required this.sensorInterval,
  });

  /// The profile these settings came from.
  final PerformanceProfile profile;

  /// Minimum time between dial updates (~15 fps low, ~30 fps normal).
  final Duration arrowFrameInterval;

  /// Whether painters may use gradients / blur.
  final bool useGradients;

  /// Whether cards may cast shadows / halos.
  final bool useShadows;

  /// Whether implicit animations run (tab highlight, banners).
  final bool animate;

  /// `PaintingBinding.imageCache.maximumSizeBytes`.
  final int imageCacheMaxBytes;

  /// `PaintingBinding.imageCache.maximumSize`.
  final int imageCacheMaxImages;

  /// Marker cluster radius in pixels: lower = clusters break up sooner, fewer
  /// overlapping markers on screen at once.
  final int clusterRadius;

  /// Zoom above which clustering stops.
  final int clusterMaxZoom;

  /// Whether the map keeps an on-disk tile cache.
  final bool tileCacheEnabled;

  /// Sensor sampling period.
  final Duration sensorInterval;

  /// Whether this is the low profile.
  bool get isLow => profile == PerformanceProfile.low;

  static const PerfSettings low = PerfSettings._(
    profile: PerformanceProfile.low,
    arrowFrameInterval: Duration(milliseconds: 66),
    useGradients: false,
    useShadows: false,
    animate: false,
    imageCacheMaxBytes: 16 << 20, // 16 MB
    imageCacheMaxImages: 40,
    clusterRadius: 30,
    clusterMaxZoom: 13,
    tileCacheEnabled: false,
    sensorInterval: Duration(milliseconds: 66),
  );

  static const PerfSettings normal = PerfSettings._(
    profile: PerformanceProfile.normal,
    arrowFrameInterval: Duration(milliseconds: 33),
    useGradients: true,
    useShadows: true,
    animate: true,
    imageCacheMaxBytes: 48 << 20, // 48 MB
    imageCacheMaxImages: 200,
    clusterRadius: 45,
    clusterMaxZoom: 15,
    tileCacheEnabled: true,
    sensorInterval: Duration(milliseconds: 40),
  );

  /// Settings for a profile.
  static PerfSettings of(PerformanceProfile profile) =>
      profile == PerformanceProfile.low ? low : normal;
}
