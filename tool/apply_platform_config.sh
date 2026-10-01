#!/usr/bin/env bash
#
# Copies the platform configuration from platform_config/ over a Flutter
# scaffold, so the manifest, Gradle build, Info.plist and Podfile are the ones
# in this repository.
#
# Usage (from the repo root, after `flutter create` has generated android/ ios/):
#   ./tool/apply_platform_config.sh
#
# Or point it at a project somewhere else:
#   ./tool/apply_platform_config.sh ../path/to/tshk_compass
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$REPO_ROOT}"

if [[ ! -d "$TARGET/android" && ! -d "$TARGET/ios" ]]; then
  echo "error: $TARGET does not look like a Flutter project (no android/ or ios/)." >&2
  echo "       Run 'flutter create --org com.tshk --project-name tshk_compass \\" >&2
  echo "            --platforms=android,ios .' first." >&2
  exit 1
fi

echo "Applying platform config from $REPO_ROOT/platform_config → $TARGET"

if [[ -d "$TARGET/android" ]]; then
  mkdir -p "$TARGET/android"
  cp -R "$REPO_ROOT/platform_config/android/." "$TARGET/android/"
  # Gradle must see exactly one app build script. `cp -R` cannot delete, so a
  # Groovy build.gradle left over from an older scaffold would survive next to
  # build.gradle.kts — and Gradle would then use the Groovy one, which still
  # references the removed `flutterVersionCode` / `flutterVersionName`.
  rm -f "$TARGET/android/app/build.gradle"
  echo "  android/ updated"
fi

if [[ -d "$TARGET/ios" ]]; then
  mkdir -p "$TARGET/ios"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 is needed to register CompassPlugin.swift in Xcode." >&2
    exit 1
  fi
  if [[ ! -f "$TARGET/ios/Runner.xcodeproj/project.pbxproj" ]]; then
    echo "error: generate the iOS scaffold before applying platform config." >&2
    exit 1
  fi
  cp -R "$REPO_ROOT/platform_config/ios/." "$TARGET/ios/"
  python3 "$REPO_ROOT/tool/register_ios_compass.py" "$TARGET/ios/Runner.xcodeproj/project.pbxproj"
  echo "  ios/ updated"
fi

echo "Done. Now run: flutter pub get"
