#!/usr/bin/env bash
# Builds the Debug input method (universal) and installs it for the current user in
# ~/Library/Input Methods, then stops the old input method process so macOS loads the
# new one on the next key press.
#
# It does NOT register or enable the input source: that is the user's action in
# System Settings (N4). The steps are printed at the end.
#
# Usage:
#   scripts/install-debug.sh               build, install, stop the old process
#   scripts/install-debug.sh --build-only  build and check only, touch nothing outside the repo
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED="$ROOT/build/DerivedData"
PROCESS_NAME="DauInputMethod"            # CFBundleExecutable of the input method
BUNDLE_NAME="$PROCESS_NAME.app"
DEST_DIR="$HOME/Library/Input Methods"

BUILD_ONLY=0
case "${1:-}" in
  "") ;;
  --build-only) BUILD_ONLY=1 ;;
  -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "Tham số không hợp lệ: $1 (dùng --build-only hoặc không có tham số)" >&2; exit 2 ;;
esac

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Cần XcodeGen: brew install xcodegen" >&2
  exit 1
fi

echo "==> Sinh Dau.xcodeproj"
(cd "$ROOT" && xcodegen generate --quiet)

echo "==> Build Debug universal (scheme DauInputMethod)"
xcodebuild \
  -project "$ROOT/Dau.xcodeproj" \
  -scheme DauInputMethod \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -quiet \
  build

BUILT="$DERIVED/Build/Products/Debug/$BUNDLE_NAME"
if [[ ! -d "$BUILT" ]]; then
  echo "Không tìm thấy $BUILT sau khi build." >&2
  exit 1
fi

echo "==> Kiểm tra bản build"
ARCHS="$(lipo -archs "$BUILT/Contents/MacOS/$PROCESS_NAME")"
echo "    kiến trúc: $ARCHS"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "Bản build không phải universal (D1)." >&2
  exit 1
fi
codesign --verify --strict "$BUILT"
if codesign -d --entitlements - --xml "$BUILT" 2>/dev/null | grep -q "com.apple.security.network"; then
  echo "Bộ gõ có quyền mạng — trái N2. Dừng." >&2
  exit 1
fi
echo "    chữ ký hợp lệ, không có quyền mạng (N2)"

if [[ "$BUILD_ONLY" == 1 ]]; then
  echo "==> --build-only: không cài. Bản build: $BUILT"
  exit 0
fi

echo "==> Cài vào $DEST_DIR"
mkdir -p "$DEST_DIR"
rm -rf "${DEST_DIR:?}/$BUNDLE_NAME"
ditto "$BUILT" "$DEST_DIR/$BUNDLE_NAME"

echo "==> Dừng tiến trình bộ gõ cũ (nếu đang chạy)"
if killall "$PROCESS_NAME" 2>/dev/null; then
  echo "    đã dừng $PROCESS_NAME; macOS sẽ chạy bản mới ở lần gõ tiếp theo"
else
  echo "    không có tiến trình $PROCESS_NAME đang chạy"
fi

cat <<'EOF'

Đã cài bản Debug của Dấu. Các bước còn lại do bạn làm trên máy:

  1. Mở Cài đặt hệ thống › Bàn phím. Ở mục "Nguồn đầu vào" (Input Sources),
     bấm "Sửa…" (Edit…).
  2. Bấm nút "+" ở góc dưới bên trái danh sách.
  3. Chọn ngôn ngữ "Tiếng Việt" (Vietnamese), chọn "Dấu – Tiếng Việt", bấm "Thêm".
     Dấu chỉ có nguồn này (D2). Gõ tiếng Anh bằng ABC/U.S. sẵn có của macOS; nếu
     danh sách còn "Dấu – Tiếng Anh" từ bản cũ thì bấm "–" để bỏ nó.
  4. Nếu không thấy "Dấu" trong danh sách: đăng xuất rồi đăng nhập lại, sau đó làm lại
     từ bước 1 (lần cài đầu, hệ thống có thể chưa quét thư mục ~/Library/Input Methods).
  5. Chọn "Dấu – Tiếng Việt" trên menu nguồn nhập liệu ở thanh menu, hoặc bằng phím tắt
     chuyển nguồn nhập liệu của macOS.
  6. Tắt các bộ gõ tiếng Việt khác đang chạy (OpenKey, EVKey, GoTiengViet…) trước khi thử.
  7. Gõ thử theo docs/M2-TESTING.md, rồi chạy scripts/perf-report.sh để lấy số đo.

Gỡ bản thử: xoá ~/Library/Input Methods/DauInputMethod.app, bỏ "Dấu" khỏi Nguồn đầu vào,
rồi đăng xuất.
EOF
