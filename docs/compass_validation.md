# Validation checkpoint — 2026-10-01

## Implementation status

The compass accuracy/reliability work and its native/platform integration are complete on
`arena/01a0f743-spiritual-campass`: explicit north references, native diagnostics,
quality-aware phone sources, a separate GPS travel mode, quaternion-relative calibration,
elapsed-time filtering, conservative alignment, location metadata and cleanup, UI
safety/semantics, regression tests and CI.

The platform overlays match the active Android/iOS files. The apply helper registers the
Swift source idempotently without replacing the Xcode project, and it now removes a
scaffold's leftover `Podfile` so iOS uses Swift Package Manager. Background cleanup also
covers standalone Location-tab tracking and pending one-shot GPS acquisition.

**Everything below that a machine can check has been run and passes. Physical accuracy has
not been measured on any phone.**

## Checks actually performed

| Check | Result | What it establishes |
| --- | --- | --- |
| CI: Flutter analysis | **Passed** | `flutter analyze --no-fatal-infos` clean on Flutter 3.44.0 / Dart 3.12 |
| CI: Flutter regression tests | **Passed** | Full `flutter test` suite green, including the new compass, ladder, source, alignment, WMM, solar, location-lifecycle and widget-safety tests |
| CI: Android build | **Passed** | `flutter build apk --debug --target-platform android-arm64` compiles the Kotlin bridge |
| CI: Android native tests | **Passed** | JUnit fixtures for the accuracy adapter: fifth-slot radians, invalid status, no invented degree bound |
| CI: iOS build | **Passed** | Device and simulator builds on Xcode 26.3 with Swift Package Manager integration |
| CI: iOS native tests | **Passed** | XCTest fixtures: Core Motion reference→device transpose into ENU, upright/back-north case, scalar sentinel rejection |
| Platform helper tests | **5/5 passed** | Registration, idempotence, synchronized groups, unsupported/partial-project handling and overlay application on a temporary scaffold |
| Configuration validator | **Passed** | Active/overlay equality, Swift registration IDs, portrait/scene configuration, translation keys/placeholders/mirrors, old dependency removal and bundled fonts |

Run: [Compass checks 36881282504](https://github.com/ThaboTheDev/Spiritual-campass/actions/runs/36881282504)
— the Flutter, Android and iOS jobs all succeeded.

Two pre-existing breakages were fixed along the way because they blocked that run:

- `AsyncValue.guard(...)` and a phantom `travelDirection` field on two dial painters were
  genuine Dart compile errors on every platform.
- One membership test asserted `Navigator.maybePop(...) == false`. Flutter's
  `maybePop` returns `true` when a `PopScope` refuses the pop ("the pop was handled"), per
  `navigator.dart` in 3.44.0, so the assertion contradicted the pinned SDK. The test now
  verifies the surviving route instead; the screen's behaviour is unchanged.

## Not run / remaining release gates

- **Physical devices:** no independent heading-error, interference, battery or thermal
  measurements have been collected. Simulators and CI cannot replace this.
- **Language review:** new isiZulu/Portuguese safety guidance needs fluent review; new
  Chichewa/Bemba copy currently falls back to English.
- **Release builds:** only debug builds were compiled. Release obfuscation, ProGuard rules
  and store signing are untested.

Use the commands and mandatory device matrix in [compass_accuracy.md](compass_accuracy.md).
Record device-specific p50/p95/max error and false-confirmation counts before release. A
genuine OS error estimate plus a conservative 3° gate is not a guarantee that every phone
is physically accurate to ±3°.
