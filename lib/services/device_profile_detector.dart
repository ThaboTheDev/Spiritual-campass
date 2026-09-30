import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/perf/performance_profile.dart';

/// Reads the hardware facts the performance profile needs, once, at startup.
///
/// Never throws: any plugin problem yields [DeviceClass.unknown] (= normal
/// profile), so the app cannot fail to start because of device detection.
abstract final class DeviceProfileDetector {
  static Future<DeviceClass> detect({DeviceInfoPlugin? plugin}) async {
    if (kIsWeb) {
      return DeviceClass.unknown;
    }
    final DeviceInfoPlugin info = plugin ?? DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo android = await info.androidInfo;
        // device_info_plus reports physicalRamSize in megabytes; guard
        // against a future change to bytes.
        final int ram = android.physicalRamSize;
        final int ramMb = ram > 1000000 ? ram ~/ (1024 * 1024) : ram;
        return DeviceClass(
          isAndroid: true,
          androidSdkInt: android.version.sdkInt,
          isLowRamDevice: android.isLowRamDevice,
          totalRamMb: ramMb > 0 ? ramMb : null,
        );
      }
      if (Platform.isIOS) {
        final IosDeviceInfo ios = await info.iosInfo;
        return DeviceClass(
          isIos: true,
          iosMachine: ios.utsname.machine,
        );
      }
    } catch (error, stack) {
      debugPrint('Device detection failed, assuming a normal phone: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 5);
    }
    return DeviceClass.unknown;
  }
}
