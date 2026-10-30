#!/usr/bin/env bash
# Regenerates the temporary input mode icon "V" (template TIFF, 22 × 16 pt @1x + @2x) into
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
# One input mode only (D2): "Dấu – Tiếng Việt".
tiffutil -cathidpicheck "$TMP/V.png" "$TMP/V@2x.png" -out "$OUT/ModeVietnamese.tiff" >/dev/null
echo "wrote $OUT/ModeVietnamese.tiff"
