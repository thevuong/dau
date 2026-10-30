#!/bin/zsh
# UI checks of the real Settings window (docs/UI-CHECKS.md).
#
# Usage: scripts/check-settings-window/run.sh <output-dir> [Dau.app]
#
# Copies the Debug build of Dau.app, signs the copy without the sandbox (so it can
# write its captures), and runs it with --capture-window for every combination of
# scroll bar style (overlay, legacy "Always", system "Automatic") and scroll offset
# (0, 60 pt). Each run captures the 4 sections in light and dark mode off screen.
# Then it captures the onboarding window (onboarding/, onboarding-no-shortcut/).
# check.swift checks the captures and frames (a)–(f) and writes a summary grid.
# Exit status 0 only if every check passes.
#
# The window is moved off screen but exists for a few seconds per run.
set -euo pipefail
here=${0:A:h}
out=${1:?output dir}
app=${2:-${here:h:h}/build/DerivedData/Build/Products/Debug/Dau.app}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

cp -R "$app" "$work/Dau.app"
cat > "$work/ent.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>
PLIST
codesign --force --sign - --entitlements "$work/ent.plist" "$work/Dau.app" >/dev/null 2>&1

for style in WhenScrolling Always Automatic; do
  for scroll in 0 60; do
    dir="$out/$style-$scroll"
    "$work/Dau.app/Contents/MacOS/Dau" --capture-window "$dir" --scroll "$scroll" \
      -AppleShowScrollBars "$style" >/dev/null 2>&1
  done
done

# The onboarding window (steps 1, 2, 2 after "Bật Dấu", 3; light and dark), on fixed
# services; once with the real input-source shortcut, once as if none were set.
"$work/Dau.app/Contents/MacOS/Dau" --capture-onboarding "$out/onboarding" >/dev/null 2>&1
"$work/Dau.app/Contents/MacOS/Dau" --capture-onboarding "$out/onboarding-no-shortcut" \
  --shortcut none >/dev/null 2>&1

swiftc -O -o "$work/check" "$here/check.swift"
"$work/check" "$out"
