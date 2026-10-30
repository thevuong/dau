# Ma trận tương thích

Bảng ghi kết quả thử Dấu trong từng ứng dụng (M3, việc T5 lập khung; T6 chạy và điền). Khung lập ngày 30/10/2026 trên máy phát triển: macOS 27.2 (26B123), Apple M1 Pro. Dòng nào chưa thử ghi "chưa thử"; không điền ô nào bằng phỏng đoán.

## 1. Mục đích

- Biết Dấu gõ đúng hay sai trong từng ứng dụng, ở tốc độ nào, và vì sao.
- Là nguồn duy nhất cho **danh sách tương thích**: ứng dụng nào cần gạch chân (marked text, D13) thì vào danh sách theo bundle ID. Danh sách có sẵn trong bản build (M3, việc T3: `Apps/Dau/Resources/CompatibilityList.json`, model `CompatibilityList` trong DauShared) và về sau được cập nhật riêng bằng file JSON có chữ ký do app chủ tải (D7); tiến trình bộ gõ không tải gì (N2). Trong trang Ứng dụng, các quy tắc đến từ danh sách hiện nhãn "Đề xuất" (D5, `AppRule` nguồn `suggested`).
- Ai vào danh sách: theo D13 (chốt 30/10/2026). Danh sách đề xuất ban đầu là VS Code, các app Electron/Chromium và Firefox; app chưa đo được xếp theo công nghệ giao diện (mục 2, mục 3), app đã đo thì theo số đo ở mục 5. Terminal không đề xuất. Mặc định mọi app không gạch chân; nhãn "Đề xuất" chỉ gợi ý, người dùng tự bật.
- Bảng này không phải lời hứa (N5). Không chép kết quả lên giao diện hay website ("chạy tốt trong mọi app", danh sách logo ứng dụng…) trước khi phiên chính tổng hợp; website giữ ô trống như `[Kết quả bài test tải nặng]`.

Tiêu chí "cần gạch chân" đã chốt ở D13 (30/10/2026): gạch chân chỉ là đề xuất, không tự bật. Theo số đo M3, thay tại chỗ chỉ sai khi phím cách nhau dưới 10 ms, từ 10 ms đều đúng; app sai ở 0–5 ms mà gạch chân sửa được thì được đề xuất (Firefox thêm theo cách này), Terminal sai ở 0 ms cả khi gạch chân nên không đề xuất.

## 2. Vì sao ghi công nghệ giao diện

Dấu thay chữ tại chỗ: ở phím có thay chữ, hỏi `selectedRange` một lần rồi gọi `insertText(_:replacementRange:)` (cách A, D11, N3). Cách này cần ứng dụng trả vị trí con trỏ đúng **ngay lúc hỏi**.

- Header `IMKInputSession.h` (HIToolbox, SDK macOS 27.0) ghi: nếu client không hỗ trợ TSMDocumentAccess thì `selectedRange` trả `NSNotFound` và `replacementRange` bị bỏ qua; header cũng ghi client như vậy "cực kỳ hiếm" và hệ thống văn bản Cocoa có hỗ trợ. Bộ gõ đếm trường hợp này là `unsupported`. Trang tài liệu web của `IMKTextInput` trả 404 (đã ghi ở `docs/OPENKEY-NOTES.md` mục 5); phía ứng dụng: https://developer.apple.com/documentation/appkit/nstextinputclient/selectedrange() và https://developer.apple.com/documentation/appkit/nstextinputclient/inserttext(_:replacementrange:)
- Lỗi đã đo được ở M2 không phải `unsupported` mà là **ứng dụng áp phím bất đồng bộ**: Chrome, VS Code, Terminal trả một vị trí cũ khi phím đến dồn (mục 6.2). Vì vậy công nghệ giao diện là dấu hiệu dự đoán tốt nhất trước khi thử: Chromium/Electron và terminal dễ gặp lỗi này; AppKit/WebKit (TextEdit, Safari) thì chưa thấy. Đây là suy luận từ 5 ứng dụng, cần kiểm chứng trên từng ứng dụng.
- Gạch chân dùng `setMarkedText(_:selectionRange:replacementRange:)`; theo cùng header, chuỗi thường sẽ được gạch chân mặc định. Gạch chân có giải được lỗi bất đồng bộ không: T1 đã đo (30/10/2026, D13, `docs/PROGRESS.md` nhật ký 30/10): sửa được Chrome và VS Code ở 0 ms; Terminal ở 0 ms vẫn lỗi (còn vẽ marked text cũ). Kết quả từng app ở mục 5.

Cách ghi công nghệ ở mục 3: đọc từ bundle trên máy này (thư mục `Contents/Frameworks`, `otool -L` của file chạy; chỉ đọc, không mở app) khi app có trên máy; app không có trên máy thì ghi theo hiểu biết chung và đánh dấu "suy luận".

## 3. Danh sách ứng dụng

"Máy này": tra ngày 30/10/2026 trong `/Applications`, `~/Applications`, `/System/Applications`, `/System/Library/CoreServices` và `mdfind kMDItemCFBundleIdentifier == '…'` (đã thử đối chứng: `mdfind` tìm ra Zalo và Edge). Phiên bản là `CFBundleShortVersionString` lúc tra. "web" = không có app, thử trong trình duyệt.

| Nhóm | Ứng dụng | Bundle ID | Máy này | Công nghệ giao diện | Rủi ro dự đoán (suy luận) |
|---|---|---|---|---|---|
| Hệ thống | TextEdit | `com.apple.TextEdit` | có (1.21) | AppKit (NSTextView) | thấp; có tự sửa chính tả của hệ thống |
| Trình duyệt | Safari | `com.apple.Safari` | có (27.2) | WebKit | thấp (M2 đúng ở mọi tốc độ) |
| Trình duyệt | Chrome | `com.google.Chrome` | có (156.0) | Chromium | bất đồng bộ (đã đo, mục 6.2) |
| Trình duyệt | Firefox | `org.mozilla.firefox` (Nightly: `org.mozilla.nightly`) | có (158.0.1; Nightly 160.0a1) | Gecko, không dùng Chromium | chưa biết; nhân xử lý nhập liệu riêng |
| Trình duyệt | Edge | `com.microsoft.edgemac` | có (155.0) | Chromium (`Microsoft Edge Framework`) | như Chrome |
| Trình duyệt | Arc | `company.thebrowser.Browser` | không | Chromium (suy luận) | như Chrome |
| Trình duyệt | Brave | `com.brave.Browser` | không | Chromium (suy luận) | như Chrome |
| Soạn mã | VS Code | `com.microsoft.VSCode` | có (1.144.0) | Electron | bất đồng bộ (đã đo, mục 6.2) |
| Soạn mã | Cursor | `com.todesktop.230313mzl4w4u92` | có (3.24.12) | Electron (bản dựng từ VS Code) | như VS Code |
| Soạn mã | Zed | `dev.zed.Zed` | có (1.23.2) | tự vẽ bằng Metal (GPUI, Rust), vỏ AppKit | chưa biết; tự cài đặt phía nhập liệu |
| Soạn mã | Sublime Text | `com.sublimetext.4` | có (Build 4215) | tự vẽ, vỏ Cocoa/AppKit | chưa biết (M2 chỉ có số đo gõ tay) |
| Soạn mã | JetBrains IDE | `com.jetbrains.WebStorm`; khác: `com.jetbrains.intellij`, `com.jetbrains.intellij.ce`, `com.jetbrains.pycharm`, `com.jetbrains.goland`, `com.google.android.studio` | WebStorm có (2026.2.3, `~/Applications`); các ID khác không | Java (JetBrains Runtime, có thư mục `jbr`) | chưa biết; nhập liệu qua lớp Java |
| Soạn mã | Xcode | `com.apple.dt.Xcode` | có (27.1) | AppKit, trình soạn mã riêng | chưa biết; có gợi ý hoàn thành mã |
| Terminal | Terminal | `com.apple.Terminal` | có (2.15) | AppKit, chờ shell in lại chữ | bất đồng bộ (đã đo, mục 6.2) |
| Terminal | iTerm2 | `com.googlecode.iterm2` | không | AppKit (suy luận) | như Terminal (suy luận) |
| Terminal | Warp | `dev.warp.Warp-Stable` | không | tự vẽ bằng Metal, Rust (suy luận) | chưa biết |
| Terminal | Ghostty | `com.mitchellh.ghostty` | có (1.4.0) | AppKit + SwiftUI, vẽ bằng Metal | như Terminal (suy luận) |
| Chat | Zalo | `com.vng.zalo` | có (26.10.10) | Electron | như VS Code (suy luận) |
| Chat | Messenger | web (`messenger.com`, `facebook.com`) | web | trình duyệt | theo trình duyệt. Meta đã ngừng app Messenger cho Mac từ 15/12/2025 và chuyển người dùng sang web ([TechCrunch](https://techcrunch.com/2025/10/16/meta-to-shut-down-messenger-desktop-apps-for-mac-and-windows/), [AppleInsider](https://appleinsider.com/articles/25/12/15/facebook-messenger-for-macos-departs-the-desktop)); ID cũ `com.facebook.archon` không có trên máy |
| Chat | Telegram | `ru.keepcoder.Telegram` | có (13.1.0) | AppKit, Swift (bản "Telegram for macOS") | thấp (M2 đúng ở 30 ms) |
| Chat | Telegram Desktop | `org.telegram.desktop` | không | Qt (suy luận) | chưa biết; đại diện nhóm Qt |
| Chat | Discord | `com.hnc.Discord` | có (0.0.415) | Electron | như VS Code (suy luận) |
| Chat | Slack | `com.tinyspeck.slackmacgap` | không | Electron (suy luận) | như VS Code (suy luận) |
| Chat | Microsoft Teams | `com.microsoft.teams2` (bản cũ `com.microsoft.teams`) | không | web view (suy luận, cần kiểm chứng) | chưa biết |
| Văn phòng | Word | `com.microsoft.Word` | không | vỏ AppKit, bộ soạn chữ riêng (suy luận) | chưa biết |
| Văn phòng | Excel | `com.microsoft.Excel` | không | như Word (suy luận) | chưa biết; ô bảng tính có chế độ sửa riêng |
| Văn phòng | PowerPoint | `com.microsoft.Powerpoint` | không | như Word (suy luận) | chưa biết |
| Văn phòng | Pages | `com.apple.Pages` (bản "Creator Studio" 15.4) và `com.apple.iWork.Pages` (14.5) | có, cả hai bản | AppKit, bộ soạn chữ riêng của iWork | chưa biết. Hai bản khác bundle ID: quy tắc phải ghi cả hai |
| Văn phòng | Numbers | `com.apple.Numbers` (Creator Studio 15.4); ID cũ `com.apple.iWork.Numbers` không có trên máy | có | như Pages | chưa biết; ô bảng tính |
| Văn phòng | Keynote | `com.apple.Keynote` (Creator Studio 15.4); ID cũ `com.apple.iWork.Keynote` không có trên máy | có | như Pages | chưa biết |
| Văn phòng | Google Docs | web | web | trình duyệt; Docs vẽ bằng canvas từ 2021 ([Google Workspace Updates](https://workspaceupdates.googleblog.com/2021/05/Google-Docs-Canvas-Based-Rendering-Update.html)), chữ nhập qua một ô ẩn (suy luận) | cao (suy luận); D20 trên web editor là câu hỏi mở trong `DECISIONS.md` |
| Văn phòng | Google Sheets | web | web | trình duyệt | chưa biết |
| Văn phòng | Notion | `notion.id` | có (7.41.1) | Electron | như VS Code (suy luận) |
| Văn phòng | Obsidian | `md.obsidian` | không | Electron (suy luận) | như VS Code (suy luận) |
| Apple | Ghi chú (Notes) | `com.apple.Notes` | có (4.13) | AppKit | thấp (suy luận); có tự sửa chính tả |
| Apple | Mail | `com.apple.mail` | có (16.0) | AppKit; khung soạn thư dùng WebKit (suy luận: file chạy có liên kết WebKit) | thấp (suy luận); có tự sửa chính tả |
| Apple | Tin nhắn (Messages) | `com.apple.MobileSMS` | có (26.0) | Mac Catalyst (UIKit qua `iOSSupport`) | chưa biết |
| Apple | Spotlight | `com.apple.Spotlight` | có | giao diện hệ thống | chưa biết; ô tìm có gợi ý tự hoàn thành |
| Apple | Finder (đổi tên tệp) | `com.apple.finder` | có (27.2) | AppKit | thấp (suy luận) |
| Khác | Figma | `com.figma.Desktop` | có (126.11.7) | Electron, nội dung vẽ bằng canvas | cao (suy luận) |
| Khác | Raycast | `com.raycast.macos` | không | AppKit (suy luận) | chưa biết; ô tìm có gợi ý |
| Khác | Alfred | `com.runningwithcrayons.Alfred` | không | AppKit (suy luận) | chưa biết; ô tìm có gợi ý |

Tổng (42 dòng): 26 có trên máy, 13 không có, 3 chỉ có bản web (Messenger, Google Docs, Google Sheets).

Ngoài danh sách chính, máy này còn các app Electron thử được nếu cần thêm mẫu: Claude (`com.anthropic.claudefordesktop`), GitHub Desktop (`com.github.GitHubClient`), Postman (`com.postmanlabs.mac`), Antigravity (`com.google.antigravity`), LM Studio (`ai.elementlabs.lmstudio`), Polypane (`com.firstversionist.polypane`); trình duyệt Blisk (`org.blisk.Blisk`); Zoom (`us.zoom.xos`).

Bundle ID mà bộ gõ thật sự nhận có thể khác cột trên (ví dụ tiến trình con của trình duyệt). Khi thử, lấy ID từ `scripts/perf-report.sh` (mục 4.4) và sửa cột nếu khác.

## 4. Cách thử một ứng dụng

### 4.1 Chuẩn bị

1. Làm theo `docs/M2-TESTING.md` mục 0: thoát bộ gõ tiếng Việt khác, `scripts/install-debug.sh`, bật và chọn "Dấu – Tiếng Việt". Nếu máy bật "Tự động chuyển sang nguồn đầu vào của tài liệu", chọn lại Dấu **sau khi** chuyển sang ứng dụng cần thử.
2. Ghi lại: ngày, commit của Dấu, phiên bản ứng dụng, phiên bản macOS, chế độ gạch chân của ứng dụng đó (Không / Có).
3. Chỉ gõ vào ô nháp: tài liệu mới không lưu, Saved Messages của Telegram, ô soạn tin không gửi. Không gửi tin nhắn, không lưu tệp nếu người dùng chưa cho phép (như M2).

### 4.2 Gõ câu mẫu

Câu mẫu (Telex), kết thúc bằng một dấu cách:

```
windows carr tooi yeeu tieengs Vieetj, Codefastlabs␣
```

Mong đợi: `windows car tôi yêu tiếng Việt, Codefastlabs␣` (D4, D26, D30). "carr" đứng trước câu tiếng Việt để tránh tự sửa chính tả của macOS (mục 6.1). Số đo ngày 29/10 dùng câu mẫu cũ `tooi yeeu tieengs Vieetj, windows Codefastlabs carr␣`.

- **Ứng dụng có trong script** (`textedit`, `safari`, `chrome`, `vscode`, `terminal`; từ T6 thêm `edge`, `firefox`, `notes`, `mail`): chạy lần lượt
  `scripts/selftest-typing/run.sh --delay 30 <app>` và `scripts/selftest-typing/run.sh --delay 0 <app>`.
  Script cần quyền Trợ năng cho tiến trình chạy nó (gửi phím qua System Events), tự mở cửa sổ trống, gõ, đọc lại, đóng không lưu, in PASS/FAIL và số đo. `--delay 0` gửi cả chuỗi trong một lệnh (khoảng 1–2 ms/phím): đây là bài thử phím dồn, nhanh hơn người gõ. Có thể thêm `--delay 5`, `--delay 10`, `--delay 20` để tìm ngưỡng.
- **Ứng dụng khác:** script chưa hỗ trợ. Gõ tay (tốc độ bình thường, rồi gõ nhanh hết sức), hoặc tự gõ qua System Events như cách đã làm với Telegram ngày 30/10. Ghi rõ cách thử vào cột "Cách thử".

### 4.3 Những gì cần kiểm tra

| Mã | Kiểm tra | Cách làm | Mong đợi |
|---|---|---|---|
| K1 | Chữ đúng | so từng ký tự với câu mong đợi | khớp hoàn toàn |
| K2 | Gạch chân | nhìn từ đang gõ | chế độ thường: không gạch chân. Chế độ gạch chân: từ đang gõ có gạch, hết gạch khi kết thúc từ hoặc reset |
| K3 | Nhảy chữ | nhìn trong lúc gõ | không lặp, mất, đảo chữ; con trỏ không nhảy; không thay sai chỗ |
| K4 | Backspace (D32) | gõ `hoaf` rồi ⌫ | "hoà" rồi "hò" |
| K5 | Click reset (D4, D11) | gõ `tooi`, click vào chỗ khác trong văn bản (sau dấu cách hoặc đầu dòng), gõ `s` | chỉ thêm "s" ở chỗ mới, "tôi" cũ không đổi. Click ngay sau một chữ thì D20 có thể đặt dấu vào chữ đó (D4 × D20) |
| K6 | Mũi tên reset (D4, D4 × D20) | gõ `tooi`, nhấn ←, nghỉ một nhịp, gõ `s` | D20 bật (mặc định): "tối". ← chỉ xoá bộ đệm, không chặn D20: phím dấu đặt dấu vào chữ ngay trước con trỏ ("tô" → "tố"), chữ "i" sau con trỏ giữ nguyên. D20 tắt: phím đi thẳng, thêm "s" tại con trỏ ("tôsi"). Ghi chú M2: lần ← đầu sau từ gõ dở có thể bị ứng dụng nuốt (TextEdit, cả với U.S.) |
| K7 | Thêm dấu cho từ đã gõ (D20) | gõ `hoc`, dấu cách, ⌫, nghỉ một nhịp (≥ 50 ms, gõ tay là đủ), rồi `j`. Tự gõ: `run.sh --delay 120 --keys "hoc ⌫j tooi ⌫s carr ⌫s hoc ⌫f viet ⌫j xin chao ⌫f " --expect "học tối cars hocf vietj xin chào "` | "học". Phím dồn dưới 50 ms thì D20 cố ý không chạy ("hocj"). App gạch chân (D13): không có D20, ra "hocj". Terminal: ⌫ không tới bộ gõ nên ra "hocj" (ARCHITECTURE.md) |
| K8 | Tự sửa chính tả (D4) | gõ `tooi yeeu tieengs Vieetj, Codefastlabs carr␣` | Dấu trả "car". Nếu sau dấu cách chữ thành "cả": gõ lại câu bằng U.S. (`… Codefastlabs car␣`). U.S. cũng bị sửa thì đó là macOS, ghi "có" ở cột Tự sửa; không tắt tự sửa hộ người dùng (N4) |

### 4.4 Số đo cần ghi

Ngay sau khi gõ xong:

```
scripts/perf-report.sh --last 5m --app <tên app hoặc một phần bundle ID>
```

`--app` không phân biệt hoa thường, không nhận PID; không ra số thì script in danh sách app có số đo. Ghi vào bảng mục 5:

- `selectedRange_us` p50 / p99 (chi phí cách A).
- `insertText_us`, `handle_replace_us` p50 / p99 (ghi ở cột Ghi chú nếu có).
- `count_mismatch` (vị trí con trỏ khác dự đoán), `count_unsupported` (ứng dụng trả `NSNotFound`, dấu hiệu cần gạch chân), `count_replace`, `count_pass`.
- `event_client-changed`, `event_client-not-text-input`: khác 0 thì báo lại ngay (xem `docs/M2-TESTING.md` mục 2).

Số đo lấy từ bản Debug, có thêm một lần hỏi chẩn đoán sau mỗi lần thay (`ReplaceDiag.swift`), nên không phải số của bản Release. Cần p99 đáng tin thì gõ thêm vài trăm phím có dấu trong cùng ứng dụng rồi chạy lại.

## 5. Kết quả

"30 ms", "0 ms": tự gõ bằng `scripts/selftest-typing/run.sh` hoặc System Events. Số µs là `selectedRange` ở 30 ms/phím, phím có thay chữ, trừ khi ghi khác. "—": chưa đo mục đó. Gạch chân ở 0 ms của Chrome, VS Code, Terminal, TextEdit, Safari: lượt T1 (30/10/2026, gạch chân ép bằng `DauDebugForceUnderline`, `docs/PROGRESS.md` nhật ký 30/10). K7 (D20): lượt T2 (30/10/2026, chuỗi K7 ở 120 ms, `docs/PROGRESS.md` "Số đo" 30/10) cho TextEdit, Safari, Chrome, VS Code, Terminal; lượt T6 cho Firefox, Edge, Notes. Phiên bản ứng dụng lúc đo M2 không được ghi lại.

| Ứng dụng | Ngày | Cách thử | 30 ms | 0 ms | Gõ tay | Gạch chân / nhảy chữ (K2, K3) | K4–K6 | K7 (D20) | Tự sửa (K8) | `selectedRange` p50 / p99 µs | mismatch / unsupported | Cần gạch chân? | Nguồn |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TextEdit | 29–30/10/2026 | script + gõ tay | đúng | đúng; gạch chân 0 và 30 ms: đúng (T1) | đúng | không / không | ĐẠT (K6 theo mong đợi cũ, xem dưới bảng) | ĐẠT (T2, 120 ms) | chưa ghi riêng | 327 / 606 | 0 / — | chưa thấy lỗi | PROGRESS "Số đo" 29/10; M2-TESTING mục 2, 4; PROGRESS nhật ký 30/10 (script PASS sau đổi bundle ID; T1, T2) |
| Safari | 29/10/2026; K4 30/10/2026 | script + gõ tay | đúng | đúng; gạch chân 0 và 30 ms: đúng (T1) | đúng | không / không | K4 ĐẠT ("hò", 30 ms) | ĐẠT (T2, 120 ms) | — | 622 / 1.057 | 0 / — | chưa thấy lỗi | PROGRESS "Số đo" 29/10, 30/10; M2-TESTING mục 2 |
| Chrome | 29/10/2026; K4, T1, T2 30/10/2026 | script + gõ tay | đúng | **sai** (mismatch 3–4, thay nhầm vùng ở lần thay đầu của từ); 5 và 10 ms đúng; 0 ms gạch chân: **đúng** (T1) | đúng | không / không ở 30 ms | K4 **SAI** ở 0ac50c3 ("h", 120 ms); đã sửa: ĐẠT ("hò" ở 120 ms và chạy lại ở 30 ms, mục 6.4) | ĐẠT (T2, 120 ms) | — | 415 / 694 | 0 / — (ở 30 ms) | có, đề xuất (D13: sai ở 0 ms, gạch chân sửa được) | PROGRESS "Số đo" 29/10, 30/10; PROGRESS nhật ký 30/10 (T1); M2-TESTING mục 2 |
| Firefox | 30/10/2026 | script (158.0.1, trang thử cục bộ, `spellcheck=false`) | đúng | **sai**, chữ nhảy chỗ ("ar ấki tj, Hangs Vieu tiei yeoindows ca", mismatch 4); 5 ms sai (mismatch 1); 10 ms đúng; 0 ms gạch chân: **đúng** (mark 38) | — | — / **có nhảy chữ ở 0 ms** | K4 ĐẠT ("hò"); K5, K6 chưa thử | ĐẠT ("học", 120 ms) | không (trang thử tắt kiểm tra chính tả) | 265 / 1.174 | 0 / 0 (30 ms) | có, đề xuất (sai ở 0–5 ms, gạch chân sửa được; vào danh sách ở 94ada11) | T6 30/10/2026 (mục 5.1). `insertText` 752 / 3.365 µs; `handle` phím có thay 1.171 / 4.113 µs; replace 12, pass 33 |
| Edge | 30/10/2026 | script (155.0, trang thử cục bộ, `spellcheck=false`) | đúng | **sai** ("ưấrndows ca toi yeu tiengs Vietj, Haki", mismatch 4); 5 ms sai (mismatch 1); 10 ms đúng; 0 ms gạch chân: **đúng** | — | không / không ở 30 ms | K4 **SAI** ở 0ac50c3 ("h": mất 2 chữ) ở 30 và 120 ms; đã sửa: ĐẠT ("hò", 120 ms, mục 6.4); gạch chân: ĐẠT. K5, K6 chưa thử | ĐẠT ("học", 120 ms) | không (trang thử tắt kiểm tra chính tả) | 369 / 6.828 | 0 / 0 (30 ms) | có (đã trong danh sách; nay có số đo) | T6 30/10/2026 (mục 5.1). `insertText` 1.184 / 8.661 µs; `handle` phím có thay 1.527 / 15.851 µs (n=12, p99 là một lần chậm); replace 12, pass 33 |
| Arc | chưa thử | | | | | | | | | | | | |
| Brave | chưa thử | | | | | | | | | | | | |
| VS Code | 29/10/2026; K4, T1, T2 30/10/2026 | script | đúng | **sai**; 5 ms sai. 10 ms: M2 (29/10/2026) sai ("ôoi"), lượt T1 sau đó (30/10/2026, câu mẫu đã đổi) đúng; từ 20 ms đúng. Gạch chân 0 và 5 ms: **đúng** (T1) | — | không / không ở 30 ms | K4 **SAI** ở 0ac50c3 ("h", 30 ms); đã sửa: ĐẠT ("hò" ở 120 ms và chạy lại ở 30 ms, mục 6.4) | ĐẠT (T2, 120 ms) | — | 230 / 885 | 0 / — (ở 30 ms) | có, đề xuất (D13: sai ở 0 và 5 ms, gạch chân sửa được) | PROGRESS "Số đo" 29/10, 30/10, nhật ký chẩn đoán 29/10 và nhật ký 30/10 (T1) |
| Cursor | chưa thử | | | | | | | | | | | | |
| Zed | chưa thử | | | | | | | | | | | | |
| Sublime Text | 29/10/2026 | gõ tay | — | — | có số đo; kết quả chữ không được ghi | — | — | — | — | 334 / 3.718 (gõ tay, n=35, sơ bộ) | — | chưa đủ dữ liệu | PROGRESS "Số đo" 29/10; DECISIONS câu hỏi A/B (selectedRange 17% thời gian phím) |
| JetBrains IDE | chưa thử | | | | | | | | | | | | |
| Xcode | chưa thử | | | | | | | | | | | | |
| Terminal | 29/10/2026; T1, T2 30/10/2026 | script | đúng | **sai**; 5 và 10 ms đúng. Gạch chân 0 ms: **vẫn sai** (chữ chốt đúng nhưng Terminal còn vẽ marked text cũ tới phím sau); gạch chân 5–30 ms đúng (T1) | — | không / không ở 30 ms | — | ra "hocj…" (T2: ⌫ không tới bộ gõ, mục 6.5) | — | 408 / 637 | 0 / — (ở 30 ms) | không đề xuất (D13: gạch chân không sửa được ở 0 ms) | PROGRESS "Số đo" 29/10, 30/10; PROGRESS nhật ký 30/10 (T1, T2) |
| iTerm2 | chưa thử | | | | | | | | | | | | |
| Warp | chưa thử | | | | | | | | | | | | |
| Ghostty | chưa thử | | | | | | | | | | | | |
| Zalo | chưa thử | | | | | | | | | | | | |
| Messenger (web) | chưa thử | | | | | | | | | | | | |
| Telegram | 30/10/2026 | System Events, 30 ms, Saved Messages, không gửi | đúng (câu mẫu cũ) | — | — | không / không | — | — | — | 240 / 1.670 | 0 / 0 | chưa thấy lỗi | PROGRESS "Số đo" 30/10; M2-TESTING mục 2. `insertText` p50 1.830 / p99 3.491 µs; cả phím có thay p50 2.171 / p99 5.313 µs; replace 12, pass 34. M2-TESTING mục 4 dòng 3 (Return ngay sau từ) bỏ qua vì không gửi tin |
| Telegram Desktop | chưa thử | | | | | | | | | | | | |
| Discord | chưa thử | | | | | | | | | | | | |
| Slack | chưa thử | | | | | | | | | | | | |
| Microsoft Teams | chưa thử | | | | | | | | | | | | |
| Word | chưa thử | | | | | | | | | | | | |
| Excel | chưa thử | | | | | | | | | | | | |
| PowerPoint | chưa thử | | | | | | | | | | | | |
| Pages | chưa thử | | | | | | | | | | | | |
| Numbers | chưa thử | | | | | | | | | | | | |
| Keynote | chưa thử | | | | | | | | | | | | |
| Google Docs | chưa thử | | | | | | | | | | | | |
| Google Sheets | chưa thử | | | | | | | | | | | | |
| Notion | chưa thử | | | | | | | | | | | | |
| Obsidian | chưa thử | | | | | | | | | | | | |
| Ghi chú (Notes) | 30/10/2026 | script (4.13, ghi chú mới trong iCloud, xoá trắng sau khi đọc) | đúng | đúng (mismatch 0) | — | — / không | K4 ĐẠT ("hò"); K5, K6 chưa thử | ĐẠT ("Học": Notes tự viết hoa chữ đầu) | không: "…Codefastlabs carr␣" giữ "car" (chữ đầu "Tôi" do Notes viết hoa) | 330 / 1.135 | 0 / 0 | chưa thấy lỗi | T6 30/10/2026 (mục 5.1). `insertText` 3.799 / 10.207 µs; `handle` phím có thay 4.274 / 8.003 µs (cao nhất trong các app đã đo, vẫn đúng ở 0 ms) |
| Mail | 30/10/2026 | script (16.0, thư mới, gõ vào thân thư, ô Đến để trống, không gửi; đóng "Don’t Save") | đúng ("Windows…": Mail tự viết hoa chữ đầu) | — | — | — / — | chưa thử | chưa thử | chưa thử | 375 / 1.245 | 0 / 0 | chưa đủ dữ liệu (chỉ 30 ms) | T6 30/10/2026 (mục 5.1), dừng theo yêu cầu người dùng sau K1 30 ms. `insertText` 471 / 2.536 µs; `handle` phím có thay 926 / 2.979 µs |
| Tin nhắn (Messages) | chưa thử | | | | | | | | | | | | |
| Spotlight | chưa thử | | | | | | | | | | | | |
| Finder (đổi tên tệp) | chưa thử | | | | | | | | | | | | |
| Figma | chưa thử | | | | | | | | | | | | |
| Raycast | chưa thử | | | | | | | | | | | | |
| Alfred | chưa thử | | | | | | | | | | | | |

K4–K6 của TextEdit: M2-TESTING mục 4 dòng 1, 4, 5, 6 (30/10/2026, agent tự gõ qua System Events); K4 chạy lại bằng script ngày 30/10/2026 (T6, 120 ms): ĐẠT. K6 ĐẠT theo mong đợi cũ (thêm "s", không bỏ dấu), trước khi có D20; mong đợi mới theo D4 × D20 ("tối" khi D20 bật) chưa chạy lại. Các app khác chưa chạy K5, K6: làm tiếp ở M6 (mục 7).

### 5.1 Lượt T6 ngày 30/10/2026

- Máy: macOS 27.2, Apple M1 Pro; bộ gõ Debug đã cài ở HEAD 60dac6f. Tự gõ bằng `scripts/selftest-typing/run.sh` (thêm `edge`, `firefox`, `notes`, `mail` trong lượt này). Phím chỉ gửi khi app thử đứng trước; không nhấn Return ở đâu; không gửi thư hay tin nhắn.
- Mỗi app: K1 câu mẫu ở 30 ms và 0 ms; app sai ở 0 ms (hoặc trong danh sách đề xuất) thử thêm 0 ms với `--underline`, 5 và 10 ms. K4: `--keys "hoaf⌫ " --expect "hò "` (30 ms). K7: `--delay 120 --keys "hoc ⌫j " --expect "học "`. K8: `--keys "tooi yeeu tieengs Vieetj, Codefastlabs carr " --expect "tôi yêu tiếng Việt, Codefastlabs car "` (30 ms). Số µs lấy từ báo cáo `perf-report.sh` mà script in cho lượt 30 ms (p50 / p99).
- Trình duyệt thử trên trang cục bộ có `spellcheck="false"`, nên K8 ở đây không nói gì về tự sửa của trình duyệt khi gõ trên web thật.
- Người dùng dừng lượt thử sau Mail (K1 30 ms). Chưa thử trong lượt này: Mail (phần còn lại), Messages, Pages, Numbers, Zalo, Discord, Ghostty, Zed, Xcode, WebStorm; kiểm chứng lại Terminal không gửi ⌫ cho bộ gõ (mục 6.5) cũng chưa chạy. Các việc này làm tiếp ở M6 (người dùng chốt 30/10/2026, mục 7).
- Dọn dẹp: tab thử đã đóng; ghi chú thử trong Notes đã xoá trắng và Notes bỏ ghi chú trống (đếm 53 ghi chú trước và sau); thư nháp đóng bằng "Don’t Save"; Notes, Mail, Firefox đã thoát; Edge (do lượt thử mở) còn chạy, không cửa sổ. Nguồn nhập liệu và clipboard được script khôi phục; khoá `DauDebugForceUnderline` đã xoá.

## 6. Giới hạn đã biết

### 6.1 Tự sửa chính tả của macOS đè lên chữ đã giữ (D4) — ghi ngày 30/10/2026

- Hiện tượng: từ macOS 27.2, ở ứng dụng bật tự sửa chính tả, khi phía trước là câu tiếng Việt, hệ thống có thể sửa chữ tiếng Anh vừa gõ thành chữ tiếng Việt ("…Codefastlabs car␣" → "cả"), **kể cả khi gõ bằng bàn phím U.S.**. Việc này xảy ra sau khi Dấu đã trả đúng "car", nên đè lên kết quả gõ đúp ("carr" → "car").
- Bằng chứng: `docs/DECISIONS.md` D4 (đoạn "Giới hạn đã biết"); `docs/PROGRESS.md` nhật ký 30/10/2026 (câu mẫu `selftest-typing` đổi thành "windows carr tooi yeeu tieengs Vieetj, Codefastlabs " để né, 3/3 ĐẠT); chú thích đầu `scripts/selftest-typing/run.sh`. Nguồn không ghi ứng dụng cụ thể đã quan sát; T6 điền cột "Tự sửa" cho từng app bằng K8.
- Dấu không tắt tự sửa của hệ thống (N4). Người dùng hoàn tác bằng ⌘Z hoặc bấm vào chữ bị sửa. Tự sửa là thuộc tính của từng ô soạn thảo do ứng dụng quyết định (ví dụ `NSTextView.isAutomaticSpellingCorrectionEnabled`, https://developer.apple.com/documentation/appkit/nstextview/isautomaticspellingcorrectionenabled), nên ứng dụng không dùng hệ thống văn bản của Apple có thể không bị (suy luận, cần kiểm chứng bằng K8).

### 6.2 Ứng dụng áp phím bất đồng bộ (câu hỏi A/B) — ghi ngày 29/10/2026

- Hiện tượng: Chrome, VS Code, Terminal đúng khi phím cách nhau từ 20 ms, nhưng sai khi phím đến dồn: dưới khoảng 10 ms ở Chrome, Terminal; dưới khoảng 20 ms ở VS Code. Các app này áp phím bất đồng bộ (Chromium/Electron; Terminal chờ shell in lại chữ), nên `selectedRange` trả ảnh chụp cũ; bộ gõ thấy lệch (`mismatch`), reset từ đang gõ, chữ ra thiếu dấu hoặc thay nhầm vùng. Ảnh chụp không cập nhật trong lúc `handle` đang chạy (hỏi lại 10 lần, cách 2 ms, vẫn y nguyên).
- Ví dụ lượt tự gõ đầu tiên ngày 29/10: VS Code ra "arroi yeu tiengs Vietj, ?indows Haki c", Terminal ra "tôi yêu tiêngs Viêtj, windows Hấki car".
- Không phải do thiếu quyền Trợ năng (bộ gõ không có quyền đó mà vẫn đúng ở 20 ms trở lên). Cách B (tự cộng dồn vị trí) cũng không cứu được, vì vị trí gốc cũng là ảnh chụp cũ và VS Code đổi gốc toạ độ. Đã thử và bỏ: chờ ứng dụng rồi hỏi lại; so chữ trước con trỏ bằng `attributedSubstring` (Safari trả chữ cũ nên hỏng cả Safari).
- Bằng chứng: `docs/DECISIONS.md` câu hỏi A/B (đã chốt cách A) và câu hỏi Chrome/Terminal; `docs/PROGRESS.md` mục "Số đo" (dòng "Cách A theo tốc độ gõ") và nhật ký 29/10 (chẩn đoán VS Code/Terminal).
- Hướng xử lý: M3 việc T1 thử gạch chân (D13) theo bundle ID, đo ở 0, 5, 10 ms rồi chốt. Đã làm (30/10/2026): kết quả ở D13 và mục 5; lượt T1 với câu mẫu mới, VS Code đúng từ 10 ms. Người gõ tay hiếm khi có hai phím cách nhau dưới 10 ms, nhưng phím lặp khi giữ phím, máy đang tải nặng hay ứng dụng tạm đứng có thể làm phím đến dồn (suy luận; M6 đo dưới tải).

### 6.3 Ô mật khẩu — ghi ngày 30/10/2026

Ở ô nhập bảo mật (ví dụ ô mật khẩu trong Safari), macOS giữ bàn phím `com.apple.keylayout.US` và Dấu không nhận phím nào. Đây là hành vi của hệ thống, không phải lỗi. Nguồn: `docs/M2-TESTING.md` mục 4 dòng 17.

### 6.4 Backspace thay chữ tại chỗ bị xoá hai lần trong Chromium/Electron (D32) — ghi ngày 30/10/2026, đã sửa cùng ngày

- Hiện tượng (bản 0ac50c3): ở Chrome, Edge, VS Code, gõ `hoaf` ("hoà") rồi ⌫ ra "h" thay vì "hò", ở cả 30 và 120 ms/phím. Không gặp ở TextEdit, Safari, Firefox, Notes; chế độ gạch chân (D13) ở Edge đúng.
- **Nguyên nhân (đã kiểm chứng):** ứng dụng Chromium tự chạy lệnh xoá của mình cho phím ⌫ dù bộ gõ đã nuốt phím. Không phải `selectedRange` cũ, không phải đường đọc D20:
  - Log `diag`/`perf` của lượt T6 (Debug, 120 ms/phím, chỉ số): phím ⌫ ở Chrome là `key kind=replace … read_ns=-1` và `replace kind=replace del=2 sel=3,0 expected=3 rep=1,2 ins_len=1 after=3,0 after_expected=2`; VS Code (30 ms) và Edge giống hệt. Vị trí hỏi được đúng bằng dự đoán (`sel=3` = `expected=3`), vùng thay đúng (`rep=1,2` = "oà" → "ò"), không có lần đọc D20 (`read_ns=-1`, không có kind `seed*`). TextEdit, Safari, Notes cùng dòng đó trừ `after=2,0` (ứng dụng áp ngay); Firefox `after=3,0` (bất đồng bộ) mà vẫn ra "hò", nên bất đồng bộ không phải nguyên nhân. Kết quả "h" = "hò" mất thêm đúng một chữ.
  - Mã Chromium (`content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm`, `keyEvent:`, nhánh chính hiện tại): sau `interpretKeyEvents:`, nếu không có marked text và chữ chờ chèn không quá 1 ký tự, Chromium **luôn** gửi phím gốc (RawKeyDown) cho trang bằng `ForwardKeyboardEventWithCommands`, không xét bộ gõ có nuốt phím hay không; `insertText` có `replacementRange` thì được gửi ngay (`ImeCommitText`), tức là trước phím gốc. Với chữ cái, RawKeyDown không làm gì; với ⌫, trang xoá một chữ. Khi có marked text, Chromium gửi phím giả VKEY_PROCESSKEY thay cho phím gốc, nên gạch chân không bị.
- **Cách sửa (M3, `InPlaceComposer`):** ⌫ cần đặt lại dấu thì **không nuốt phím ở mọi ứng dụng**: lệnh xoá của chính ứng dụng bỏ chữ cuối, còn bộ gõ thay phần còn lại và trả chữ cuối về đúng chỗ để lệnh xoá đó lấy đi ("hoà": thay "oà" bằng "òà" → ứng dụng xoá "à" → "hò"). Vẫn một `selectedRange` và một `insertText` như trước (N3); D32 giữ nguyên. Cần thứ tự: chữ của bộ gõ được áp trước lệnh xoá. Ứng dụng AppKit áp `insertText` trước khi `handle` trả về; Chromium gửi `ImeCommitText` trước phím gốc (mã trên); Safari, Firefox: đo trên máy (bảng dưới). Nếu thứ tự ngược ở một ứng dụng nào đó, phím có thay chữ kế tiếp thấy lệch (D11) và reset.
- Kết quả sau khi sửa (Debug, 30/10/2026, 08f3281): `hoaf⌫ ` → "hò" ở 120 ms: TextEdit, Safari, Chrome, VS Code, Edge **PASS** (replace 2, mismatch 0). Chạy lại khi máy rảnh (phiên chính): ở 30 ms `hoaf⌫ ` → "hò", `vieetj⌫⌫ ` → "vị", `tieengs⌫⌫ ` → "tiế" **PASS** ở cả 6 app (TextEdit, Safari, Chrome, VS Code, Edge, Firefox); câu mẫu ở 30 ms **PASS** ở cả 6 app; `vieetj⌫s ` → "việs" ở 120 ms **PASS** (TextEdit, Chrome, Firefox). ⌫ không còn là lý do đề xuất gạch chân; lý do còn lại là gõ dồn dưới 10 ms (mục 5).
- Test: `InPlaceComposerTests` có client giả kiểu Chromium (`deletesConsumedBackspace`: luôn xoá sau `insertText`) và kiểu AppKit, chạy cùng các chuỗi ⌫; thêm ca ảnh chụp cũ (phím cách 10 ms, ứng dụng trễ 50 ms): D11 bắt lệch, chỉ mất dấu, không mất chữ.

### 6.5 Terminal không gửi ⌫ cho bộ gõ (D32) — ghi ngày 30/10/2026

Phát hiện ở M3 T2 (`docs/PROGRESS.md` nhật ký 30/10/2026): Terminal xử lý ⌫ mà không đưa phím cho bộ gõ, nên D32 không giữ được ở đó (K7 ra "hocj", ARCHITECTURE.md). T6 chưa kiểm chứng lại bằng `hoaf⌫␣` vì lượt thử dừng sớm; làm ở M6 (mục 7).

### 6.6 Biểu tượng nguồn nhập liệu trên máy nhiều màn hình — ghi ngày 30/10/2026, đã sửa cùng ngày

Triệu chứng: trên máy hai màn hình, thanh menu tối ở màn hình phụ (biểu tượng hệ thống màu trắng) vẫn hiện ô V của Dấu màu đen. Lúc đầu tưởng là giới hạn của macOS với ảnh template của bộ gõ bên ngoài; thực ra cùng nguyên nhân với 6.7: `TISIconIsTemplate` chỉ khai ở cấp bundle, cờ của input mode là false. Sau bcb1227 (cờ ở cấp mode), chụp cả hai màn hình: ô V xám trên thanh menu sáng, trắng trên thanh menu tối, giống các biểu tượng hệ thống bên cạnh.

### 6.7 Chỉ báo ⌃Space dưới con trỏ trống — ghi ngày 30/10/2026, đã sửa cùng ngày

- Hiện tượng (đến 55c00bb): chuyển nguồn bằng ⌃Space, bong bóng xanh dưới con trỏ hiện "A" cho U.S. nhưng **trống** cho Dấu.
- Nguyên nhân (đọc bằng lldb và gọi thử lớp riêng `KLInputSourceIconManager` của `KeyboardLayouts.framework`, macOS 27.2): bong bóng do `CursorUIViewService` (TextInputUIMacHelper) vẽ, lấy ảnh từ `indicatorImageForInputSource:`. Nhãn chữ ("A", "VI", "VI TX") lấy từ bảng `KLDynamicInputSourceIconTable` dựng sẵn trong framework, khoá theo ID nguồn của Apple (291 mục); `TISIconLabels` trong Info.plist không được đọc cho bộ gõ bên ngoài. Nguồn không có trong bảng thì dùng ảnh TIS `TSMInputSourcePropertyIconImage` và cờ `TSMInputSourcePropertyIconShouldBeTemplate`. Cờ này của input mode `….Dau.vi` là `false` dù `TISIconIsTemplate` đặt ở cấp bundle (nguồn cấp bundle thì `true`); với ảnh không phải template, bong bóng trống.
- Cách sửa: thêm `TISIconIsTemplate = true` vào từ điển của input mode. Cờ TIS đổi ngay khi cài lại, không cần đăng xuất. Bong bóng hiện ô V trắng khoét chữ (cùng ảnh thanh menu), không phải chữ trần như "A": hệ thống không cho bộ gõ bên ngoài nhãn chữ.
- Kiểm chứng (TextEdit, ⌃Space Dấu → U.S. → Dấu, chụp 0,25 s sau phím): có khoá ở mode: hiện V; bỏ khoá (đối chứng, cùng cách khởi động lại dịch vụ): trống. Thanh menu hai màn hình vẫn đúng. `CursorUIViewService` giữ ảnh cũ trong bộ nhớ đệm và bỏ qua SIGTERM: máy đã cài bản cũ thấy V sau khi đăng xuất, hoặc `killall -9 CursorUIViewService` (dịch vụ tự chạy lại).
- Không thử (không cần sau khi tìm ra nguyên nhân): ảnh PDF, `TISIconLabels` cấp bundle, nhãn bản địa hoá. Chuyển sang IMK extension (`.appex`) có lẽ cũng không cho nhãn chữ, vì bảng nhãn khoá theo ID của Apple (suy luận, chưa thử).

## 7. Còn mở

- Phần còn lại của ma trận làm tiếp ở M6 (người dùng chốt 30/10/2026): Zalo, Discord, Messages, Pages, Numbers, Ghostty, Zed, Xcode, WebStorm (và phần còn lại của Mail); kiểm chứng lại Terminal không gửi ⌫ cho bộ gõ (mục 6.5); K5, K6 cho phần lớn app (K6 theo mong đợi mới D4 × D20).
- Đã xong: danh sách đề xuất theo số đo T6 — **thêm Firefox** (`org.mozilla.firefox`; sai ở 0 và 5 ms, chữ nhảy chỗ, gạch chân sửa được) vào `CompatibilityList.json` ở 94ada11; Edge giữ, nay có số đo (sai ở 0 và 5 ms, ⌫ xoá hai lần — nay đã sửa ở thay tại chỗ, mục 6.4 — gạch chân sửa cả hai); Notes không đề xuất (đúng ở 0 ms).
- Đã xong: tiêu chí đưa một ứng dụng vào danh sách gạch chân đã chốt ở D13 (mục 1): chỉ đề xuất; thay tại chỗ chỉ sai dưới 10 ms.
- `scripts/selftest-typing/run.sh` biết 9 ứng dụng (thêm Edge, Firefox, Notes, Mail ở T6). Thử nhiều ứng dụng ở 0 ms cần thêm ứng dụng vào script (mở ô trống, đọc lại chữ) hoặc chấp nhận gõ tay.
- Pages có hai bundle ID trên cùng máy (`com.apple.Pages` và `com.apple.iWork.Pages`); Numbers, Keynote bản mới đổi ID (`com.apple.Numbers`, `com.apple.Keynote`). Nếu các app này cần quy tắc, danh sách tương thích phải ghi đủ các ID.
