#!/usr/bin/env bash
# Regenerates the temporary input mode icons (template TIFF, 16 pt @1x + @2x) into
# Apps/DauInputMethod/Resources. Apple's headers document .tif/.icns for input method
# icons (TextServices.h, tsInputMethodIconFileKey); built-in input methods use multi-
# resolution TIFF the same way. TODO(M7): official identity files (docs/BRAND.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Apps/DauInputMethod/Resources"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

xcrun swift "$ROOT/scripts/make-mode-icons.swift" "$TMP"
for letter in V E; do
  name="ModeVietnamese"
  [[ "$letter" == "E" ]] && name="ModeEnglish"
  tiffutil -cathidpicheck "$TMP/$letter.png" "$TMP/$letter@2x.png" -out "$OUT/$name.tiff" >/dev/null
  echo "wrote $OUT/$name.tiff"
done
