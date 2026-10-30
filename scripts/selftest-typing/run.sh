#!/usr/bin/env bash
# Types a sentence into real apps with the Dấu input method and checks the text that
# comes out. Needs the Accessibility permission for the process running the script
# (System Events keystrokes); the Debug input method must be installed, the Dấu input
# source enabled (scripts/install-debug.sh), and the apps installed.
#
# Usage:
#   scripts/selftest-typing/run.sh [options] <app>...
#     app:  textedit | safari | chrome | vscode | terminal | edge | firefox | notes | mail
#           | all (= the first five)
#   --delay MS        pause between keys in ms (default 30). 0 sends the whole string in
#                     one System Events keystroke (about 1 ms per key): a stress test that
#                     Chrome, VS Code and Terminal fail with method A (docs/PROGRESS.md);
#                     120 is close to normal typing.
#   --keys "…"        keys to type (default: the sample sentence below). Two marks are
#                     not typed as characters: ⌫ sends the Delete key; ⇄ switches the
#                     input source to U.S. (com.apple.keylayout.US, must be enabled) and
#                     back to Dấu with TISSelectInputSource from this script's process,
#                     which IMK does not report to the input method as a deactivation
#                     (ROADMAP M3). Example (D20, K7): --keys "hoc ⌫j " --expect "học "
#   --expect "…"      expected text (default: what the sample sentence must give)
#   --underline       force underline mode (D13: marked text, committed at the word end)
#                     for each app tested, without touching the user's Dấu settings.
#                     Debug input method only: the script writes the bundle ID into the
#                     global defaults key DauDebugForceUnderline (`defaults write -g`,
#                     the only domain both a shell can write and the sandboxed input
#                     method can read) before the app runs, and deletes the key at exit.
#                     The input method reads it at activation; the report shows
#                     `underline-on` when it took effect. By hand:
#                       defaults write -g DauDebugForceUnderline -array com.google.Chrome
#                       defaults delete -g DauDebugForceUnderline
#
# For each app: opens a new, empty window, selects the Dấu input source (which must be
# enabled already; nothing is enabled or disabled, N4), types, reads the text back,
# closes the window without saving, prints the text, PASS/FAIL and the input method's
# counts and timings for that app (scripts/perf-report.sh). The input source selected
# before and the clipboard (read through ⌘C in browsers, VS Code, Notes, Mail) are
# restored; the clipboard is emptied before each ⌘C so a failed copy cannot pass. A new
# document whose first letter the app capitalized by itself counts as PASS (noted).
#
# Edge, Firefox: the same local test page as Safari/Chrome, closed with ⌘W.
# Notes: a new note (⌘N) in the folder shown; it syncs while it exists. The script
# empties it, and Notes drops an empty new note (checked 30/10/2026: count unchanged
# after quitting). Mail: a new message (⌘N), keys go to the body focused through
# Accessibility, the To field stays empty, Send is never pressed; the body is emptied
# and the window closed with "Don't Save". Apps launched by the script stay running.
#
# Terminal: the keys go to the shell prompt of a new window. The script never presses
# Return; it clears the line with ⌃U before closing the window. Keys must not contain
# a newline.
#
# Safety: keys and shortcuts (⌘A ⌘C ⌘W ⌃U) are only sent while the app under test is
# frontmost (browsers: with the test page in front; VS Code: an Untitled editor; Mail:
# the New Message window). If another app comes to the front, the script stops sending
# keys and exits with status 3.
#
# Exit status 0 only if every app gives the expected text.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/scripts/selftest-typing"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BIN="$ROOT/build/selftest"
LOG=/usr/bin/log

# "carr" comes first: after Vietnamese text, macOS 27.2 autocorrect turns a typed "car"
# into "cả" (D4, known limit), which would hide what Dấu did.
KEYS='windows carr tooi yeeu tieengs Vieetj, Sunrise '
EXPECT='windows car tôi yêu tiếng Việt, Sunrise '
DELAY_MS=30
UNDERLINE=0
FORCE_KEY=DauDebugForceUnderline
APPS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --delay) DELAY_MS="${2:?--delay cần số ms}"; shift 2 ;;
    --keys) KEYS="${2?}"; shift 2 ;;
    --expect) EXPECT="${2?}"; shift 2 ;;
    --underline) UNDERLINE=1; shift ;;
    -h|--help) sed -n '2,57p' "$0"; exit 0 ;;
    all) APPS+=(textedit safari chrome vscode terminal); shift ;;
    textedit|safari|chrome|vscode|terminal|edge|firefox|notes|mail) APPS+=("$1"); shift ;;
    *) echo "Tham số không hợp lệ: $1" >&2; exit 2 ;;
  esac
done
[[ ${#APPS[@]} -gt 0 ]] || { sed -n '2,57p' "$0"; exit 2; }
US_SOURCE=com.apple.keylayout.US
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
if [[ "$KEYS" == *"⇄"* ]] && ! "$INPUT_SOURCE" enabled "$US_SOURCE" | grep -qx "$US_SOURCE"; then
  echo "⇄ cần nguồn $US_SOURCE đã bật (script không tự bật, N4)." >&2
  exit 1
fi
# ⇄: U.S., then back to Dấu, from this (unsandboxed) process.
SWITCH_CMD="$(printf '%q select %q; sleep 0.3; %q select %q; sleep 0.3' \
  "$BIN/input-source" "$US_SOURCE" "$BIN/input-source" "$DAU_SOURCE")"

WORK="$(mktemp -d)"
ORIGINAL_SOURCE="$("$INPUT_SOURCE" current)"
"$CLIPBOARD" save "$WORK/clipboard.plist" || exit 1
cleanup() {
  [[ $UNDERLINE == 1 ]] && defaults delete -g "$FORCE_KEY" >/dev/null 2>&1
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

# Every keystroke goes through a check that the app under test is frontmost (and, for
# browsers, that the test page is the front tab of its focused window), in the same osascript as the keys: if
# the user switches app while the script runs, nothing is typed into their window. A
# failed check stops the whole run (exit 3).
STOP_FILE=""   # set below, in $WORK
front_guard() { # process [window-title-substring] → AppleScript that errors if not front
  cat <<OSA
  tell application "System Events"
    set fp to name of first process whose frontmost is true
    if fp is not "$1" then error "frontmost is " & fp & ", not $1"
    if "${2:-}" is not "" then
      -- The focused window is the one that receives keys. "front window" can be a
      -- floating helper window instead (an Edge extension's popup, seen 30/10/2026).
      try
        set fw to name of (value of attribute "AXFocusedWindow" of process "$1")
      on error
        set fw to name of front window of process "$1"
      end try
      if fw does not contain "${2:-}" then error "front window of $1 is " & fw & ", not the test page"
    end if
  end tell
OSA
}
# Runs AppleScript $3 only if the guard for process $1 (title $2) passes.
# The check alone is retried for a few seconds first: right after `open`, Safari 27 may
# briefly report an untitled front window (seen 30/10/2026). Keys are still only sent
# once the check passes.
guarded() {
  local out _
  for _ in 1 2 3 4 5 6 7 8; do
    osascript -e "$(front_guard "$1" "$2")" -e 'return' >/dev/null 2>&1 && break
    sleep 0.4
  done
  if ! out="$(osascript -e "$(front_guard "$1" "$2")" -e "$3" 2>&1)"; then
    echo "DỪNG: $out — không gửi phím nào nữa" >&2
    : > "$STOP_FILE"
    return 1
  fi
  printf '%s' "$out"
}
stopped() { [[ -e "$STOP_FILE" ]]; }

type_keys() { # process [window-title-substring]
  stopped && return 1
  # The delay goes in as whole milliseconds: coercing "0.030" to a real follows the
  # user's locale (Vietnamese uses a decimal comma, so it became 30 seconds).
  guarded "$1" "${2:-}" 'return' >/dev/null || return 1
  osascript - "$KEYS" "$DELAY_MS" "$1" "$SWITCH_CMD" <<'OSA' || { echo "DỪNG: app đổi giữa chừng" >&2; : > "$STOP_FILE"; return 1; }
on run argv
  set s to item 1 of argv
  set d to ((item 2 of argv) as integer) / 1000
  set p to item 3 of argv
  set sw to item 4 of argv
  tell application "System Events"
    if (name of first process whose frontmost is true) is not p then error "frontmost changed"
    if d = 0 and s does not contain "⌫" and s does not contain "⇄" then
      keystroke s
    else
      set i to 0
      repeat with c in characters of s
        -- Re-check now and then; not every key, so the delay stays close to d.
        set i to i + 1
        if i mod 8 = 0 then
          if (name of first process whose frontmost is true) is not p then error "frontmost changed"
        end if
        if (c as text) is "⌫" then
          key code 51
        else if (c as text) is "⇄" then
          tell current application to do shell script sw
          if (name of first process whose frontmost is true) is not p then error "frontmost changed"
        else
          keystroke (c as text)
        end if
        if d > 0 then delay d
      end repeat
    end if
  end tell
end run
OSA
  sleep 0.8   # let asynchronous apps catch up before reading
}

# ⌘A ⌘C in the focused text field of process $1 (front tab title $2), then the plain
# text of the clipboard.
copy_all() {
  stopped && return 1
  # Empty the clipboard first so a failed copy cannot return an earlier run's text.
  printf '' | pbcopy
  guarded "$1" "${2:-}" 'tell application "System Events"
    keystroke "a" using {command down}
    delay 0.2
    keystroke "c" using {command down}
    delay 0.3
  end tell' >/dev/null || return 1
  "$CLIPBOARD" text
}

# --- one function per app; each prints the text typed ---------------------------------
run_textedit() {
  osascript -e 'tell application "TextEdit"' -e 'activate' -e 'make new document' -e 'end tell' >/dev/null
  sleep 0.8; select_dau; type_keys TextEdit
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
    # Only when the browser is frontmost with the test page in front.
    guarded "$1" "$PAGE_TITLE" 'tell application "System Events" to keystroke "w" using {command down}' \
      >/dev/null || break
    sleep 0.6
    [[ "$(window_names "$1")" == *"$PAGE_TITLE"* ]] || return 0
  done
  echo "CẢNH BÁO: còn tab \"$PAGE_TITLE\" trong $1, đóng tay giúp" >&2
}

run_safari() {
  open -a Safari "$PAGE"
  sleep 2.5; select_dau; type_keys Safari "$PAGE_TITLE"
  copy_all Safari "$PAGE_TITLE"
  close_test_tab Safari
}

run_chrome() {
  open -a "Google Chrome" "$PAGE"
  sleep 2.5; select_dau; type_keys "Google Chrome" "$PAGE_TITLE"
  copy_all "Google Chrome" "$PAGE_TITLE"
  close_test_tab "Google Chrome"
}

run_edge() {
  open -a "Microsoft Edge" "$PAGE"
  sleep 3; select_dau; type_keys "Microsoft Edge" "$PAGE_TITLE"
  copy_all "Microsoft Edge" "$PAGE_TITLE"
  close_test_tab "Microsoft Edge"
}

run_firefox() {
  open -a Firefox "$PAGE"
  sleep 3; select_dau; type_keys firefox "$PAGE_TITLE"
  copy_all firefox "$PAGE_TITLE"
  close_test_tab firefox
}

# Notes: a new note (⌘N) in the folder shown; read with ⌘A ⌘C, then emptied. Notes
# discards an empty new note, so no note is kept (the note syncs while it exists).
run_notes() {
  open -a Notes; sleep 2.5
  guarded Notes "" 'tell application "System Events" to keystroke "n" using {command down}' \
    >/dev/null || return 0
  sleep 1; select_dau; type_keys Notes
  copy_all Notes
  guarded Notes "" 'tell application "System Events"
    keystroke "a" using {command down}
    delay 0.1
    key code 51
  end tell' >/dev/null
}

# Mail: a new message (⌘N); the keys go to the body (focused through Accessibility), the
# To field stays empty and Send is never pressed. Read with ⌘A ⌘C, emptied, closed with
# ⌘W; if Mail asks to save the draft, "Don't Save"/"Delete" is chosen.
MAIL_COMPOSE="New Message"
run_mail() {
  open -a Mail; sleep 2
  guarded Mail "" 'tell application "System Events" to keystroke "n" using {command down}' \
    >/dev/null || return 0
  sleep 2
  guarded Mail "$MAIL_COMPOSE" 'tell application "System Events" to tell process "Mail"
    set value of attribute "AXFocused" of UI element 1 of scroll area 1 of group 1 of group 1 of front window to true
  end tell' >/dev/null || return 0
  sleep 0.3; select_dau; type_keys Mail "$MAIL_COMPOSE"
  copy_all Mail "$MAIL_COMPOSE"
  discard_front_document Mail "$MAIL_COMPOSE"
}

# Empties the focused text (⌘A ⌫), closes the front window (⌘W) of process $1 whose
# title contains $2, and answers a save prompt with the button that discards.
discard_front_document() {
  guarded "$1" "$2" 'tell application "System Events"
    keystroke "a" using {command down}
    delay 0.1
    key code 51
    delay 0.3
    keystroke "w" using {command down}
  end tell' >/dev/null || return 0
  sleep 1
  osascript - "$1" "$2" <<'OSA' >/dev/null 2>&1 || echo "CẢNH BÁO: còn cửa sổ \"$2\" của $1, đóng tay giúp (không lưu)" >&2
on run argv
  set p to item 1 of argv
  set t to item 2 of argv
  tell application "System Events" to tell process p
    repeat with w in windows
      if name of w contains t then
        if (count of sheets of w) = 0 then error "window still open"
        set done to false
        repeat with b in buttons of sheet 1 of w
          if name of b is in {"Don't Save", "Don’t Save", "Delete", "Delete Draft", "Revert Changes"} then
            click b
            set done to true
            exit repeat
          end if
        end repeat
        if not done then error "no discard button"
      end if
    end repeat
  end tell
end run
OSA
}

run_vscode() {
  open -a "Visual Studio Code"; sleep 2
  osascript -e 'tell application "Visual Studio Code" to activate' -e 'delay 0.5' \
    -e 'tell application "System Events" to keystroke "n" using {command down}' >/dev/null
  sleep 1.2; select_dau; type_keys Code Untitled
  copy_all Code Untitled
  # Empty the untitled editor so ⌘W closes it without asking to save.
  guarded Code Untitled 'tell application "System Events"
    keystroke "a" using {command down}
    delay 0.1
    key code 51
    delay 0.2
    keystroke "w" using {command down}
  end tell' >/dev/null
}

run_terminal() {
  # Remember the window opened here: it is the only one read and closed.
  local win
  win="$(osascript -e 'tell application "Terminal"' -e 'activate' -e 'do script ""' \
    -e 'return id of front window' -e 'end tell')" || return 0
  # Wait for the shell prompt: keys sent before the shell is ready (a slow zsh theme
  # takes ~3 s) are lost and never reach the input method.
  for _ in $(seq 1 30); do
    osascript -e "tell application \"Terminal\" to get contents of selected tab of window id $win" \
      2>/dev/null | grep -q '[^[:space:]]' && break
    sleep 0.2
  done
  sleep 0.7; select_dau; type_keys Terminal
  # The keys sit on the prompt's last line after the prompt itself: print that line;
  # the caller compares by suffix.
  osascript -e "tell application \"Terminal\" to get contents of selected tab of window id $win" \
    | grep -v '^[[:space:]]*$' | tail -1
  # ⌃U clears the line; never Return. Then close that window (only the shell runs in it).
  guarded Terminal "" 'tell application "System Events" to keystroke "u" using {control down}' >/dev/null
  sleep 0.2
  osascript -e "tell application \"Terminal\" to close window id $win" >/dev/null 2>&1
}

# --- run -------------------------------------------------------------------------------
trim_right() { sed -e 's/[[:space:]]*$//'; }
EXPECT_TRIMMED="$(printf '%s' "$EXPECT" | trim_right)"
FAILED=0
echo "Script sẽ mở: ${APPS[*]} (mỗi app một cửa sổ/tab mới, đóng lại sau khi đọc chữ; app nào chưa chạy thì vẫn để chạy)."
echo "Phím: \"$KEYS\"   mong đợi: \"$EXPECT\"   nghỉ giữa phím: ${DELAY_MS} ms"
bundle_id() {
  case "$1" in
    textedit) echo com.apple.TextEdit ;; safari) echo com.apple.Safari ;;
    chrome) echo com.google.Chrome ;; vscode) echo com.microsoft.VSCode ;;
    terminal) echo com.apple.Terminal ;;
    edge) echo com.microsoft.edgemac ;; firefox) echo org.mozilla.firefox ;;
    notes) echo com.apple.Notes ;; mail) echo com.apple.mail ;;
  esac
}
[[ $UNDERLINE == 1 ]] && echo "Chế độ gạch chân (D13) ép bằng $FORCE_KEY cho từng app."
STOP_FILE="$WORK/stop"
for app in "${APPS[@]}"; do
  if stopped; then echo "Đã dừng: app đang thử không còn ở trước (người dùng đang dùng máy?)."; FAILED=3; break; fi
  if [[ $UNDERLINE == 1 ]]; then
    defaults write -g "$FORCE_KEY" -array "$(bundle_id "$app")"
  fi
  start="$(date '+%Y-%m-%d %H:%M:%S')"
  got="$("run_$app")"
  sleep 0.3
  got_trimmed="$(printf '%s' "$got" | trim_right)"
  if [[ "$app" == terminal ]]; then
    ok=0; [[ "$got_trimmed" == *"$EXPECT_TRIMMED" ]] && ok=1
  else
    ok=0; [[ "$got_trimmed" == "$EXPECT_TRIMMED" ]] && ok=1
    # TextEdit, Notes, Pages… capitalize the first word of a new document by themselves
    # (macOS "Capitalize words automatically") when keys come slowly enough: not the
    # input method's doing.
    if [[ $ok == 0 ]]; then
      capitalized="$(printf '%s' "$EXPECT_TRIMMED" | perl -CS -pe 's/^(.)/\u$1/')"
      [[ "$got_trimmed" == "$capitalized" ]] && { ok=1; echo; echo "  (chữ đầu viết hoa do app tự viết hoa, không tính lỗi)"; }
    fi
  fi
  echo
  if [[ $ok == 1 ]]; then echo "PASS $app: \"$got_trimmed\""; else echo "FAIL $app: \"$got_trimmed\""; FAILED=1; fi
  "$LOG" show --start "$start" --style compact \
    --predicate "subsystem == \"$IM_ID\" AND category == \"perf\"" > "$WORK/perf.log" 2>/dev/null
  case "$app" in
    textedit) filter=TextEdit ;; safari) filter=Safari ;; chrome) filter=Chrome ;;
    vscode) filter=VSCode ;; terminal) filter=Terminal ;;
    *) filter="$(bundle_id "$app")" ;;
  esac
  "$ROOT/scripts/perf-report.sh" --input "$WORK/perf.log" --app "$filter" \
    | grep -E 'count_|handle_replace_us|selectedRange_us|insertText_us|attributedSubstring_us|event_' || true
  if [[ $UNDERLINE == 1 ]]; then
    if "$LOG" show --start "$start" --style compact \
        --predicate "subsystem == \"$IM_ID\" AND category == \"settings\"" 2>/dev/null \
        | grep -q "event=underline-on app=$(bundle_id "$app")"; then
      echo "  underline-on"
    else
      echo "  CẢNH BÁO: không thấy underline-on (bộ gõ chưa nhận khoá ép?)"
    fi
  fi
done
echo
if [[ $FAILED == 0 ]]; then echo "PASS"; else echo "FAIL"; fi
exit $FAILED
