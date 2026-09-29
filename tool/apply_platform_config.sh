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
  echo "  android/ updated"
fi

if [[ -d "$TARGET/ios" ]]; then
  mkdir -p "$TARGET/ios"
  cp -R "$REPO_ROOT/platform_config/ios/." "$TARGET/ios/"
  echo "  ios/ updated"
fi

echo "Done. Now run: flutter pub get"
