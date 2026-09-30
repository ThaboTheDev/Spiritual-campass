# TSHK Compass

A native iOS + Android rebuild of the Ekuphumuleni compass web app, for
**Abantwana Bobukhosi Bukamoya (amasosha)** — the spiritual nation of The
Revelation Spiritual Home and The Spiritual Home Kingdom.

The app points the way to **Ekuphumuleni**, the spiritual capital, so that
prayer can face it and a msamo (umsamo) can be positioned toward it.

* Target: `29° 04′ 31.7″ S, 27° 37′ 28.3″ E` = decimal `-29.07547, 27.62453`
* Bilingual everywhere: English main, isiZulu secondary, both always visible
* Dark only, portrait only, Material 3
* Offline for the compass, the sun readouts and the guide; only the map needs the
  internet

---

## Contents

| Path | What it is |
| --- | --- |
| `lib/main.dart` | Entry point: portrait lock, `SharedPreferences`, `ProviderScope` |
| `lib/app.dart` | Root `MaterialApp` (dark theme, clamped text scale) |
| `lib/app_providers.dart` | App-wide providers (preferences, repositories, sensors, wake lock, performance profile, clock) |
| `lib/core/config/app_config.dart` | Feature flags (`kMembershipEnabled`, `kStoreBuild`), API / Supabase placeholders, tile-cache cap |
| `lib/core/l10n/strings.dart` | **Every** user-visible string: English + authored isiZulu (+ translation key) |
| `lib/core/l10n/app_language.dart` | Secondary languages (isiZulu / Portuguese / Chichewa / Bemba), `translations.json` loader, fallback |
| `lib/core/perf/performance_profile.dart` | `low` / `normal` profile and the knobs it controls |
| `lib/core/geo/heading_math.dart` | Facing math (flat → upright blend), tilt-compensated heading, gyro yaw, calibration offsets |
| `lib/core/theme/app_theme.dart` | Colours, layout constants, Material 3 dark theme |
| `lib/core/geo/coordinates.dart` | `GeoPoint`, `Angles`, the `Ekuphumuleni` constants |
| `lib/core/geo/geo_math.dart` | Great-circle bearing, haversine distance, true ↔ magnetic |
| `lib/core/geo/angle_smoother.dart` | Wrap-aware low-pass filter + UI throttle |
| `lib/core/wmm/wmm.dart` | World Magnetic Model 2025 (spherical harmonics, degree 12) |
| `lib/core/wmm/wmm_coefficients.dart` | Official NOAA/NGA WMM2025 Gauss coefficients |
| `lib/core/sun/sun_position.dart` | NOAA solar azimuth / elevation / equation of time |
| `lib/core/sun/facing_sun.dart` | "Are you facing the sun?" logic |
| `lib/core/time/decimal_year.dart` | `DateTime` ↔ decimal year (what the WMM needs) |
| `lib/core/format/formatters.dart` | Bearings, distances ("1 234 km"), DMS, coordinates |
| `lib/core/net/connectivity_probe.dart` | Tiny reachability probe for the map's offline notice |
| `lib/data/models/centre.dart` | Centre model + JSON parsing |
| `lib/data/repositories/centres_repository.dart` | Loads/sorts/groups `assets/centres.json` |
| `lib/data/repositories/location_repository.dart` | geolocator wrapper (permissions, fixes, settings, speed/course) |
| `lib/data/repositories/towns_repository.dart` | Loads/filters `assets/towns.json` |
| `lib/data/local/preferences_store.dart` | Persisted manual location, locked bearing, language, Simple mode, entitlement cache |
| `lib/services/compass_service.dart` | flutter_compass wrapper (rung 1) |
| `lib/services/motion_sensors.dart` | sensors_plus wrapper (magnetometer / accelerometer / gyroscope) |
| `lib/services/wake_lock_service.dart` | wakelock_plus wrapper |
| `lib/services/device_profile_detector.dart` | device_info_plus → `DeviceClass` |
| `lib/services/navigation_launcher.dart` | Apple Maps / Google Maps / tel: intents |
| `lib/features/shell/app_shell.dart` | Five-tab shell (lazy `IndexedStack`, lifecycle → sensors) |
| `lib/features/compass/…` | Compass screen, controller, providers, dial, level bubble, source chip, calibration, sun guidance |
| `lib/features/compass/engine/…` | `HeadingSource`, `HeadingLadder`, the four sensor rungs |
| `lib/features/msamo/…` | Msamo screen + lock controller |
| `lib/features/location/…` | Live GPS, manual entry, town picker, pick-from-centres |
| `lib/features/towns/…` | Searchable grouped town picker |
| `lib/features/settings/…` | Language switcher + Simple mode (shown on the Guide tab) |
| `lib/features/membership/…` | Optional membership (Supabase OTP, `/api/me`, PayFast), behind `kMembershipEnabled` |
| `lib/features/centres/…` | Map, clustering, search, nearest, grouped list, bottom sheet |
| `lib/features/guide/…` | Guide screen (coordinates, steps, accuracy, about) |
| `lib/widgets/…` | Header, bilingual text, cards, buttons, bottom navigation |
| `assets/centres.json` | The 88 centres in 15 regions — add centres here, not in code |
| `assets/towns.json` | Towns for the Location tab picker |
| `assets/translations.json` | Secondary-language table (zu / pt / ny / bem), 116 keys |
| `assets/fonts/` | Bundled IBM Plex Sans / Mono and Source Serif 4 (`tool/fetch_fonts.sh`) |
| `assets/logo.png` (+ `2.0x/`, `3.0x/`) | Crest (replace with the official artwork) |
| `platform_config/…` | Android manifest / Gradle, iOS Info.plist / Podfile |
| `tool/apply_platform_config.sh` | Copies `platform_config/` over a Flutter scaffold |
| `test/…` | Unit tests: bearing, distance, declination, sun, smoothing, heading math, ladder, calibration, GPS, l10n, assets, profile |

---

## 1. Set the project up

This repository contains the Dart sources, the assets and the platform
configuration, but not the generated native scaffolding (Gradle wrapper,
`Runner.xcodeproj`, …). Generate it once, then apply the config from this repo:

```bash
cd Spiritual-campass

# 1. install dependencies (also writes .dart_tool and the plugin registrants)
flutter pub get

# 2. generate android/ and ios/ into a throwaway project …
cd ..
flutter create --org com.tshk --project-name tshk_compass \
    --platforms=android,ios tshk_scaffold
cd -

# 3. … copy the generated folders in …
cp -R ../tshk_scaffold/android .
cp -R ../tshk_scaffold/ios .

# 4. … and overwrite them with this repository's configuration
./tool/apply_platform_config.sh

flutter pub get
```

> `flutter create` refuses to overwrite an existing `pubspec.yaml`, which is why
> the scaffold is generated elsewhere and copied in.

Then generate the launcher icon and the native splash (both configured in
`pubspec.yaml`):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Android

* `minSdk` is inherited from `flutter.minSdkVersion` (24 in Flutter 3.44), which
  is above the 23 that geolocator and flutter_compass need — nothing to
  configure.
* There is exactly one app build script, `android/app/build.gradle.kts`, and it
  takes `versionCode` / `versionName` from the Flutter Gradle Plugin
  (`flutter.versionCode` / `flutter.versionName`). Do not add a Groovy
  `build.gradle` beside it: Gradle prefers the Groovy file, and the old
  `flutterVersionCode` / `flutterVersionName` properties no longer exist.
* Permissions: `INTERNET`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`.
* `<queries>` for `https`, `geo`, `google.navigation` and `tel`, so Directions,
  Map and Call can be handed to another app on Android 11+.
* Orientation is locked to portrait in the manifest **and** in `main.dart`.

### iOS

* `NSLocationWhenInUseUsageDescription` and `NSMotionUsageDescription`, both
  phrased so that adding the isiZulu line is easy.
* `LSApplicationQueriesSchemes` includes `maps`, `http`, `https` and `tel`.
* Portrait only (`UISupportedInterfaceOrientations`).
* `Podfile` sets iOS 13.0 and `BYPASS_PERMISSION_LOCATION_ALWAYS=1` for
  geolocator, so no "Always" location key is required.

---

## 2. Run it

```bash
# Devices / simulators
flutter devices

# Android (emulator or cable-connected phone)
flutter run -d android

# iOS (needs a Mac with Xcode; the simulator has no magnetometer, so the
# compass shows the "no sensor" state — use a real device to test the dial)
flutter run -d "iPhone"
```

First run notes:

* Tap **Start compass** on the Compass tab. iOS then asks for location and for
  motion & orientation; Android asks for location (fine + coarse together).
* On a simulator the compass reports no sensor. The app keeps working: true
  bearing, magnetic bearing, distance and declination are still shown.
* `google_fonts` downloads Source Serif 4 / IBM Plex Sans the first time it
  paints and caches them. Offline it falls back to the platform font, so text
  still renders. To be fully offline from the first launch, bundle the fonts and
  drop `google_fonts` (see "Notes" below).

---

## 3. Tests

```bash
flutter test
```

`test/core/wmm_test.dart` checks the WMM implementation against **10 of NOAA's
published WMM2025 test values** (the full 100-vector file was used while
developing it) and asserts that Southern African declinations are negative and
inside the 17°–28° west range quoted in the guide.

Added with the sensor ladder:

| Test | Covers |
| --- | --- |
| `test/core/heading_math_test.dart` | Tilt-compensated heading from accelerometer + magnetometer vectors (flat and upright), yaw-rate sign, level bubble |
| `test/features/heading_ladder_test.dart` | Failover ladder under `fake_async`: timeouts, absent sensors, stale → restart → next rung, provisional samples, restart |
| `test/features/calibration_and_gps_test.dart` | Sun / north calibration offset math (true vs magnetic), GPS course accepted only while walking and flagged true-north |
| `test/core/l10n_test.dart` | Fallback order chosen → authored isiZulu → file isiZulu → English; locale suggestion; all `S.*` keys exist in `translations.json` |
| `test/data/centres_asset_test.dart`, `test/data/towns_repository_test.dart` | 88 centres / 15 regions with valid coordinates and unique ids; towns parsing, search and filtering |
| `test/core/performance_profile_test.dart` | Profile detection and the Simple-mode override |

---

## 4. Release builds

### Android

```bash
# Create a keystore once (keep it safe — you need it for every update)
keytool -genkey -v -keystore ~/tshk-compass.jks -keyalg RSA -keysize 2048 \
    -validity 10000 -alias tshk

# android/key.properties
cat > android/key.properties <<'EOF'
storeFile=/absolute/path/to/tshk-compass.jks
storePassword=...
keyPassword=...
keyAlias=tshk
EOF
```

Then replace the `signingConfig = signingConfigs.debug` line in
`android/app/build.gradle` with a real `signingConfigs { release { … } }` block
(the standard Flutter snippet), and build:

```bash
# Fonts once (bundled; no runtime download):
bash tool/fetch_fonts.sh

# Per-ABI APKs for sideloading on low-storage phones (arm64-v8a, armeabi-v7a):
flutter build apk --release --split-per-abi
# Outputs: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#          build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk

# Play Store bundle (Play serves the right ABI / density itself):
flutter build appbundle --release
# Output:  build/app/outputs/bundle/release/app-release.aab

# Optional flags:
#   --dart-define=STORE_BUILD=true        hide purchase UI (store builds)
#   --dart-define=MEMBERSHIP_ENABLED=true turn the membership feature on
#   --dart-define=MEMBERSHIP_API_BASE_URL=… SUPABASE_URL=… SUPABASE_ANON_KEY=…
```

Release builds use R8 minification and resource shrinking (rules in
`android/app/proguard-rules.pro`), `minSdk 24` (Android 7.0) and only the two
ARM ABIs. The iOS deployment target is 13.0.

### iOS (macOS + Xcode)

```bash
flutter build ipa --release \
  --export-options-plist=ios/ExportOptions.plist
```

Or archive from Xcode: open `ios/Runner.xcworkspace`, select **Any iOS Device
(arm64)**, *Product ▸ Archive*, then *Distribute App*. You need an Apple
Developer team, a bundle identifier and a signing certificate.

Before shipping, bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`).

---

## Notes on the calculations

**Declination is computed, never hard-coded.** `lib/core/wmm/wmm.dart` is a Dart
port of the NOAA/NCEI spherical-harmonic evaluation (degree and order 12,
Schmidt semi-normalised Legendre recursion, WGS84 geodetic → geocentric
conversion, secular variation to the requested decimal year), using the official
WMM2025 coefficient file bundled in `wmm_coefficients.dart`. Verified against
NOAA's published test values: worst case **0.005°** in declination and
**0.001 nT** in horizontal intensity over 100 vectors. Valid 2025.0 – 2030.0;
`kWmmEpoch` and `kWmm2025Coefficients` are the two things to replace when WMM
2030 ships.

**About the "17° to 28° west" figure.** With WMM2025 the real values are:
Johannesburg −20.6° (2026), Pretoria −20.0°, Ekuphumuleni −24.9°, Bloemfontein
−24.3°, Cape Town −26.6°, Durban −27.5°. The −17° to −19° figure that older
tables quote for Johannesburg corresponds to roughly 2010–2015; the field has
drifted about 1° west every five years. `test/core/wmm_test.dart` asserts
today's values, and the guide text quotes both the historic range and the
current examples.

**Sun position** follows the NOAA Solar Calculator (Reda & Andreas)
formulation, including the equation of time and atmospheric refraction. Checked
against the solstice/equinox declinations (±23.44° / 0°), the published
equation-of-time curve (±0.5 min), `elevation = 90 − |lat − dec|` at solar noon,
polar day/night, and the hemisphere of the noon sun.

**Bearings** are great-circle (initial) bearings; **distances** are haversine
kilometres on a 6371.0088 km sphere. The dial needle sits at
`bearing − trueHeading`; the heading is smoothed with a wrap-aware filter
(`AngleSmoother`) and the UI is throttled to ~30 fps.

---

## How the heading is found — the source ladder

One `CompassController` feeds both the Compass and the Msamo screens. It walks a
ladder of heading sources, best first, and drops a rung when a sensor is absent
or produces no valid sample for ~3 s (`HeadingLadder`, pure Dart, tested with
`fake_async`). A rung that goes quiet later is flagged **stale** ("Move the
phone to wake the compass · Nyakazisa ifoni"), restarted once, then abandoned.

| # | Source (status chip) | Reference | Declination | Notes |
| --- | --- | --- | --- | --- |
| 1 | **Compass sensor** — `flutter_compass` fused heading | magnetic | applied | Android rotation vector / iOS `CLHeading` |
| 2 | **Raw sensors** — magnetometer + accelerometer, tilt-compensated in Dart (`HeadingMath.tiltCompensatedHeading`) | magnetic | applied | Same math as Android's `getRotationMatrix`; the "facing" blend uses the top edge when flat and the back of the phone when upright |
| 3 | **Turn sensor + calibration** — gyroscope (or rotation vector) integrated about the vertical, plus one tap on **Set: pointing at the sun** or **Set: pointing north** | true (sun) / magnetic (north) | only for north | Uncalibrated it shows the Set buttons and no heading; the smoother resets at calibration |
| 4 | **GPS (walking)** — geolocator course, only when speed > 1 m/s with sane heading accuracy | true | never | "Walk a few steps to get direction · Hamba izinyathelo ezimbalwa"; also listened to opportunistically while rung 3 waits |
| 5 | **Sun guidance** — no heading at all | — | — | Sun azimuth now, "face the sun then turn N°", stick-shadow method, hand-compass bearing (true & magnetic). Bearing / distance / declination keep working |

Rules: WMM declination is added only to magnetic samples (rungs 1, 2, north-
calibrated 3); GPS and sun-calibrated headings are already true. The wrap-aware
smoother (`AngleSmoother`) and the UI throttle (`HeadingThrottle`, 33 ms normal /
66 ms low profile) sit between the ladder and the dial. Level bubble
("Flat · Ithe bha" when |pitch| < 8° and |roll| < 8°) runs on the accelerometer
independently and is shown only while a sensor is active. The screen stays on
(`wakelock_plus`) while the compass runs; sensors and the wake lock are released
when the app goes to the background and restarted on resume.

### Degradation matrix

| Situation | What happens |
| --- | --- |
| No compass (magnetometer) | Rungs 1–2 are skipped; rung 3 asks for a one-tap Set (sun or north); walking gives GPS course; otherwise sun guidance. Bearings still shown |
| No gyroscope | Rung 3 is skipped (rotation vector is tried first); GPS course while walking, else sun guidance |
| No accelerometer | Rung 2 and the level bubble are unavailable; rung 1 (fused) still works if present; the gyro rung uses a vertical assumption |
| No GPS / no fix | Compass still turns (magnetic heading); bearing, distance and declination wait for a manual location, a town from the picker or a centre |
| No internet | Everything except map tiles works: compass, sun, guide, centres list, town picker. Map shows "Map unavailable offline"; cached tiles still draw (normal profile) |
| Low RAM (≤ 2 GB, `isLowRamDevice`, Android ≤ 8.0, old iPhones) | `low` profile: 15 fps arrow, flat dial (no gradients / shadows / halo), no animations, 16 MB image cache, tighter clustering, tile cache off. Users can force it with **Battery saver · Simple mode** on the Guide tab |
| Location denied / denied forever / services off | Distinct messages with a button to the right system screen; the dial still turns on magnetic heading |
| Motion denied (iOS) or sensor stream errors | The rung fails over like an absent sensor; nothing crashes. `NSMotionUsageDescription` is set |

### Low-end guidance

* Tabs are built lazily: the map is not created until Centres is opened.
* `RepaintBoundary` around the dial and the map; dial tick paths are cached per
  size; `const` widgets throughout.
* `ImageCache` limits follow the profile; the crest ships as 1x / 2x / 3x and is
  decoded at display size.
* Fonts are bundled (`GoogleFonts.config.allowRuntimeFetching = false`).
* Text scale is clamped to 0.9–1.3; layouts are checked at 320 dp.
* Map tiles use `userAgentPackageName = com.tshk.tshk_compass` and an optional
  ~50 MB size-capped cache (off in the low profile).

## Languages

English is always the first line. The second line follows the language chosen
on the Guide tab — **isiZulu (default), Português, Chichewa, Bemba** — loaded
from `assets/translations.json` (116 keys). The choice is persisted; on first run
it is suggested from the device locale (pt / ny / bem, else isiZulu). Fallback
per string: chosen language → isiZulu authored in code → isiZulu in the file →
English. All strings live in `lib/core/l10n/strings.dart` (`Bi(en, zu, key:)`).

## Feature flags

| Flag | Default | Effect |
| --- | --- | --- |
| `kMembershipEnabled` (`--dart-define=MEMBERSHIP_ENABLED`) | `false` | Shows the Membership card on the Guide tab: Supabase e-mail OTP sign-in, `/api/me`, PayFast checkout / cancel, offline entitlement cache (`flutter_secure_storage` for tokens) |
| `kStoreBuild` (`--dart-define=STORE_BUILD`) | `false` | Hides every purchase / subscribe / cancel control; sign-in and status remain |
| `MEMBERSHIP_API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` | placeholders | See `lib/core/config/app_config.dart` |

---

## What you must supply

1. **The crest artwork** — replace `assets/logo.png` with the official round
   blue-and-gold crest (1024 × 1024 PNG with a transparent background), then
   re-run `dart run flutter_launcher_icons` and
   `dart run flutter_native_splash:create`. The file in the repo is a
   placeholder generated for this build.
2. **Verify the centre and town coordinates.** `assets/centres.json` now holds
   the 88 centres in 15 regions from the web edition and `assets/towns.json` the
   town list; both are the single source of truth for the map, the grouped list
   and the pickers. The coordinates are as supplied and were not re-checked
   against the ground.
3. **Confirm the Msamo and Location behaviour.** Both are built as described
   below; please confirm this is what you want:
   * *Msamo*: shows the required true bearing and the matching magnetic bearing
     for a hand compass, and a live instruction ("Turn 32° to your right /
     `Phendukela ngakwesokudla ngo-32°`"). Within ±3° it turns gold and says
     "Your msamo is facing Ekuphumuleni". **Lock this direction** freezes the
     bearing (and survives a restart) so the spot can be marked; **Unlock**
     returns to live readings.
   * *Location*: shows the current GPS fix with its accuracy; **Use my location**
     starts live tracking; **Enter coordinates manually** and **Pick from
     centres** save a manual origin that overrides GPS for every bearing and
     distance in the app; **Return to live GPS** clears it. Permission denial,
     permanent denial and switched-off location services each get their own
     message plus a button that opens the right settings screen.
4. **A fluent isiZulu speaker's review** of `lib/core/l10n/strings.dart`. Every
   string is in that one file, so a single pass covers them all. The strings you
   supplied verbatim (tab names, readouts, guide steps, help text) are used as
   given; the surrounding isiZulu was written for this build and should be
   checked.

---

## Packages

`flutter_riverpod` (state), `geolocator` (location, GPS course),
`flutter_compass` (fused heading), `sensors_plus` (raw sensors, level bubble),
`wakelock_plus` (screen on), `device_info_plus` (performance profile),
`flutter_map` + `latlong2` + `flutter_map_marker_cluster` (map), `url_launcher`
(directions/calls/PayFast), `shared_preferences` (settings), `flutter_secure_storage`
+ `http` (membership, only active behind the flag), `google_fonts` (bundled
Source Serif 4 + IBM Plex Sans/Mono, no runtime fetching).

Riverpod is pinned to the 2.x line (`^2.6.1`) because that is the API the code
was written against. If you upgrade to Riverpod 3, the only changes needed are
cosmetic (the handwritten providers used here — `Provider`, `FutureProvider`,
`StreamProvider`, `NotifierProvider` — are all still valid).

The map uses the standard OpenStreetMap raster tiles (darkened with a colour
filter) with visible attribution and the `com.tshk.tshk_compass` user agent
required by the OSM tile usage policy. For heavy traffic switch the URL in
`lib/core/map_config.dart` to a keyed provider.

## Could not be verified in this environment

* No Flutter SDK was available where the code was written: the Dart files were
  cross-checked by hand but **not compiled or run**. Run `flutter pub get`,
  `flutter analyze` and `flutter test` first.
* The 88 centre coordinates and the town coordinates are as supplied.
* Portuguese, Chichewa and Bemba strings in `translations.json` are as supplied;
  the new isiZulu strings written for the sensor ladder, settings and membership
  need a fluent speaker's review.
* Fonts are not committed; `tool/fetch_fonts.sh` downloads them (release URLs
  may need updating).
* Behaviour on specific low-end phones (Android 7 / 1 GB, iPhone 6s) and the
  sensors_plus axis conventions on iOS were reasoned from documentation only.
* The membership API is implemented from the contract, not against a live
  server.
