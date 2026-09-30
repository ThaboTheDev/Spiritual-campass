#!/usr/bin/env bash
# Downloads the fonts TSHK Compass bundles under assets/fonts so that
# google_fonts never has to fetch anything at runtime
# (GoogleFonts.config.allowRuntimeFetching = false in lib/main.dart).
#
# Requires: curl, unzip. Run once from the repository root:
#   bash tool/fetch_fonts.sh
#
# Sources (OFL-licensed):
#   IBM Plex Sans / IBM Plex Mono — https://github.com/IBM/plex/releases
#   Source Serif 4                — https://github.com/adobe-fonts/source-serif/releases
# The release URLs below were correct when this script was written; if a
# download 404s, open the releases page and update the two variables.
set -euo pipefail

PLEX_URL="${PLEX_URL:-https://github.com/IBM/plex/releases/download/v6.4.0/TrueType.zip}"
SERIF_URL="${SERIF_URL:-https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/fonts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

echo "→ IBM Plex"
curl -fsSL "$PLEX_URL" -o "$TMP/plex.zip"
unzip -q -o "$TMP/plex.zip" -d "$TMP/plex"
for f in IBMPlexSans-Regular IBMPlexSans-Medium IBMPlexSans-SemiBold IBMPlexSans-Bold \
         IBMPlexMono-Regular IBMPlexMono-Medium; do
  src="$(find "$TMP/plex" -name "$f.ttf" | head -n 1)"
  [ -n "$src" ] || { echo "missing $f.ttf in $PLEX_URL" >&2; exit 1; }
  cp "$src" "$OUT/$f.ttf"
done

echo "→ Source Serif 4"
curl -fsSL "$SERIF_URL" -o "$TMP/serif.zip"
unzip -q -o "$TMP/serif.zip" -d "$TMP/serif"
for f in SourceSerif4-Regular SourceSerif4-Semibold; do
  src="$(find "$TMP/serif" \( -name "$f.ttf" -o -name "$f.otf" \) | head -n 1)"
  [ -n "$src" ] || { echo "missing $f in $SERIF_URL" >&2; exit 1; }
  # pubspec expects SourceSerif4-SemiBold.ttf (capital B, as google_fonts names it).
  dest="$OUT/${f/Semibold/SemiBold}.ttf"
  cp "$src" "$dest"
done

echo "Fonts in $OUT:"
ls -1 "$OUT"
