#!/usr/bin/env bash
# Prints per-app timing of the input method from the unified log (open question A/B):
# p50/p99 of `selectedRange()`, `insertText`, and the whole `handle`, plus event counts.
#
# The input method logs one line per key (Debug builds, or Release with the defaults key
# DauPerfLog = YES), category "perf": event kind, durations in ns and the client app's
# bundle ID. Never the text typed (D8).
#
# Usage:
#   scripts/perf-report.sh                      last 1 hour, all apps
#   scripts/perf-report.sh --last 10m           any `log show --last` value
#   scripts/perf-report.sh --app TextEdit       bundle ID or part of it, any case
#                                               (TextEdit, com.apple.Safari, chrome, slack)
#   scripts/perf-report.sh --input FILE         parse saved `log show --style compact` output
#
# Subsystem = the input method's bundle ID, read from the installed bundle; override with
# DAU_IM_BUNDLE_ID.
set -euo pipefail

LAST="1h"
APP_FILTER=""
INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --last) LAST="${2:?--last cần giá trị, ví dụ 10m}"; shift 2 ;;
    --app) APP_FILTER="${2:?--app cần tên app hoặc bundle ID}"; shift 2 ;;
    --input) INPUT="${2:?--input cần đường dẫn file}"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Tham số không hợp lệ: $1" >&2; exit 2 ;;
  esac
done

INSTALLED_PLIST="$HOME/Library/Input Methods/DauInputMethod.app/Contents/Info.plist"
SUBSYSTEM="${DAU_IM_BUNDLE_ID:-}"
if [[ -z "$SUBSYSTEM" && -f "$INSTALLED_PLIST" ]]; then
  SUBSYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALLED_PLIST" 2>/dev/null || true)"
fi
SUBSYSTEM="${SUBSYSTEM:-com.codefastlabs.dau.inputmethod.Dau}"

read_log() {
  if [[ -n "$INPUT" ]]; then
    cat "$INPUT"
  else
    /usr/bin/log show --last "$LAST" --style compact \
      --predicate "subsystem == \"$SUBSYSTEM\" AND category == \"perf\""
  fi
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Step 1: one row per measurement: "<app> <metric> <value>".
read_log | awk -v want="$(printf '%s' "$APP_FILTER" | tr '[:upper:]' '[:lower:]')" '
  function field(name,   i, n, parts) {
    for (i = 1; i <= NF; i++) {
      if (index($i, name "=") == 1) { return substr($i, length(name) + 2) }
    }
    return ""
  }
  / key kind=/ {
    app = field("app"); kind = field("kind")
    if (app == "" || kind == "") next
    if (want != "" && index(tolower(app), want) == 0) next
    print app, "count_" kind, 1
    h = field("handle_ns"); s = field("sel_ns"); i = field("ins_ns")
    if (h != "") print app, "handle_us", h / 1000
    if (kind == "replace" || kind == "mismatch" || kind == "unsupported") {
      if (h != "") print app, "handle_replace_us", h / 1000
    }
    if (s != "" && s + 0 >= 0) print app, "selectedRange_us", s / 1000
    if (i != "" && i + 0 >= 0) print app, "insertText_us", i / 1000
  }
  / event name=/ {
    app = field("app"); name = field("name")
    if (want != "" && index(tolower(app), want) == 0) next
    if (app != "" && name != "") print app, "event_" name, 1
  }
' | sort -k1,1 -k2,2 -k3,3g > "$TMP"

if [[ ! -s "$TMP" ]]; then
  echo "Không có số đo nào (subsystem $SUBSYSTEM, --last $LAST${APP_FILTER:+, app $APP_FILTER})."
  echo "Kiểm tra: bộ gõ bản Debug đã cài và đã gõ thử trong khoảng thời gian này chưa?"
  if [[ -n "$APP_FILTER" ]]; then
    echo "--app so khớp một phần bundle ID (không phân biệt hoa thường), không nhận PID."
    echo "Các app có số đo trong khoảng này:"
    read_log | grep -o 'app=[^ ]*' | sort -u | sed 's/^app=/  /' || true
  fi
  exit 0
fi

echo "Subsystem: $SUBSYSTEM   Khoảng: ${INPUT:-log show --last $LAST}"
echo "Đơn vị: µs. p50/p99 theo hạng gần nhất (nearest rank). n = số mẫu."

# Step 2: per (app, metric) group, counts for count_/event_ rows, p50/p99/max otherwise.
awk '
  function flush(   i50, i99) {
    if (n == 0) return
    if (metric ~ /^(count_|event_)/) {
      printf "  %-22s %8d\n", metric, n
    } else {
      i50 = int((50 * n + 99) / 100); if (i50 < 1) i50 = 1
      i99 = int((99 * n + 99) / 100); if (i99 < 1) i99 = 1
      printf "  %-22s n=%-7d p50=%-10.1f p99=%-10.1f max=%.1f\n", metric, n, v[i50], v[i99], v[n]
    }
  }
  {
    if ($1 != app) {
      flush(); n = 0; metric = ""
      app = $1; printf "\n%s\n", app
    }
    if ($2 != metric) { flush(); n = 0; metric = $2 }
    n++; v[n] = $3
  }
  END { flush() }
' "$TMP"
