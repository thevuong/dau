#!/usr/bin/env bash
# Regenerates the temporary app icon (docs/BRAND.md "Biểu tượng", D25).
#
#   scripts/make-app-icon.sh [<preview-dir>]
#       Render Resources/Brand/AppIcon*.svg and
#       Apps/Dau/Resources/Assets.xcassets/AppIcon.appiconset from the outlined glyphs in
#       Resources/Brand/app-icon-glyphs.txt. No font needed. With <preview-dir>, also write
#       icon-512.png and sizes.png (16/32/64/128 px, actual size and magnified).
#
#   scripts/make-app-icon.sh outline <BeVietnamPro-Bold.ttf>
#       Re-extract the glyph outlines. Download the font from the official source
#       (https://github.com/google/fonts/tree/main/ofl/bevietnampro or
#       https://github.com/bettergui/BeVietnamPro) to a directory outside the repo.
#       Never commit the font file.
#
# TODO(M7): the official icon is built in Icon Composer (Default / Dark / Clear / Tinted).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAND="$ROOT/Resources/Brand"
GLYPHS="$BRAND/app-icon-glyphs.txt"
ICONSET="$ROOT/Apps/Dau/Resources/Assets.xcassets/AppIcon.appiconset"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ "${1:-}" == "outline" ]]; then
  [[ $# -eq 2 ]] || { echo "usage: $0 outline <font.ttf>" >&2; exit 2; }
  mkdir -p "$BRAND"
  exec xcrun swift "$ROOT/scripts/make-app-icon.swift" outline "$2" "$GLYPHS"
fi

mkdir -p "$ROOT/Apps/Dau/Resources/Assets.xcassets"
if [[ ! -f "$ROOT/Apps/Dau/Resources/Assets.xcassets/Contents.json" ]]; then
  printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' \
    > "$ROOT/Apps/Dau/Resources/Assets.xcassets/Contents.json"
fi
rm -f "$ICONSET"/*.png
xcrun swift "$ROOT/scripts/make-app-icon.swift" render "$GLYPHS" "$BRAND" "$ICONSET" ${1:+"$1"}
