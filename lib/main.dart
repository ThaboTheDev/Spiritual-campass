import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_providers.dart';
import 'core/l10n/app_language.dart';
import 'core/perf/performance_profile.dart';
import 'data/local/preferences_store.dart';
import 'services/device_profile_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts are bundled under assets/fonts; never fetch them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // The compass and the dial are designed for portrait.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Secondary-language table (isiZulu / Portuguese / Chichewa / Bemba).
  // A missing or corrupt file leaves the authored isiZulu strings in place.
  try {
    L10n.install(
      Translations.parse(await rootBundle.loadString('assets/translations.json')),
    );
  } catch (_) {
    L10n.install(const Translations.empty());
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Hardware class → performance profile. Never throws.
  final DeviceClass device = await DeviceProfileDetector.detect();
  final PerformanceProfile profile = resolveProfile(
    device: device,
    simpleModeForced: PreferencesStore(preferences).simpleMode,
  );
  final PerfSettings perf = PerfSettings.of(profile);
  PaintingBinding.instance.imageCache
    ..maximumSize = perf.imageCacheMaxImages
    ..maximumSizeBytes = perf.imageCacheMaxBytes;

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(preferences),
        deviceClassProvider.overrideWithValue(device),
      ],
      child: const TshkApp(),
    ),
  );
}
