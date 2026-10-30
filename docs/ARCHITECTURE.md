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
│  └─ DauShared/               # model cài đặt chung (phụ thuộc DauEngine), lưu trữ App Group + Darwin notification, xem trước bằng engine thật, model danh sách tương thích; sau này (M7): kiểm chữ ký danh sách tải về
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
- `CompatibilityList` (D7, D13): danh sách app được gắn nhãn "Đề xuất" — mỗi mục có các bundle ID của một app (một app có thể có nhiều ID), tên, cờ `suggestUnderline`, ghi chú cho người bảo trì (không hiện lên giao diện, N5); có `version`. Giải mã dễ dãi (D18): khoá lạ bị bỏ qua, mục hỏng hoặc không có bundle ID bị bỏ mà không mất các mục khác, file hỏng thành danh sách rỗng. Bản có sẵn là `Apps/Dau/Resources/CompatibilityList.json` trong app chủ (M3: VS Code và các app Electron/Chromium của `docs/COMPATIBILITY.md`, không có Terminal); test trong DauShared đọc chính file này. `DauSettings.ruleRows(suggesting:isInstalled:)` dựng các hàng "Quy tắc riêng": app đề xuất đã cài mà chưa có quy tắc hiện như quy tắc "Không gạch chân" nguồn `suggested` nhưng **không lưu**; người dùng đổi popup thì `setUnderline` lưu quy tắc nguồn `suggested` (đặt lại "Không gạch chân" thì xoá quy tắc đó); hàng giữ nguyên chỗ khi được lưu. Quy tắc người dùng tự thêm cho một app đề xuất vẫn là quy tắc người dùng. Bộ gõ **không** đọc danh sách: gạch chân chỉ theo quy tắc đã lưu (D13). M7: app chủ tải bản JSON có chữ ký cùng định dạng vào container App Group (bộ gõ không tải, N2), kiểm chữ ký rồi dùng bản hợp lệ có `version` cao hơn giữa bản tải về và bản có sẵn; chỉ cần thay chỗ `SettingsModel` lấy danh sách (`CompatibilityList.bundled()`).
- `TypingPreview`/`TypingExample`: chạy engine thật như bộ gõ. App chủ dùng chúng để dựng mọi ví dụ "phím → kết quả" trên giao diện (`SettingsSamples` trong `Apps/Dau`, có test ở `scripts/snapshot-settings`), nên mọi ví dụ đều do engine tính (N5).

### DauInputMethod (input method)
- Lớp con `IMKInputController`, mỗi client một instance và một `VietEngine` riêng (không có trạng thái toàn cục — khác OpenKey).
- `handle(_:client:)`: đưa phím vào engine qua `InPlaceComposer` (thay tại chỗ) hoặc `MarkedComposer` (gạch chân); cả hai là kiểu giá trị thuần, test bằng client giả. Thay tại chỗ: nếu `replace`, hỏi `selectedRange` một lần để có vị trí tuyệt đối rồi gọi `insertText(_:replacementRange:)` đúng một lần; phím đi thẳng không hỏi gì (N3, cách A đã chốt trong `DECISIONS.md`). Bản Debug có thêm một lần hỏi sau khi thay để chẩn đoán (`ReplaceDiag.swift`); số đo M2 làm trên Debug có lời gọi thừa này.
- Reset engine khi: click chuột, `activateServer`/`deactivateServer`, `commitComposition`, phím di chuyển con trỏ, `selectedRange` khác dự đoán, hoặc nguồn nhập liệu đổi mà IMK không báo (xem dưới).
- **Đổi nguồn nhập liệu không qua `activateServer`** (M3): chọn U.S. rồi chọn lại Dấu bằng `TISSelectInputSource` từ tiến trình khác thì IMK không gọi `deactivateServer`/`activateServer`, từ đang gõ dở bị gõ tiếp. Mỗi controller nghe thông báo phân tán `kTISNotifySelectedKeyboardInputSourceChanged` (bộ gõ có sandbox vẫn nhận được) và reset từ đang gõ (D4; chế độ gạch chân thì chốt chữ đang hiện). Thông báo đến trong 0,5 s sau `activateServer` của chính controller được coi là tiếng vọng của lần chuyển bằng phím tắt/menu và bị bỏ qua, để phím gõ ngay sau khi chuyển không mất từ. Đo 30/10/2026 (`scripts/selftest-typing/run.sh --keys "to⇄cj " textedit`, `⇄` = chọn U.S. rồi Dấu bằng `TISSelectInputSource` từ tiến trình của script): có bộ nghe ra "tocj" (log `source-changed-reset`), tắt bộ nghe ra "tọc". Kịch bản cũ của ROADMAP (`to` ⇄ `o`) không còn phân biệt được: sau reset, D20 đọc lại "to" và `o` cho "tô" đúng như D20 định.
- **"Thêm dấu cho từ đã gõ" (D20)**, `InPlaceComposer.addMarks`. Chỉ đọc chữ của ứng dụng khi **mọi** điều kiện sau đúng: công tắc bật (`addMarksToTypedWords`, D15 mặc định bật; đọc lúc `activateServer` và khi cài đặt đổi, không đọc theo phím); engine không có từ; phím là phím dấu/biến đổi của kiểu gõ (Telex, Telex đơn giản: `s f r x j z a e o w d`, hoa hay thường; VNI: chữ số); chưa biết chữ trước con trỏ là gì (đầu phiên, sau reset, click, ⌫ hay Return/Tab ra khỏi từ; sau một ký tự kết thúc từ gõ ở đây thì đã biết không phải chữ cái nên không đọc); phím hay click trước đó trên client này cách ít nhất 50 ms (`settleInterval`). Khi đó: một `selectedRange` (phải là con trỏ, không có vùng chọn), một `attributedSubstring` tối đa 16 đơn vị UTF-16 ngay trước con trỏ, lấy dãy chữ cái/dấu kết hợp/chữ số cuối cùng, `seed(displayed:)`, rồi đưa phím vào engine. `replace` thì một `insertText` thay đúng vùng chữ đã đọc (đếm UTF-16; mọi ký tự engine nhận đều thuộc BMP nên số scalar bằng số UTF-16, kể cả chữ NFD). `passThrough` thì phím đi thẳng và engine giữ từ để gõ tiếp (mốc khôi phục D4 = chữ đã đọc). Client trả `NSNotFound` hoặc `nil` thì thôi đọc tới lần `activateServer` sau; chuỗi sai độ dài, không có chữ, từ dài hơn phần đọc, có vùng chọn: không seed, phím xử lý như phím đầu của từ mới (D18). Chỉ xét chữ trước con trỏ: con trỏ giữa từ ("hoc|tap" + `j`) thì chỉ phần trước con trỏ đổi ("họctap").
  - Vì sao chờ 50 ms: app áp phím bất đồng bộ (Chromium, Electron, terminal) trả `selectedRange`/chữ từ ảnh chụp cũ khi phím dồn (M2: sai dưới 10–20 ms); chữ đọc từ ảnh chụp cũ có thể bị thay sai chỗ. Thử 30/10/2026 khi **không** chờ (`--keys "hoc ⌫j tooi ⌫s carr ⌫s hoc ⌫f "`, 0/10/30 ms): TextEdit, Safari, Chrome đúng ở mọi tốc độ; VS Code ở 0 ms đọc ảnh chụp cũ, không thấy từ nên phím đi thẳng ("hocj tôis"), không hỏng chữ. Không thấy ca hỏng nào; vẫn giữ 50 ms làm biên an toàn vì người quay lại sửa từ không gõ nhanh như vậy. Phím dồn dưới 50 ms thì D20 không áp dụng, phím đi thẳng.
  - Chi phí thêm (Debug, 30/10/2026, 120 ms/phím, mỗi app 6 phím D20): `selectedRange` trung vị khoảng 0,3–0,6 ms; `attributedSubstring` trung vị TextEdit ~1,0 ms, Safari ~3,7 ms (tối đa 12,8 ms), Chrome ~0,8 ms, VS Code ~0,7 ms. Chỉ tốn ở phím dấu ngay sau reset/⌫; câu mẫu gõ liền không đọc lần nào (test `sample`). Log perf: kind `seed` (đã thay), `seed_pass` (đọc, seed, phím đi thẳng), `seed_none` (đọc, không có từ), trường `read_ns`.
  - Chế độ gạch chân (D13) **không** dùng D20: chế độ này dành cho app có ảnh chụp vị trí không tin được và không bao giờ hỏi `selectedRange`, còn biến từ đã chốt thành marked text thì cần vị trí tuyệt đối. Ở app gạch chân, phím dấu sau reset bắt đầu từ mới như khi tắt D20 (cần ghi vào `DECISIONS.md`).
  - Terminal không chuyển phím ⌫ cho bộ gõ (đo 30/10/2026: không có dòng log nào cho ⌫), nên ở Terminal D20 sau ⌫ không bao giờ chạy, và ⌫ giữa từ không qua D32: "hoaf⌫␣" ra "ho " thay vì "hò "; "tooi⌫s" ra "tôs" (bộ theo dõi con trỏ D11 bắt lệch). Ghi vào ma trận tương thích.
- **Chế độ gạch chân (D13)**, bật khi quy tắc của app có `underline` (`MarkedComposer.swift`): từ đang gõ hiện bằng `setMarkedText` (app tự vẽ gạch chân), chốt bằng `insertText` khi kết thúc từ. Mọi lời gọi dùng `replacementRange` = NSNotFound (vùng marked hoặc con trỏ của app), nên **không bao giờ hỏi `selectedRange`** và không cần vị trí tuyệt đối — đó là lý do chế độ này đúng với app áp phím bất đồng bộ. Lời gọi mỗi phím (tối đa một, N3):
  - chữ cái/chữ số trong từ, Backspace trong từ (D32): một `setMarkedText` với cả từ (chuỗi rỗng = xoá marked text khi xoá hết từ);
  - ký tự kết thúc từ (D4): một `insertText` gồm từ (đã khôi phục nếu D4 bảo vậy) + ký tự đó, phím được nuốt;
  - Return, Tab, Enter bàn phím số: một `insertText` của từ rồi để app xử lý phím (ứng dụng chat vẫn gửi tin);
  - mũi tên, Esc, tổ hợp ⌘/⌃/⌥ và các sự kiện reset (click, `deactivateServer`, `commitComposition`, đổi nguồn/mode, đổi client, đổi cài đặt): một `insertText` của **đúng chữ đang hiện**, không khôi phục (D4), không làm mất chữ; rồi phím đi tiếp tới app. Chốt vào client đã nhận marked text nếu nó còn, không thì client của sự kiện; không còn client nào thì bỏ trạng thái (D18);
  - không có từ đang gõ: không gọi gì, phím đi thẳng (không có D20, xem trên).
  - Gõ đúp (D26), khôi phục (D4), độ dài từ (D33) giống hệt chế độ thay tại chỗ: `MarkedComposer` giữ bản sao chữ engine đang hiển thị và áp nguyên `Action` lên đó (test so khớp ngẫu nhiên với thay tại chỗ). Chuỗi chữ dài hơn 32 ký tự không dấu cách (chỉ xảy ra sau D33) được chốt sớm, phần còn lại của từ đi thẳng.
  - Đo 30/10/2026 (`scripts/selftest-typing/run.sh --underline`): Chrome, VS Code đúng ở 0, 5, 10, 30 ms/phím (thay tại chỗ sai ở 0 ms, VS Code sai cả 5 ms); Terminal đúng từ 5 ms, ở 0 ms chữ chốt đúng nhưng Terminal còn vẽ marked text cũ của từ cuối sau khi chốt cho tới phím kế tiếp.
- **Đầu vào từ IMK (D18)**, mọi điểm vào và cách xử lý giá trị lạ:
  - `handle(_:client:)`: event nil hoặc kiểu khác keyDown/mouseDown → `false`; client nil hoặc không phải `IMKTextInput` → reset, `false`; `characters` nil, rỗng, nhiều scalar, ký tự điều khiển → chỉ reset (`KeyRouter`); `selectedRange` `NSNotFound`, âm, có vùng chọn, ít chữ hơn số cần xoá → không thay (`CursorTracker`); `attributedSubstring` nil, sai độ dài, ký tự ngoài BMP → không seed.
  - `activateServer`/`deactivateServer`/`commitComposition` với client nil: reset (gạch chân: chốt vào client đã nhận marked text nếu còn, không thì bỏ); `activateServer(nil)` không giữ bundle ID của app trước.
  - `setValue(_:forTag:client:)`: giá trị nil không chuyển cho `super`; giá trị lạ chỉ reset.
  - `inputControllerWillClose`: reset, bỏ hai bộ nghe (cài đặt, nguồn nhập liệu).
  - `menu()` và hành động menu: không chạy ngoài main thread (`onMain` trả nil thay vì dừng chương trình); tham số của hành động không được dùng.
  - Thông báo cài đặt và nguồn nhập liệu: chỉ chạy trên main thread, tham chiếu yếu tới controller.
- Một input mode duy nhất "Dấu – Tiếng Việt" (`….Dau.vi`) khai báo trong Info.plist (`ComponentInputModeDict`), để ID nguồn đã bật không đổi và nguồn nằm trong nhóm Tiếng Việt (D2). Gõ tiếng Anh bằng nguồn ABC/U.S. của macOS. Bộ gõ không giữ trạng thái chế độ: IMK báo mode nào (kể cả `….Dau.en` còn sót từ bản cũ) cũng xử lý như tiếng Việt; `setValue(_:forTag:client:)` chỉ reset từ đang gõ (D4, D18). Không tự đổi nguồn nhập liệu theo app, không nhớ chế độ theo app (D5), không tự thông báo VoiceOver (D17).
- Quy tắc theo app: lựa chọn gạch chân đọc lúc `activateServer` và khi cài đặt đổi, không đọc theo phím. Đổi chế độ giữa chừng một từ thì chốt từ trước. Bundle ID của app lấy từ client lúc `activateServer`; Chrome đôi khi đưa client có `bundleIdentifier()` nil, khi đó dùng app đang ở trước (`NSWorkspace.frontmostApplication`). Bản Debug có thêm khoá `DauDebugForceUnderline` (mảng bundle ID, miền global `defaults write -g`) để ép gạch chân khi thử mà không đụng cài đặt người dùng; bản Release không đọc khoá này. Lúc khởi động, bộ gõ xoá khoá `rememberedInputModes` (nhớ chế độ theo app của bản cũ) khỏi defaults riêng của nó.
- Đọc cài đặt từ App Group; nghe thay đổi để áp dụng ngay. Không đọc danh sách tương thích: gạch chân chỉ theo quy tắc đã lưu (D13).
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
- Danh sách tương thích có sẵn trong app (`Resources/CompatibilityList.json`, xem DauShared); M7: Sparkle 2 + tải danh sách có chữ ký (D7). Sau khi cập nhật, chờ người dùng ngừng gõ rồi dừng tiến trình bộ gõ cũ.
- Phát hiện bộ gõ cũ đang chạy bằng `NSWorkspace.shared.runningApplications` (D14).

## Luồng một phím (chế độ Tiếng Việt)

1. IMK gọi `handle(event, client)` trên main thread. Bỏ qua event nil/bất thường (D18).
2. Phím điều khiển (mũi tên, ⌘-tổ hợp, Esc…) → reset engine, trả `false` cho hệ thống xử lý. Không khôi phục từ ở bước này (D4).
   Backspace → engine bỏ chữ cuối đang hiển thị và đặt lại dấu (D32); bộ đệm rỗng thì trả `false`.
3. Ký tự → `engine.handle(scalar)`:
   - `passThrough` → trả `false`.
   - `replace(n, s)` → `client.insertText(s, replacementRange: vùng n ký tự trước con trỏ)`, trả `true`.
   - Engine rỗng, phím dấu/biến đổi, chưa biết chữ trước con trỏ → D20: đọc từ trước con trỏ, `seed`, rồi như trên (xem mục DauInputMethod).
4. Ký tự kết thúc từ (Space, dấu câu, Enter, Tab — D4) → nếu từ không phải âm tiết tiếng Việt hợp lệ thì khôi phục phím gốc (D4), commit, reset.

Ở chế độ gạch chân (D13) bước 3–4 khác: chữ của từ đi vào marked text (`setMarkedText`) thay cho thay chữ tại chỗ, không hỏi `selectedRange`; kết thúc từ và mọi sự kiện reset chốt marked text bằng một `insertText` (xem mục DauInputMethod).

## Đo lường

- `os_signpost` quanh `engine.handle` và quanh lệnh gọi client; xem bằng Instruments.
- Test hiệu năng engine trong CI. Bài test tải nặng: xem mốc M6 trong `ROADMAP.md`.
