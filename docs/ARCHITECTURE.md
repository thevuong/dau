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
│  └─ DauShared/               # model cài đặt chung (phụ thuộc DauEngine), lưu trữ App Group + Darwin notification, xem trước bằng engine thật; sau này: danh sách tương thích + kiểm chữ ký
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

### DauShared
- Phụ thuộc DauEngine (để đổi cài đặt sang `EngineOptions` và chạy engine thật cho phần xem trước); không dùng trong đường nóng của engine.
- `DauSettings` (Sendable, Codable, mặc định D15; `advanced` là một enum nên D22 không thể bật cả hai), `AppRule` (D5, D13: bundle ID, tên hiển thị, gạch chân, nguồn "Đề xuất"/người dùng; không có chế độ Việt/Anh). Giải mã dễ dãi: khoá lạ hoặc khoá cũ (`rememberModePerApp`, `mode` của quy tắc, từ bản trước 30/10/2026) bị bỏ qua, quy tắc cũ giữ lựa chọn gạch chân; lần lưu sau không ghi lại các khoá đó (D18). Hệ quả: quy tắc cũ chỉ có "Tiếng Anh" trở thành quy tắc không làm gì (không gạch chân), và Dấu gõ tiếng Việt ở app đó; người dùng không được báo. Chấp nhận vì chưa có bản phát hành nào.
- `SettingsStore`: lưu cả cài đặt thành một JSON dưới khoá `settings` trong UserDefaults suite = App Group (`DauAppGroupIdentifier` trong Info.plist, giá trị `$(TeamIdentifierPrefix)$(BUNDLE_ID_PREFIX).shared`); sau mỗi lần lưu phát Darwin notification `<suite>.settingsDidChange`; `observeChanges` cho bộ gõ áp dụng ngay.
- `TypingPreview`/`TypingExample`: chạy engine thật như bộ gõ. App chủ dùng chúng để dựng mọi ví dụ "phím → kết quả" trên giao diện (`SettingsSamples` trong `Apps/Dau`, có test ở `scripts/snapshot-settings`), nên mọi ví dụ đều do engine tính (N5).

### DauInputMethod (input method)
- Lớp con `IMKInputController`, mỗi client một instance và một `VietEngine` riêng (không có trạng thái toàn cục — khác OpenKey).
- `handle(_:client:)`: đưa phím vào engine; nếu `replace`, hỏi `selectedRange` một lần để có vị trí tuyệt đối rồi gọi `insertText(_:replacementRange:)` đúng một lần; phím đi thẳng không hỏi gì (N3, cách A đã chốt trong `DECISIONS.md`). Bản Debug có thêm một lần hỏi sau khi thay để chẩn đoán (`ReplaceDiag.swift`); số đo M2 làm trên Debug có lời gọi thừa này.
- Reset engine khi: click chuột, `activateServer`/`deactivateServer`, `commitComposition`, phím di chuyển con trỏ, hoặc `selectedRange` khác dự đoán.
- App trong danh sách tương thích cần gạch chân: dùng `setMarkedText` thay cho thay chữ tại chỗ (D13).
- Một input mode duy nhất "Dấu – Tiếng Việt" (`….Dau.vi`) khai báo trong Info.plist (`ComponentInputModeDict`), để ID nguồn đã bật không đổi và nguồn nằm trong nhóm Tiếng Việt (D2). Gõ tiếng Anh bằng nguồn ABC/U.S. của macOS. Bộ gõ không giữ trạng thái chế độ: IMK báo mode nào (kể cả `….Dau.en` còn sót từ bản cũ) cũng xử lý như tiếng Việt; `setValue(_:forTag:client:)` chỉ reset từ đang gõ (D4, D18). Không tự đổi nguồn nhập liệu theo app, không nhớ chế độ theo app (D5), không tự thông báo VoiceOver (D17).
- Quy tắc theo app: chỉ đọc lựa chọn gạch chân lúc `activateServer` (D13, chưa làm — ghi log `underline-rule-ignored`). Lúc khởi động, bộ gõ xoá khoá `rememberedInputModes` (nhớ chế độ theo app của bản cũ) khỏi defaults riêng của nó.
- Đọc cài đặt và danh sách tương thích từ App Group; nghe thay đổi để áp dụng ngay.
- Entitlements: App Sandbox, App Group, tạm thêm `temporary-exception.mach-register.global-name` cho tên kết nối IMK (theo mẫu IMK có sandbox). Chưa thử bỏ đi để biết có cần không: để M3. **Không** `com.apple.security.network.client`.
- Khoá Info.plist đang dùng (chạy được trên macOS 27 ở M2): `InputMethodConnectionName`, `InputMethodServerControllerClass`, `LSBackgroundOnly`, `TISInputSourceID`, `TISIntendedLanguage`, `ComponentInputModeDict` (một mode `.vi`, icon template V), `tsInputMethodIconFileKey`, `TISIconIsTemplate`; thêm `DauHostAppBundleIdentifier`, `DauAppGroupIdentifier` của riêng Dấu.

### Dau (app chủ)
- **Cửa sổ Cài đặt:** scene SwiftUI `Window` (không dùng scene `Settings`), là cửa sổ chính của app. ⌘, mở lại cửa sổ. Cỡ mặc định 820×600, tối thiểu 760×520. Điểm vào là `main.swift`: nó ghim bản địa hoá `vi` trước khi AppKit chạy.
  - Bố cục: `NavigationSplitView`, sidebar cố định 220 pt, có ô tìm và 4 mục. Ô icon ở sidebar là ảnh vẽ theo SVG của mockup.
  - Mỗi trang là `SettingsPage`: `ScrollView` gồm các card tự xếp theo mockup. Nền chọn trong các màu hệ thống, control đều là control hệ thống (D9). Không dùng `Form`, vì `Form(.grouped)` tự giới hạn độ rộng nội dung.
- **Header:** tiêu đề mục là một ToolbarItem `.navigation` (macOS 26+ tắt nền glass của item này). Tiêu đề hệ thống bị gỡ, nên mọi mục có cùng toolbar và tiêu đề không đổi chỗ. Mục Ứng dụng có thêm ô tìm và nút "+": hai item riêng, ngăn bằng `ToolbarSpacer(.fixed)` để macOS 26+ không gộp thành một khối glass.
- **Cuộn:**
  - Scroll view lấp cột chi tiết tới mép phải cửa sổ. Nội dung lấp độ rộng scroll view, không tính độ rộng bằng tay.
  - Trên macOS 26+, nội dung cuộn dưới header được che bằng `scrollEdgeEffectStyle(.hard, for: .top)`.
  - Thanh cuộn theo cài đặt hệ thống. Kiểu overlay không chiếm chỗ. Kiểu legacy chỉ hiện ở mục cần cuộn; mục đó hẹp hơn đúng độ rộng thanh cuộn, còn vị trí mọi thứ giữ nguyên (xem `docs/UI-CHECKS.md`).
- **Control hệ thống được bọc:**
  - `SegmentedPicker` bọc `NSSegmentedControl`: `Picker(.segmented)` trên macOS giữ độ rộng nội tại và căn giữa, không trải theo khung như mockup (ví dụ "Kiểu gõ" trải hết card).
  - `SearchField` bọc `NSSearchField`: cần ô tìm có độ rộng cố định trong toolbar và trong sheet, mà `.searchable` không cho đặt.
- Bản Debug có cờ chạy không mở cửa sổ (`--print-…`) và `--capture-window` để chụp cửa sổ thật; `scripts/check-settings-window` dùng cờ này để kiểm giao diện.
- Onboarding 3 bước và sheet báo lỗi: chưa làm (M5, M7; xem `docs/UI.md`).
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
