#!/usr/bin/env bash
# Types a sentence into real apps with the Dấu input method and checks the text that
# comes out. Needs the Accessibility permission for the process running the script
# (System Events keystrokes); the Debug input method must be installed, the Dấu input
# source enabled (scripts/install-debug.sh), and the apps installed.
#
# Usage:
#   scripts/selftest-typing/run.sh [options] <app>...
#     app:  textedit | safari | chrome | vscode | terminal | all
#   --delay MS        pause between keys in ms (default 30). 0 sends the whole string in
#                     one System Events keystroke (about 1 ms per key): a stress test that
#                     Chrome, VS Code and Terminal fail with method A (docs/PROGRESS.md);
#                     120 is close to normal typing.
#   --keys "…"        keys to type (default: the sample sentence below)
#   --expect "…"      expected text (default: what the sample sentence must give)
#
# For each app: opens a new, empty window, selects the Dấu input source (which must be
# enabled already; nothing is enabled or disabled, N4), types, reads the text back,
# closes the window without saving, prints the text, PASS/FAIL and the input method's
# counts and timings for that app (scripts/perf-report.sh). The input source selected
# before and the clipboard (read through ⌘C in Safari, Chrome, VS Code) are restored.
#
# Terminal: the keys go to the shell prompt of a new window. The script never presses
# Return; it clears the line with ⌃U before closing the window. Keys must not contain
# a newline.
#
# Exit status 0 only if every app gives the expected text.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/scripts/selftest-typing"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BIN="$ROOT/build/selftest"
LOG=/usr/bin/log

KEYS='tooi yeeu tieengs Vieetj, windows Hasaki carr '
EXPECT='tôi yêu tiếng Việt, windows Hasaki car '
DELAY_MS=30
APPS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --delay) DELAY_MS="${2:?--delay cần số ms}"; shift 2 ;;
    --keys) KEYS="${2?}"; shift 2 ;;
    --expect) EXPECT="${2?}"; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    all) APPS+=(textedit safari chrome vscode terminal); shift ;;
    textedit|safari|chrome|vscode|terminal) APPS+=("$1"); shift ;;
    *) echo "Tham số không hợp lệ: $1" >&2; exit 2 ;;
  esac
done
[[ ${#APPS[@]} -gt 0 ]] || { sed -n '2,27p' "$0"; exit 2; }
if [[ "$KEYS" == *$'\n'* || "$KEYS" == *$'\r'* ]]; then
  echo "Phím gõ không được có xuống dòng (không bao giờ nhấn Return trong Terminal)." >&2
  exit 2
fi

# --- helpers -------------------------------------------------------------------------
mkdir -p "$BIN"
build_helper() { # name source
  if [[ ! -x "$BIN/$1" || "$2" -nt "$BIN/$1" ]]; then
    xcrun swiftc -O -o "$BIN/$1" "$2" || { echo "Không biên dịch được $2" >&2; exit 1; }
  fi
}
build_helper input-source "$ROOT/scripts/selftest-app-group/input-source.swift"
build_helper clipboard "$HERE/clipboard.swift"
INPUT_SOURCE="$BIN/input-source"
CLIPBOARD="$BIN/clipboard"

IM_PLIST="$HOME/Library/Input Methods/DauInputMethod.app/Contents/Info.plist"
[[ -f "$IM_PLIST" ]] || { echo "Chưa cài bộ gõ (scripts/install-debug.sh)." >&2; exit 1; }
IM_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$IM_PLIST")"
DAU_SOURCE="$("$INPUT_SOURCE" enabled "$IM_ID" | grep '\.vi$' | head -1)"
[[ -n "$DAU_SOURCE" ]] || { echo "Nguồn nhập liệu Dấu – Tiếng Việt chưa được bật." >&2; exit 1; }

WORK="$(mktemp -d)"
ORIGINAL_SOURCE="$("$INPUT_SOURCE" current)"
"$CLIPBOARD" save "$WORK/clipboard.plist" || exit 1
cleanup() {
  "$CLIPBOARD" restore "$WORK/clipboard.plist" 2>/dev/null || echo "CẢNH BÁO: không khôi phục được clipboard" >&2
  if [[ "$("$INPUT_SOURCE" current)" != "$ORIGINAL_SOURCE" ]]; then
    "$INPUT_SOURCE" select "$ORIGINAL_SOURCE" || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PAGE="$WORK/dau-selftest.html"
cat > "$PAGE" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Dau self test</title>
<textarea autofocus spellcheck="false" autocomplete="off" style="width:90%;height:8em"></textarea>
HTML

[[ "$DELAY_MS" =~ ^[0-9]+$ ]] || { echo "--delay phải là số nguyên ms" >&2; exit 2; }

select_dau() { "$INPUT_SOURCE" select "$DAU_SOURCE"; sleep 0.3; }

type_keys() {
  # The delay goes in as whole milliseconds: coercing "0.030" to a real follows the
  # user's locale (Vietnamese uses a decimal comma, so it became 30 seconds).
  osascript - "$KEYS" "$DELAY_MS" <<'OSA'
on run argv
  set s to item 1 of argv
  set d to ((item 2 of argv) as integer) / 1000
  tell application "System Events"
    if d = 0 then
      keystroke s
    else
      repeat with c in characters of s
        keystroke (c as text)
        delay d
      end repeat
    end if
  end tell
end run
OSA
  sleep 0.8   # let asynchronous apps catch up before reading
}

# ⌘A ⌘C in the focused text field, then the plain text of the clipboard.
copy_all() {
  osascript -e 'tell application "System Events"' \
    -e 'keystroke "a" using {command down}' -e 'delay 0.2' \
    -e 'keystroke "c" using {command down}' -e 'delay 0.3' -e 'end tell' >/dev/null
  "$CLIPBOARD" text
}

# --- one function per app; each prints the text typed ---------------------------------
run_textedit() {
  osascript -e 'tell application "TextEdit"' -e 'activate' -e 'make new document' -e 'end tell' >/dev/null
  sleep 0.8; select_dau; type_keys
  osascript -e 'tell application "TextEdit"' -e 'set t to text of front document' \
    -e 'close front document saving no' -e 'return t' -e 'end tell'
}

# Safari and Chrome are driven with `open` and System Events keystrokes only: scripting
# them directly needs a separate Automation permission per browser.
PAGE_TITLE="Dau self test"
# Names of the windows of process $1 (System Events; the window name is the tab title).
window_names() {
  osascript -e 'on run argv' -e 'tell application "System Events" to get name of every window of process (item 1 of argv)' \
    -e 'end run' "$1" 2>/dev/null
}
# Closes the test page's tab with ⌘W (the browser is frontmost), then checks no window of
# process $1 still shows it; tries again a few times.
close_test_tab() {
  for _ in 1 2 3; do
    osascript -e 'tell application "System Events" to keystroke "w" using {command down}' >/dev/null
    sleep 0.6
    [[ "$(window_names "$1")" == *"$PAGE_TITLE"* ]] || return 0
  done
  echo "CẢNH BÁO: còn tab \"$PAGE_TITLE\" trong $1, đóng tay giúp" >&2
}

run_safari() {
  open -a Safari "$PAGE"
  sleep 2.5; select_dau; type_keys
  copy_all
  close_test_tab Safari
}

run_chrome() {
  open -a "Google Chrome" "$PAGE"
  sleep 2.5; select_dau; type_keys
  copy_all
  close_test_tab "Google Chrome"
}

run_vscode() {
  open -a "Visual Studio Code"; sleep 2
  osascript -e 'tell application "Visual Studio Code" to activate' -e 'delay 0.5' \
    -e 'tell application "System Events" to keystroke "n" using {command down}' >/dev/null
  sleep 1.2; select_dau; type_keys
  copy_all
  # Empty the untitled editor so ⌘W closes it without asking to save.
  osascript -e 'tell application "System Events"' -e 'keystroke "a" using {command down}' \
    -e 'delay 0.1' -e 'key code 51' -e 'delay 0.2' \
    -e 'keystroke "w" using {command down}' -e 'end tell' >/dev/null
}

run_terminal() {
  osascript -e 'tell application "Terminal"' -e 'activate' -e 'do script ""' -e 'end tell' >/dev/null
  sleep 1.5; select_dau; type_keys
  # The keys sit on the prompt's last line after the prompt itself: print that line;
  # the caller compares by suffix.
  osascript -e 'tell application "Terminal" to get contents of selected tab of front window' \
    | grep -v '^[[:space:]]*$' | tail -1
  # ⌃U clears the line; never Return. Then close the window (only the shell runs in it).
  osascript -e 'tell application "System Events" to keystroke "u" using {control down}' \
    -e 'delay 0.2' -e 'tell application "Terminal" to close front window' >/dev/null 2>&1
}

# --- run -------------------------------------------------------------------------------
trim_right() { sed -e 's/[[:space:]]*$//'; }
EXPECT_TRIMMED="$(printf '%s' "$EXPECT" | trim_right)"
FAILED=0
echo "Script sẽ mở: ${APPS[*]} (mỗi app một cửa sổ/tab mới, đóng lại sau khi đọc chữ; app nào chưa chạy thì vẫn để chạy)."
echo "Phím: \"$KEYS\"   mong đợi: \"$EXPECT\"   nghỉ giữa phím: ${DELAY_MS} ms"
for app in "${APPS[@]}"; do
  start="$(date '+%Y-%m-%d %H:%M:%S')"
  got="$("run_$app")"
  sleep 0.3
  got_trimmed="$(printf '%s' "$got" | trim_right)"
  if [[ "$app" == terminal ]]; then
    ok=0; [[ "$got_trimmed" == *"$EXPECT_TRIMMED" ]] && ok=1
  else
    ok=0; [[ "$got_trimmed" == "$EXPECT_TRIMMED" ]] && ok=1
    # TextEdit capitalizes the first word of a new document by itself (macOS "Capitalize
    # words automatically") when keys come slowly enough: not the input method's doing.
    if [[ $ok == 0 && "$app" == textedit ]]; then
      capitalized="$(printf '%s' "$EXPECT_TRIMMED" | perl -CS -pe 's/^(.)/\u$1/')"
      [[ "$got_trimmed" == "$capitalized" ]] && ok=1
    fi
  fi
  echo
  if [[ $ok == 1 ]]; then echo "PASS $app: \"$got_trimmed\""; else echo "FAIL $app: \"$got_trimmed\""; FAILED=1; fi
  "$LOG" show --start "$start" --style compact \
    --predicate "subsystem == \"$IM_ID\" AND category == \"perf\"" > "$WORK/perf.log" 2>/dev/null
  case "$app" in
    textedit) filter=TextEdit ;; safari) filter=Safari ;; chrome) filter=Chrome ;;
    vscode) filter=VSCode ;; terminal) filter=Terminal ;;
  esac
  "$ROOT/scripts/perf-report.sh" --input "$WORK/perf.log" --app "$filter" \
    | grep -E 'count_(replace|mismatch|unsupported|insert)|handle_replace_us|selectedRange_us' || true
done
echo
if [[ $FAILED == 0 ]]; then echo "PASS"; else echo "FAIL"; fi
exit $FAILED
