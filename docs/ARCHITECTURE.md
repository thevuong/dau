# Kiến trúc

## Các thành phần

```
dau/
├─ .claude/agents/             # subagent: researcher, engine-dev, imk-dev, app-ui-dev, release-eng, auditor
├─ .claude/commands/           # /milestone, /audit
├─ project.yml                 # XcodeGen → Dau.xcodeproj
├─ Packages/
│  ├─ DauEngine/               # Swift package thuần, không Foundation/AppKit
│  │  ├─ Sources/DauEngine/    # VietEngine, bảng nguyên âm/dấu, quy tắc chính tả
│  │  └─ Tests/                # Swift Testing: ca Telex/VNI theo quy tắc chính tả, ca biên, test hiệu năng
│  └─ DauShared/               # khoá cài đặt, model danh sách tương thích + kiểm chữ ký
├─ Apps/
│  ├─ DauInputMethod/          # bundle input method (IMK), sandbox, KHÔNG có quyền mạng (N2)
│  └─ Dau/                     # app chủ SwiftUI: Cài đặt, onboarding, cập nhật (Sparkle), báo lỗi
└─ docs/                      # gồm OPENKEY-NOTES.md, viết ở mốc M1
```

### DauEngine
- `struct VietEngine: Sendable` giữ từ đang gõ trong bộ đệm dung lượng cố định (`TextBuffer`: tối đa 32 scalar lưu trong `SIMD32<UInt32>` — `InlineArray` cần macOS 26), không cấp phát mỗi phím (đã đo: 0 lần).
- API (mọi hàm `mutating`, trả `Action`):
  - `handle(_ key: Unicode.Scalar)`: chữ cái/chữ số nối vào từ; ký tự in ra khác (Space, Enter, Tab, dấu câu) kết thúc từ (D4) và nằm luôn trong `insert`; ký tự điều khiển, 0x7F và phím chức năng 0xF700–0xF8FF chỉ `reset()`.
  - `backspace()` (D32) — IMK phải gọi hàm này cho phím xoá, **không** đưa 0x7F vào `handle`.
  - `endWord()` — kết thúc từ không chèn ký tự, cho Return/Tab/Enter bàn phím số (0x03) khi IMK muốn để app tự xử lý phím.
  - `seed(displayed:) -> Bool` (D20) — nạp từ đọc được từ ứng dụng; nhận NFC hoặc NFD.
  - `reset()`, `isComposing`.
- `Action` = `.passThrough` (IMK trả `false`) | `.replace(deleteCount:insert: TextBuffer)`: xoá `deleteCount` **scalar** trước con trỏ và chèn `insert` trong một lần `insertText` (N3). Chữ Việt dựng sẵn đều nằm trong BMP nên số scalar bằng độ dài UTF-16, trừ khi từ được seed từ NFD — khi đó IMK tự đo chuỗi đã seed.
- Tuỳ chọn `EngineOptions`: kiểu gõ (`telex`, `simpleTelex`, `vni`), vị trí dấu (`modern`/`classic`), bỏ dấu tự do (D28), tự khôi phục (D4/D30/D33), `advanced: .off | .consonantShortcuts | .allowZFWJ` (một enum nên hai mục loại trừ nhau — D22).
- Đường nóng không dùng `String`, `any Protocol`, closure, không import Foundation. Engine dựng thẳng ký tự NFC từ bảng (D3), không chuẩn hoá lúc chạy.

### DauInputMethod (input method)
- Lớp con `IMKInputController`, mỗi client một instance và một `VietEngine` riêng (không có trạng thái toàn cục — khác OpenKey).
- `handle(_:client:)`: đưa phím vào engine; nếu `replace`, gọi `insertText(_:replacementRange:)` đúng một lần (N3). Cách lấy vị trí tuyệt đối: xem câu hỏi mở A/B trong `DECISIONS.md`.
- Reset engine khi: click chuột, `activateServer`/`deactivateServer`, `commitComposition`, phím di chuyển con trỏ, hoặc `selectedRange` khác dự đoán.
- App trong danh sách tương thích cần gạch chân: dùng `setMarkedText` thay cho thay chữ tại chỗ (D13).
- Hai input mode "Tiếng Việt" và "Tiếng Anh" khai báo trong Info.plist (`ComponentInputModeDict`); ở chế độ Anh, mọi phím đi thẳng (D2).
- Đọc cài đặt và danh sách tương thích từ App Group; nghe thay đổi để áp dụng ngay.
- Entitlements: App Sandbox, App Group, tạm thêm `temporary-exception.mach-register.global-name` cho tên kết nối IMK (theo mẫu IMK có sandbox; M2 kiểm chứng có cần không). **Không** `com.apple.security.network.client`.
- Khoá Info.plist cần nghiên cứu và xác minh theo tài liệu Apple / mẫu IMK: `InputMethodConnectionName`, `InputMethodServerControllerClass`, `LSBackgroundOnly`, `TISInputSourceID`, `TISIntendedLanguage`, `ComponentInputModeDict`, `tsInputModeListKey`, icon cho từng mode.

### Dau (app chủ)
- SwiftUI `Settings` với sidebar 4 mục, onboarding 3 bước, sheet báo lỗi (xem `docs/UI.md`).
- Cài bộ gõ: chép bundle `DauInputMethod.app` từ trong app chủ vào `~/Library/Input Methods`, đăng ký qua Text Input Sources. Gỡ cài đặt và quay về bản trước cũng nằm ở đây (D16).
- Sparkle 2 + tải danh sách tương thích có chữ ký (D7). Sau khi cập nhật, chờ người dùng ngừng gõ rồi dừng tiến trình bộ gõ cũ.
- Phát hiện bộ gõ cũ đang chạy bằng `NSWorkspace.shared.runningApplications` (D14).

## Luồng một phím (chế độ Tiếng Việt)

1. IMK gọi `handle(event, client)` trên main thread. Bỏ qua event nil/bất thường (D18).
2. Phím điều khiển (mũi tên, ⌘-tổ hợp, Esc…) → reset engine, trả `false` cho hệ thống xử lý. Không khôi phục từ ở bước này (D4).
   Backspace → engine bỏ chữ cuối đang hiển thị và đặt lại dấu (D32); bộ đệm rỗng thì trả `false`.
3. Ký tự → `engine.handle(scalar)`:
   - `passThrough` → trả `false`.
   - `replace(n, s)` → `client.insertText(s, replacementRange: vùng n ký tự trước con trỏ)`, trả `true`.
4. Ký tự kết thúc từ (Space, dấu câu, Enter, Tab — D4) → nếu từ không phải âm tiết tiếng Việt hợp lệ thì khôi phục phím gốc (D4), commit, reset.

## Đo lường

- `os_signpost` quanh `engine.handle` và quanh lệnh gọi client; xem bằng Instruments.
- Test hiệu năng engine trong CI. Bài test tải nặng: xem mốc M6 trong `ROADMAP.md`.
