# Compass accuracy and release validation

No phone app can guarantee an accurate heading on every handset or next to magnets, steel, vehicles, electrical equipment, or weak geomagnetic fields. An OS accuracy estimate is not a measurement of this app's physical error. The engine deliberately prefers an honest warning or unavailable heading to a false precision confirmation.

## Implemented behavior

### North reference and phone axes

- The app-owned Android/iOS channels carry an explicit north reference, sample time, genuine heading error (when available), reliability, and optional magnetic/gravity/gyroscope/motion diagnostics.
- Android uses rotation-vector fusion, then geomagnetic rotation-vector fusion if necessary. A **game rotation vector is not an absolute compass**. Only the real fifth rotation-vector element supplies a degree estimate; calibration status is never converted into made-up ±degree values.
- iOS uses a magnetic-north Core Motion frame. Its reference-to-device NWU matrix is transposed and converted to device-to-Earth ENU before Dart uses it. Fresh `CLHeading.headingAccuracy` supplies diagnostics; the scalar fallback rejects unavailable magnetic headings and requires a sufficiently level phone.
- A true-north sample is never corrected again. WMM declination is added **once**, only to magnetic readings. Zero, missing, nonfinite or invalid accuracy is not evidence of a perfect heading.
- ENU means east, north, up. Screen rotations remap the UI's top edge. With the screen facing up, the pointing edge is the **top edge**; as the phone becomes upright, pointing transitions toward the **back of the phone**. The dial is not a camera viewfinder.

### Modes and recovery

**Phone direction** selects platform fusion → raw magnetometer/gravity → temporarily calibrated quaternion gyro tracking → sun/hand-compass guidance. The ladder considers usable quality as well as capability and freshness. Acquisition, cancellation, staleness and recovery are bounded; preferred-source probes require a continuous run of new, healthy timestamps. An uncalibrated gyro source may stay available for calibration but does not silently switch to GPS.

**Travel direction** is explicitly selected by the user. GPS measures movement over the ground, **not the direction the phone faces**. Turning the phone without changing the path must not turn a travel-course heading. Travel direction cannot confirm prayer, msamo or sun-facing alignment.

GPS accepts fresh fixes (up to 3 s), speed at least 1.2 m/s, radius at most 25 m and a sustained sequence of moving fixes. A genuine native course error is used when present. With unknown course error, a sufficiently long, straight displacement baseline is required instead; this estimate remains uncertain. Walk straight outdoors rather than spin or wave the handset.

### Confidence and precision

- Field strength, model deviation, calibration status, motion, timestamp order/gaps, tilt/gravity validity and available gyro consistency help identify interference. Constant magnetic bias can still evade these checks.
- Unknown degree accuracy remains **uncertain**, even if a heading looks smooth or the OS calibration flag is high. Raw sensors and human sun/north anchors do not receive invented angular bounds.
- A precise-alignment indication requires a reliable, fresh (≤250 ms) true heading, at least one second of settling, and a known reliable destination bearing. Nominal angular deviation **plus heading/filter lag, WMM and location-bearing uncertainty must fit inside 3°**.
- A frozen msamo mark and the actual live destination must both fit the same error budget. Missing, approximate, stale or near-destination location, relative tracking and GPS travel mode cannot claim that confirmation.
- These are conservative gates on **reported/estimated uncertainty**, not a universal physical ±3° guarantee. Field measurements remain necessary.

### Location, WMM and calibration

Original fix timestamps, horizontal radius, speed and course error are retained. Precision requires a location no older than 3 s and known velocity/error metadata; reported motion grows the origin error circle between fixes and at the moment of confirmation. Unknown motion is not silently treated as a stationary origin. Reduced/unknown OS precision and mocked fixes are marked approximate. Towns, manually entered coordinates and centres are approximate origins, not secretly fresh GPS fixes. Bearing error increases near the target; within the fix radius (or 10 m), direction to the destination is treated as undefined.

WMM2025 is valid from **2025-01-01 UTC to before 2030-01-01 UTC**. Model expiry or a badly set device clock must warn rather than extrapolate silently. Evaluation is cached by date/position/altitude; context validity refreshes independently of sensor frames.

Gyro-relative tracking uses 3D quaternions, not a flat-only `gyro.z` integration. Anchor expiry (60 s), restarts and integration gaps (>250 ms) invalidate calibration. Rest-based gyro bias adaptation is heuristic: gravity cannot distinguish very slow yaw from bias, and temperature can change drift. Relative tracking remains temporary and uncertain. Re-anchor frequently.

For sun calibration, use a correct clock and location, elevation **5° to below 80°**, and a flat/still phone. Place a straight vertical stick on level ground; point the phone's top edge **opposite the shadow**. **Never look directly at the sun.** A hand-compass anchor means magnetic north, not map/true north; keep the instruments apart so they do not disturb each other.

### Lifecycle and low-end devices

Sensor sampling and elapsed-time filtering follow the performance profile; rendering is capped rather than assuming a fixed sample rate. Source/reference/quality transitions reset smoothing and settling. Pending source cleanup is serialized and bounded. Backgrounding cancels continuous location, the owned one-shot location listener and sensor sessions and releases the wake lock; resuming starts a new session. A GPS session started from the Location tab also participates in lifecycle cleanup. Transient inactive states (for example a permission dialog) are not treated as full backgrounding.

The fresh level bubble is not proof of heading quality. Missing or stale acceleration hides the bubble instead of displaying an invented level phone.

## Automated validation

Use Flutter **3.44.0 / Dart 3.12 or newer** and **Xcode 26.1+** for the current iOS dependencies; CI is pinned to Flutter 3.44.0 and selects Xcode 26.3. Python 3 is required only for platform configuration helpers.

```bash
python3 tool/check_compass_config.py
python3 -m unittest discover -s tool/tests -v
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
(cd android && bash gradlew :app:testDebugUnitTest --no-daemon)
# macOS + Xcode + CocoaPods:
flutter build ios --debug --no-codesign
flutter build ios --simulator --debug
# Run the RunnerTests test target in Xcode on an available iOS simulator.
```

`.github/workflows/compass-checks.yml` performs Flutter analysis/tests, Android compilation/JUnit and iOS compilation/XCTest. Its existence is **not** evidence of a successful run. Check the workflow results before merging/releasing. Simulators validate code paths, not physical sensor accuracy.

Regression suites cover reference correction/sentinels, frames/quaternions, elapsed-time smoothing, quality, alignment budgets, fallback/probes, anchor expiry, explicit GPS, location races/metadata/cleanup, controller lifecycle/filter lag, and dial semantics/haptic guards. Native tests exercise the actual iOS matrix conversion and Android fifth-slot accuracy conversion.

## Physical-device acceptance protocol — required before release

### Device matrix and setup

At minimum test:

1. A low-end Android, including one without a gyro or magnetometer when available.
2. A mid-range Android and a high-end Android, with different sensor vendors.
3. An older supported iPhone and a current iPhone. Include an iPad/naturally-landscape Android tablet if claiming support there.

Record model, OS/build, app revision, available sensors, mode, source, reported error/confidence, performance profile, case/accessories, time/location metadata, temperature and conditions. Use the same signed/test build and normal app access flow. Do not disable the membership gate in a shipping build for testing.

Choose an open outdoor site away from cars, fences, reinforced concrete, power cables and magnetic accessories. Use a surveyed **true** bearing or an independently established GNSS baseline as reference. Do not use another app on the same magnetometer as independent ground truth. Convert a hand-compass comparison using local declination and keep it well away from the phone.

### Measurements and behavior

| Check | Procedure and acceptance |
| --- | --- |
| Cardinal axes | Measure N/E/S/W, flat, intermediate tilt and upright. Repeat display rotations/tablet posture. UI top/back must follow the documented convention; no sign flips, 90° or 180° axis mistakes. |
| True vs magnetic | Compare iOS/Android independently at a site with substantial declination (Southern Africa is useful). Correction must occur once, not zero/twice. |
| Static heading error | Collect ≥30 settled observations per pose/cardinal direction, both profiles, after normal OS calibration. Record signed error and absolute-error p50/p95/max, not just the prettiest reading. |
| Precision confirmations | Count every gold/aligned/haptic event and compare to independent ground truth. Record false confirmations separately. Any out-of-budget confirmation requires investigation; do not certify universal ±3° based on the UI estimate. |
| Dynamic response | Slow and fast turns, wrap across north, tilt/roll while turning. Check lag/overshoot and that precision disappears immediately on motion, quality loss or staleness. |
| Interference | Introduce a magnetic case, metal desk, car interior and nearby electrical equipment separately. Expect a warning/unreliable state or safe fallback where detectable; remove interference and observe bounded recovery. Also record interference that evades diagnostics. |
| Missing/denied sensors | Test actual reduced hardware, motion denied, permission changes, stream silence and no fix indoors. No fabricated zero heading or target needle; explicit travel selector stays accessible during gyro calibration. |
| Gyro anchors | Calibrate on a safe sun/shadow or separated hand compass. Test 60 s expiry, pauses, restarts, gaps, yaw plus tilt/roll, slow-turn bias and thermal drift. Expired/lost anchors must require re-setting. Relative tracking never claims measured precision. |
| GPS travel | Remain still, walk straight, turn a corner, stop and rotate the phone alone. Distinguish course from facing; stale/slow/poor-radius fixes must not appear precise. Test unknown course error and repeated/out-of-order fixes. |
| Location | Denied/forever denied/off, reduced precision, stale cached fix, manually selected town and accurate fresh GPS. Near the destination, direction/align prompts must disappear. |
| Lifecycle | Start/pause/resume repeatedly, navigate tabs, lock screen, background and foreground, change profile, revoke access/sign out. Repeat with **only Location tracking** active. No residual native listeners, wake lock or revived old-session callbacks; pending GPS acquisition must cancel. |
| Solar safety | Day/night, horizon (<5°), near zenith (≥80°), bad clock, flat/still requirement. No encouragement to look at the sun; opposite-shadow instruction must be unambiguous. |
| Battery/performance | Profile release/profile builds for 10–15 min on low-end and high-end devices. Record CPU, frame times/dropped frames, battery and thermal behavior in both profiles; verify reduced sampling/rendering and no background sensors. |
| Accessibility/languages | Screen reader, 320 dp width, supported text scale and all five languages. Review isiZulu/Portuguese safety copy with fluent speakers; new Chichewa/Bemba keys currently use English fallback and need language review. |

If a phone cannot meet a measured accuracy target, keep the warning/fallback behavior and document that device/condition; do not loosen the confirmation gate simply to make it turn gold. Fix discovered regressions, rerun automated checks and repeat affected physical tests. Store results with the build revision. There are **no physical measurements attached to this implementation yet**.
