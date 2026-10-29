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
- `struct VietEngine: Sendable` giữ trạng thái từ đang gõ trong bộ đệm `[Unicode.Scalar]` có sẵn dung lượng, không cấp phát lại mỗi phím.
- API dạng hàm thuần: `mutating func handle(_ key: Unicode.Scalar) -> Action`, với `Action` là `passThrough` hoặc `replace(deleteCount:insert:)`; `reset()` khi lệch ngữ cảnh.
- Tuỳ chọn: kiểu gõ (Telex, VNI, Telex đơn giản), vị trí dấu (mới/cũ), bỏ dấu tự do, tự khôi phục từ không phải tiếng Việt, nhóm nâng cao. Gõ đúp phím dấu thì bỏ dấu và giữ chữ gốc (chuẩn Telex).
- Đường nóng không dùng `String`, `any Protocol`, closure. Chỉ chuẩn hoá NFC khi sinh chuỗi kết quả.

### DauInputMethod (input method)
- Lớp con `IMKInputController`, mỗi client một instance và một `VietEngine` riêng (không có trạng thái toàn cục — khác OpenKey).
- `handle(_:client:)`: đưa phím vào engine; nếu `replace`, gọi `insertText(_:replacementRange:)` đúng một lần (N3). Cách lấy vị trí tuyệt đối: xem câu hỏi mở A/B trong `DECISIONS.md`.
- Reset engine khi: click chuột, `activateServer`/`deactivateServer`, `commitComposition`, phím di chuyển con trỏ, hoặc `selectedRange` khác dự đoán.
- App trong danh sách tương thích cần gạch chân: dùng `setMarkedText` thay cho thay chữ tại chỗ (D13).
- Hai input mode "Tiếng Việt" và "Tiếng Anh" khai báo trong Info.plist (`ComponentInputModeDict`); ở chế độ Anh, mọi phím đi thẳng (D2).
- Đọc cài đặt và danh sách tương thích từ App Group; nghe thay đổi để áp dụng ngay.
- Entitlements: App Sandbox, App Group. **Không** `com.apple.security.network.client`.
- Khoá Info.plist cần nghiên cứu và xác minh theo tài liệu Apple / mẫu IMK: `InputMethodConnectionName`, `InputMethodServerControllerClass`, `LSBackgroundOnly`, `TISInputSourceID`, `TISIntendedLanguage`, `ComponentInputModeDict`, `tsInputModeListKey`, icon cho từng mode.

### Dau (app chủ)
- SwiftUI `Settings` với sidebar 4 mục, onboarding 3 bước, sheet báo lỗi (xem `docs/UI.md`).
- Cài bộ gõ: chép bundle `DauInputMethod.app` từ trong app chủ vào `~/Library/Input Methods`, đăng ký qua Text Input Sources. Gỡ cài đặt và quay về bản trước cũng nằm ở đây (D16).
- Sparkle 2 + tải danh sách tương thích có chữ ký (D7). Sau khi cập nhật, chờ người dùng ngừng gõ rồi dừng tiến trình bộ gõ cũ.
- Phát hiện bộ gõ cũ đang chạy bằng `NSWorkspace.shared.runningApplications` (D14).

## Luồng một phím (chế độ Tiếng Việt)

1. IMK gọi `handle(event, client)` trên main thread. Bỏ qua event nil/bất thường (D18).
2. Phím điều khiển (mũi tên, ⌘-tổ hợp, Esc…) → reset engine, trả `false` cho hệ thống xử lý.
3. Ký tự → `engine.handle(scalar)`:
   - `passThrough` → trả `false`.
   - `replace(n, s)` → `client.insertText(s, replacementRange: vùng n ký tự trước con trỏ)`, trả `true`.
4. Ký tự kết thúc từ (Space, dấu câu, Enter, Tab — D4) → nếu từ không phải âm tiết tiếng Việt hợp lệ thì khôi phục phím gốc (D4), commit, reset.

## Đo lường

- `os_signpost` quanh `engine.handle` và quanh lệnh gọi client; xem bằng Instruments.
- Test hiệu năng engine trong CI. Bài test tải nặng: xem mốc M6 trong `ROADMAP.md`.
