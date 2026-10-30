# Dấu

Bộ gõ tiếng Việt cho macOS, dựng trên InputMethodKit.

Dự án đang phát triển, chưa có bản phát hành. Bản Debug đã gõ được Telex/VNI (đã thử TextEdit, Safari, Chrome, VS Code, Terminal, Sublime Text; giới hạn còn lại ghi trong `docs/PROGRESS.md`); cài thử bằng `scripts/install-debug.sh`.

Tài liệu dự án nằm trong `docs/`: bắt đầu từ `docs/DECISIONS.md` (sổ quyết định) và `docs/ROADMAP.md` (lộ trình).

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `Apps/Dau` | app chủ SwiftUI (Cài đặt, cài bộ gõ, cập nhật) |
| `Apps/DauInputMethod` | bộ gõ (input method IMK), sandbox, không có quyền mạng |
| `Packages/DauEngine` | engine xử lý phím, Swift thuần, không dùng Foundation/AppKit |
| `Packages/DauShared` | phần dùng chung giữa app chủ và bộ gõ |

`Dau`, `DauInputMethod`… là định danh kỹ thuật của Dấu (tên target, tên gói), không phải tên hiển thị.

## Sinh project và build

Đã thử với Xcode 27.1 và Swift 6.4. Project Xcode được sinh từ `project.yml` bằng [XcodeGen](https://github.com/yonaskolb/XcodeGen); không sửa tay và không commit `Dau.xcodeproj`.

```sh
brew install xcodegen
xcodegen generate
```

Nếu `xcode-select -p` đang trỏ tới Command Line Tools thay vì Xcode, đặt `DEVELOPER_DIR` cho mọi lệnh `xcodebuild`, `xcrun`, `swift` (không cần đổi `xcode-select`):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Build Debug universal (Apple silicon + Intel):

```sh
xcodebuild -project Dau.xcodeproj -scheme Dau -configuration Debug \
  -destination 'generic/platform=macOS' build
xcodebuild -project Dau.xcodeproj -scheme DauInputMethod -configuration Debug \
  -destination 'generic/platform=macOS' build
```

Không có `-destination 'generic/platform=macOS'`, bản Debug chỉ build cho kiến trúc của máy đang chạy: Xcode build các Swift package local theo kiến trúc đang chạy, bỏ qua `ONLY_ACTIVE_ARCH` của app. Bản Release luôn là universal.

Scheme `Dau` build cả bộ gõ và nhúng nó vào `Dau.app/Contents/Library/Input Methods/DauInputMethod.app`.

## Chạy test

```sh
swift test --package-path Packages/DauEngine
swift test --package-path Packages/DauShared
```

Với Command Line Tools (Swift 6.4), `swift test` báo lỗi không tìm thấy plugin `TestingMacros` khi build sạch; dùng toolchain của Xcode qua `DEVELOPER_DIR` như trên.

## Định danh tạm thời

Bundle ID và Team ID chưa chốt. `project.yml` đang dùng `BUNDLE_ID_PREFIX = com.example.dau` và `DEVELOPMENT_TEAM` để trống; mọi cấu hình đang ký ad-hoc. Khi đổi `BUNDLE_ID_PREFIX`, phải sửa cả ID của các input mode (`com.example.dau.inputmethod.Dau.vi`, `.en`) trong `Apps/DauInputMethod/Info.plist` và `Apps/DauInputMethod/Resources/InfoPlist.xcstrings`, vì Xcode không thay biến trong khoá plist.

## Giấy phép

GPLv3, xem [LICENSE](LICENSE).
