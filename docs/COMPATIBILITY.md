# Ma trận tương thích

Bảng ghi kết quả thử Dấu trong từng ứng dụng (M3, việc T5 lập khung; T6 chạy và điền). Khung lập ngày 30/10/2026 trên máy phát triển: macOS 27.2 (26B123), Apple M1 Pro. Dòng nào chưa thử ghi "chưa thử"; không điền ô nào bằng phỏng đoán.

## 1. Mục đích

- Biết Dấu gõ đúng hay sai trong từng ứng dụng, ở tốc độ nào, và vì sao.
- Là nguồn duy nhất cho **danh sách tương thích**: ứng dụng nào cần gạch chân (marked text, D13) thì vào danh sách theo bundle ID. Danh sách có sẵn trong bản build (M3, việc T3) và về sau được cập nhật riêng bằng file JSON có chữ ký do app chủ tải (D7); tiến trình bộ gõ không tải gì (N2). Trong trang Ứng dụng, các quy tắc đến từ danh sách hiện nhãn "Đề xuất" (D5, `AppRule` nguồn `suggested`).
- Đề xuất (chưa ghi vào `DECISIONS.md`): một ứng dụng chỉ vào danh sách khi bảng ở mục 5 có kết quả đo của nó (ngày, cách thử, kết quả với và không gạch chân). Không đo thì không vào.
- Bảng này không phải lời hứa (N5). Không chép kết quả lên giao diện hay website ("chạy tốt trong mọi app", danh sách logo ứng dụng…) trước khi phiên chính tổng hợp; website giữ ô trống như `[Kết quả bài test tải nặng]`.

Tiêu chí "cần gạch chân" **chưa chốt** (xem mục 7). Đề xuất để phiên chính và người dùng quyết định sau T1: sai khi thay chữ tại chỗ ở một tốc độ người thật có thể gặp, và đúng khi bật gạch chân ở cùng tốc độ đó.

## 2. Vì sao ghi công nghệ giao diện

Dấu thay chữ tại chỗ: ở phím có thay chữ, hỏi `selectedRange` một lần rồi gọi `insertText(_:replacementRange:)` (cách A, D11, N3). Cách này cần ứng dụng trả vị trí con trỏ đúng **ngay lúc hỏi**.

- Header `IMKInputSession.h` (HIToolbox, SDK macOS 27.0) ghi: nếu client không hỗ trợ TSMDocumentAccess thì `selectedRange` trả `NSNotFound` và `replacementRange` bị bỏ qua; header cũng ghi client như vậy "cực kỳ hiếm" và hệ thống văn bản Cocoa có hỗ trợ. Bộ gõ đếm trường hợp này là `unsupported`. Trang tài liệu web của `IMKTextInput` trả 404 (đã ghi ở `docs/OPENKEY-NOTES.md` mục 5); phía ứng dụng: https://developer.apple.com/documentation/appkit/nstextinputclient/selectedrange() và https://developer.apple.com/documentation/appkit/nstextinputclient/inserttext(_:replacementrange:)
- Lỗi đã đo được ở M2 không phải `unsupported` mà là **ứng dụng áp phím bất đồng bộ**: Chrome, VS Code, Terminal trả một vị trí cũ khi phím đến dồn (mục 6.2). Vì vậy công nghệ giao diện là dấu hiệu dự đoán tốt nhất trước khi thử: Chromium/Electron và terminal dễ gặp lỗi này; AppKit/WebKit (TextEdit, Safari) thì chưa thấy. Đây là suy luận từ 5 ứng dụng, cần kiểm chứng trên từng ứng dụng.
- Gạch chân dùng `setMarkedText(_:selectionRange:replacementRange:)`; theo cùng header, chuỗi thường sẽ được gạch chân mặc định. Gạch chân có giải được lỗi bất đồng bộ không: chưa kiểm chứng (T1 đo).

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
2. Ghi lại: ngày, commit của Dấu, phiên bản ứng dụng, phiên bản macOS, chế độ gạch chân của ứng dụng đó (Không / Có, sau T1).
3. Chỉ gõ vào ô nháp: tài liệu mới không lưu, Saved Messages của Telegram, ô soạn tin không gửi. Không gửi tin nhắn, không lưu tệp nếu người dùng chưa cho phép (như M2).

### 4.2 Gõ câu mẫu

Câu mẫu (Telex), kết thúc bằng một dấu cách:

```
windows carr tooi yeeu tieengs Vieetj, Hasaki␣
```

Mong đợi: `windows car tôi yêu tiếng Việt, Hasaki␣` (D4, D26, D30). "carr" đứng trước câu tiếng Việt để tránh tự sửa chính tả của macOS (mục 6.1). Số đo ngày 29/10 dùng câu mẫu cũ `tooi yeeu tieengs Vieetj, windows Hasaki carr␣`.

- **Ứng dụng có trong script** (`textedit`, `safari`, `chrome`, `vscode`, `terminal`): chạy lần lượt
  `scripts/selftest-typing/run.sh --delay 30 <app>` và `scripts/selftest-typing/run.sh --delay 0 <app>`.
  Script cần quyền Trợ năng cho tiến trình chạy nó (gửi phím qua System Events), tự mở cửa sổ trống, gõ, đọc lại, đóng không lưu, in PASS/FAIL và số đo. `--delay 0` gửi cả chuỗi trong một lệnh (khoảng 1–2 ms/phím): đây là bài thử phím dồn, nhanh hơn người gõ. Có thể thêm `--delay 5`, `--delay 10`, `--delay 20` để tìm ngưỡng.
- **Ứng dụng khác:** script chưa hỗ trợ. Gõ tay (tốc độ bình thường, rồi gõ nhanh hết sức), hoặc tự gõ qua System Events như cách đã làm với Telegram ngày 30/10. Ghi rõ cách thử vào cột "Cách thử".

### 4.3 Những gì cần kiểm tra

| Mã | Kiểm tra | Cách làm | Mong đợi |
|---|---|---|---|
| K1 | Chữ đúng | so từng ký tự với câu mong đợi | khớp hoàn toàn |
| K2 | Gạch chân | nhìn từ đang gõ | chế độ thường: không gạch chân. Chế độ gạch chân (sau T1): từ đang gõ có gạch, hết gạch khi kết thúc từ hoặc reset |
| K3 | Nhảy chữ | nhìn trong lúc gõ | không lặp, mất, đảo chữ; con trỏ không nhảy; không thay sai chỗ |
| K4 | Backspace (D32) | gõ `hoaf` rồi ⌫ | "hoà" rồi "hò" |
| K5 | Click reset (D4, D11) | gõ `tooi`, click vào chỗ khác trong văn bản, gõ `s` | chỉ thêm "s" ở chỗ mới, "tôi" cũ không đổi |
| K6 | Mũi tên reset (D4) | gõ `tooi`, nhấn ←, gõ `s` | thêm "s" tại con trỏ, không bỏ dấu vào "tôi". Ghi chú M2: lần ← đầu sau từ gõ dở có thể bị ứng dụng nuốt (TextEdit, cả với U.S.) |
| K7 | Thêm dấu cho từ đã gõ (D20) | chờ T2. Dự kiến: gõ `hoc`, dấu cách, ⌫, rồi `j` | "học". Cách thử chốt lại theo cách T2 làm |
| K8 | Tự sửa chính tả (D4) | gõ `tooi yeeu tieengs Vieetj, Hasaki carr␣` | Dấu trả "car". Nếu sau dấu cách chữ thành "cả": gõ lại câu bằng U.S. (`… Hasaki car␣`). U.S. cũng bị sửa thì đó là macOS, ghi "có" ở cột Tự sửa; không tắt tự sửa hộ người dùng (N4) |

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

"30 ms", "0 ms": tự gõ bằng `scripts/selftest-typing/run.sh` hoặc System Events. Số µs là `selectedRange` ở 30 ms/phím, phím có thay chữ, trừ khi ghi khác. "—": chưa đo mục đó. D20: chờ T2 cho mọi dòng. Phiên bản ứng dụng lúc đo M2 không được ghi lại.

| Ứng dụng | Ngày | Cách thử | 30 ms | 0 ms | Gõ tay | Gạch chân / nhảy chữ (K2, K3) | K4–K6 | K7 (D20) | Tự sửa (K8) | `selectedRange` p50 / p99 µs | mismatch / unsupported | Cần gạch chân? | Nguồn |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TextEdit | 29–30/10/2026 | script + gõ tay | đúng | đúng | đúng | không / không | ĐẠT | chờ T2 | chưa ghi riêng | 327 / 606 | 0 / — | chưa thấy lỗi | PROGRESS "Số đo" 29/10; M2-TESTING mục 2, 4; PROGRESS nhật ký 30/10 (script PASS sau đổi bundle ID) |
| Safari | 29/10/2026 | script + gõ tay | đúng | đúng | đúng | không / không | — | chờ T2 | — | 622 / 1.057 | 0 / — | chưa thấy lỗi | PROGRESS "Số đo" 29/10; M2-TESTING mục 2 |
| Chrome | 29/10/2026 | script + gõ tay | đúng | **sai** (mismatch 3–4, thay nhầm vùng ở lần thay đầu của từ); 5 và 10 ms đúng | đúng | không / không ở 30 ms | — | chờ T2 | — | 415 / 694 | 0 / — (ở 30 ms) | chờ T1 | PROGRESS "Số đo" 29/10; M2-TESTING mục 2 |
| Firefox | chưa thử | | | | | | | | | | | | |
| Edge | chưa thử | | | | | | | | | | | | |
| Arc | chưa thử | | | | | | | | | | | | |
| Brave | chưa thử | | | | | | | | | | | | |
| VS Code | 29/10/2026 | script | đúng | **sai**; 5 và 10 ms cũng sai ("ôoi"); từ 20 ms đúng | — | không / không ở 30 ms | — | chờ T2 | — | 230 / 885 | 0 / — (ở 30 ms) | chờ T1 | PROGRESS "Số đo" 29/10 và nhật ký chẩn đoán 29/10 |
| Cursor | chưa thử | | | | | | | | | | | | |
| Zed | chưa thử | | | | | | | | | | | | |
| Sublime Text | 29/10/2026 | gõ tay | — | — | có số đo; kết quả chữ không được ghi | — | — | chờ T2 | — | 334 / 3.718 (gõ tay, n=35, sơ bộ) | — | chưa đủ dữ liệu | PROGRESS "Số đo" 29/10; DECISIONS câu hỏi A/B (selectedRange 17% thời gian phím) |
| JetBrains IDE | chưa thử | | | | | | | | | | | | |
| Xcode | chưa thử | | | | | | | | | | | | |
| Terminal | 29/10/2026 | script | đúng | **sai**; 5 và 10 ms đúng | — | không / không ở 30 ms | — | chờ T2 | — | 408 / 637 | 0 / — (ở 30 ms) | chờ T1 | PROGRESS "Số đo" 29/10 |
| iTerm2 | chưa thử | | | | | | | | | | | | |
| Warp | chưa thử | | | | | | | | | | | | |
| Ghostty | chưa thử | | | | | | | | | | | | |
| Zalo | chưa thử | | | | | | | | | | | | |
| Messenger (web) | chưa thử | | | | | | | | | | | | |
| Telegram | 30/10/2026 | System Events, 30 ms, Saved Messages, không gửi | đúng (câu mẫu cũ) | — | — | không / không | — | chờ T2 | — | 240 / 1.670 | 0 / 0 | chưa thấy lỗi | PROGRESS "Số đo" 30/10; M2-TESTING mục 2. `insertText` p50 1.830 / p99 3.491 µs; cả phím có thay p50 2.171 / p99 5.313 µs; replace 12, pass 34. M2-TESTING mục 4 dòng 3 (Return ngay sau từ) bỏ qua vì không gửi tin |
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
| Ghi chú (Notes) | chưa thử | | | | | | | | | | | | |
| Mail | chưa thử | | | | | | | | | | | | |
| Tin nhắn (Messages) | chưa thử | | | | | | | | | | | | |
| Spotlight | chưa thử | | | | | | | | | | | | |
| Finder (đổi tên tệp) | chưa thử | | | | | | | | | | | | |
| Figma | chưa thử | | | | | | | | | | | | |
| Raycast | chưa thử | | | | | | | | | | | | |
| Alfred | chưa thử | | | | | | | | | | | | |

K4–K6 của TextEdit: M2-TESTING mục 4 dòng 1, 4, 5, 6 (30/10/2026, agent tự gõ qua System Events). Các app khác chưa chạy K4–K6.

## 6. Giới hạn đã biết

### 6.1 Tự sửa chính tả của macOS đè lên chữ đã giữ (D4) — ghi ngày 30/10/2026

- Hiện tượng: từ macOS 27.2, ở ứng dụng bật tự sửa chính tả, khi phía trước là câu tiếng Việt, hệ thống có thể sửa chữ tiếng Anh vừa gõ thành chữ tiếng Việt ("…Hasaki car␣" → "cả"), **kể cả khi gõ bằng bàn phím U.S.**. Việc này xảy ra sau khi Dấu đã trả đúng "car", nên đè lên kết quả gõ đúp ("carr" → "car").
- Bằng chứng: `docs/DECISIONS.md` D4 (đoạn "Giới hạn đã biết"); `docs/PROGRESS.md` nhật ký 30/10/2026 (câu mẫu `selftest-typing` đổi thành "windows carr tooi yeeu tieengs Vieetj, Hasaki " để né, 3/3 ĐẠT); chú thích đầu `scripts/selftest-typing/run.sh`. Nguồn không ghi ứng dụng cụ thể đã quan sát; T6 điền cột "Tự sửa" cho từng app bằng K8.
- Dấu không tắt tự sửa của hệ thống (N4). Người dùng hoàn tác bằng ⌘Z hoặc bấm vào chữ bị sửa. Tự sửa là thuộc tính của từng ô soạn thảo do ứng dụng quyết định (ví dụ `NSTextView.isAutomaticSpellingCorrectionEnabled`, https://developer.apple.com/documentation/appkit/nstextview/isautomaticspellingcorrectionenabled), nên ứng dụng không dùng hệ thống văn bản của Apple có thể không bị (suy luận, cần kiểm chứng bằng K8).

### 6.2 Ứng dụng áp phím bất đồng bộ (câu hỏi A/B) — ghi ngày 29/10/2026

- Hiện tượng: Chrome, VS Code, Terminal đúng khi phím cách nhau từ 20 ms, nhưng sai khi phím đến dồn: dưới khoảng 10 ms ở Chrome, Terminal; dưới khoảng 20 ms ở VS Code. Các app này áp phím bất đồng bộ (Chromium/Electron; Terminal chờ shell in lại chữ), nên `selectedRange` trả ảnh chụp cũ; bộ gõ thấy lệch (`mismatch`), reset từ đang gõ, chữ ra thiếu dấu hoặc thay nhầm vùng. Ảnh chụp không cập nhật trong lúc `handle` đang chạy (hỏi lại 10 lần, cách 2 ms, vẫn y nguyên).
- Ví dụ lượt tự gõ đầu tiên ngày 29/10: VS Code ra "arroi yeu tiengs Vietj, ?indows Haki c", Terminal ra "tôi yêu tiêngs Viêtj, windows Hấki car".
- Không phải do thiếu quyền Trợ năng (bộ gõ không có quyền đó mà vẫn đúng ở 20 ms trở lên). Cách B (tự cộng dồn vị trí) cũng không cứu được, vì vị trí gốc cũng là ảnh chụp cũ và VS Code đổi gốc toạ độ. Đã thử và bỏ: chờ ứng dụng rồi hỏi lại; so chữ trước con trỏ bằng `attributedSubstring` (Safari trả chữ cũ nên hỏng cả Safari).
- Bằng chứng: `docs/DECISIONS.md` câu hỏi A/B (đã chốt cách A) và câu hỏi Chrome/Terminal; `docs/PROGRESS.md` mục "Số đo" (dòng "Cách A theo tốc độ gõ") và nhật ký 29/10 (chẩn đoán VS Code/Terminal).
- Hướng xử lý: M3 việc T1 thử gạch chân (D13) theo bundle ID, đo ở 0, 5, 10 ms rồi chốt. Người gõ tay hiếm khi có hai phím cách nhau dưới 10 ms, nhưng phím lặp khi giữ phím, máy đang tải nặng hay ứng dụng tạm đứng có thể làm phím đến dồn (suy luận; M6 đo dưới tải).

### 6.3 Ô mật khẩu — ghi ngày 30/10/2026

Ở ô nhập bảo mật (ví dụ ô mật khẩu trong Safari), macOS giữ bàn phím `com.apple.keylayout.US` và Dấu không nhận phím nào. Đây là hành vi của hệ thống, không phải lỗi. Nguồn: `docs/M2-TESTING.md` mục 4 dòng 17.

## 7. Còn mở

- Tiêu chí đưa một ứng dụng vào danh sách gạch chân (mục 1): sai ở tốc độ nào thì tính; cần quyết định sau T1. Nếu thành quy tắc thì ghi vào `docs/DECISIONS.md` (D13).
- `scripts/selftest-typing/run.sh` chỉ biết 5 ứng dụng. Thử nhiều ứng dụng ở 0 ms cần thêm ứng dụng vào script (mở ô trống, đọc lại chữ) hoặc chấp nhận gõ tay.
- Pages có hai bundle ID trên cùng máy (`com.apple.Pages` và `com.apple.iWork.Pages`); Numbers, Keynote bản mới đổi ID (`com.apple.Numbers`, `com.apple.Keynote`). Nếu các app này cần quy tắc, danh sách tương thích phải ghi đủ các ID.
