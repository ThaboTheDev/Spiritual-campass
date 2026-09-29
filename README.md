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
| `lib/app_providers.dart` | App-wide providers (preferences, repositories, compass service, clock) |
| `lib/core/l10n/strings.dart` | **Every** user-visible string, English + isiZulu |
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
| `lib/data/repositories/location_repository.dart` | geolocator wrapper (permissions, fixes, settings) |
| `lib/data/local/preferences_store.dart` | Persisted manual location and locked msamo bearing |
| `lib/services/compass_service.dart` | flutter_compass wrapper |
| `lib/services/navigation_launcher.dart` | Apple Maps / Google Maps / tel: intents |
| `lib/features/shell/app_shell.dart` | Five-tab shell (`IndexedStack`) |
| `lib/features/compass/…` | Compass screen, controller, providers, dial, readout grid |
| `lib/features/msamo/…` | Msamo screen + lock controller |
| `lib/features/location/…` | Live GPS, manual entry, pick-from-centres |
| `lib/features/centres/…` | Map, clustering, search, nearest, grouped list, bottom sheet |
| `lib/features/guide/…` | Guide screen (coordinates, steps, accuracy, about) |
| `lib/widgets/…` | Header, bilingual text, cards, buttons, bottom navigation |
| `assets/centres.json` | The centres list — add centres here, not in code |
| `assets/logo.png` | Crest (replace with the official artwork) |
| `platform_config/…` | Android manifest / Gradle, iOS Info.plist / Podfile |
| `tool/apply_platform_config.sh` | Copies `platform_config/` over a Flutter scaffold |
| `test/…` | Unit tests: bearing, distance, declination, sun, smoothing, JSON |

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
flutter build apk --release          # installable APK
flutter build appbundle --release    # AAB for the Play Store
# Outputs: build/app/outputs/flutter-apk/app-release.apk
#          build/app/outputs/bundle/release/app-release.aab
```

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

## What you must supply

1. **The crest artwork** — replace `assets/logo.png` with the official round
   blue-and-gold crest (1024 × 1024 PNG with a transparent background), then
   re-run `dart run flutter_launcher_icons` and
   `dart run flutter_native_splash:create`. The file in the repo is a
   placeholder generated for this build.
2. **The full centres list with coordinates.** `assets/centres.json` ships with
   the eight Gauteng centres you gave, using **approximate suburb/town
   coordinates** — every entry is marked `"verified": false`. Please supply the
   remaining centres (other provinces and any outside South Africa) and confirm
   or correct the eight sets of coordinates, then flip `verified` to `true`.
   The Zulu/Gauteng list needs: a street address for **Hammanskraal**, and
   confirmation of the phone numbers as dialled from abroad (`+27 …`).
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

`flutter_riverpod` (state), `geolocator` (location), `flutter_compass`
(magnetometer), `flutter_map` + `latlong2` + `flutter_map_marker_cluster` (map),
`url_launcher` (directions/calls), `shared_preferences` (manual location, locked
bearing), `google_fonts` (Source Serif 4 + IBM Plex Sans/Mono). Nothing else.

Riverpod is pinned to the 2.x line (`^2.6.1`) because that is the API the code
was written against. If you upgrade to Riverpod 3, the only changes needed are
cosmetic (the handwritten providers used here — `Provider`, `FutureProvider`,
`StreamProvider`, `NotifierProvider` — are all still valid).

The map uses CARTO's dark OpenStreetMap tiles with visible attribution. Check
their terms if you expect heavy traffic, or switch the tile URL and the
attribution in `lib/features/centres/widgets/centres_map.dart`.
