# Tiến độ

Nhật ký điều phối, để phiên sau (hoặc sau khi ngữ cảnh bị nén) tiếp tục đúng chỗ. Phiên chính cập nhật file này sau mỗi bước.

## Trạng thái hiện tại
- Mốc đang làm: M3 (chưa bắt đầu). M2 và M4 đã đóng (kiểm toán lần 3 ĐẠT, 30/10/2026). Việc hoãn: VoiceOver (D17) và biểu tượng V → M3; VoiceOver/Tab trong Cài đặt, máy tiếng Anh hẳn, sheet chế độ tối → M7; reset khi đổi nguồn không qua `activateServer`, tự sửa chính tả (D4) → M3. Test hiện tại: engine 76, DauShared 21, IMK 25, snapshot-settings 10. M0, M1 đã đóng. Bundle ID đã chốt `com.codefastlabs.dau` (D24).
- Việc đang chờ người dùng: bật nguồn nhập liệu mới `com.codefastlabs.dau.inputmethod.Dau.vi` sau khi đổi Bundle ID. Team ID: Personal Team miễn phí `M58DANM3ZP` (30/10/2026), ký tự động "Apple Development"; bản phát hành dùng Developer ID ở M7.
- M1a xong: `docs/OPENKEY-NOTES.md` (commit b0739c7).
- M0: khung xong (commit b2a331d, 06f0dcb, 6fe660b), phiên chính đã kiểm chứng lại: xcodegen + build Debug 2 target với `-destination 'generic/platform=macOS'` ra `x86_64 arm64`, swift test 2 package xanh, bộ gõ không có network.client. Tên hiển thị "Dấu" cho locale `en` đã sửa (0b188dd). **Kiểm toán M0: ĐẠT.**
- Chốt kỹ thuật M0: Debug lệnh trơn chỉ build arm64 (Xcode 27.1 build package local theo kiến trúc máy); Debug universal dùng `-destination 'generic/platform=macOS'`, Release luôn universal. CI (M7) phải dùng destination này. ID input mode viết cứng trong `Apps/DauInputMethod/Info.plist` và `InfoPlist.xcstrings` (Xcode không thay biến trong khoá plist, đã thử 30/10/2026) — đổi Bundle ID phải sửa cả hai.
- Môi trường: Xcode 27.1 ở `/Applications/Xcode.app` nhưng `xcode-select` đang trỏ CommandLineTools → mọi lệnh build dùng `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Swift 6.4.

## Kế hoạch M0 + M1
| Việc | Agent | Song song |
|---|---|---|
| M0: git init, .gitignore, LICENSE, README, project.yml, khung 2 app + 2 package, build Debug universal | release-eng | với M1-nghiên cứu |
| M1a: clone OpenKey ra /tmp, viết `docs/OPENKEY-NOTES.md` | researcher | với M0 |
| M1b: engine Telex + test (sau M1a, đối chiếu mâu thuẫn trước) | engine-dev | sau M1a |
| M1c: VNI, Telex đơn giản, gõ tắt phụ âm, test hiệu năng | engine-dev | sau M1b |
| Kiểm toán M0, M1 | auditor | cuối mỗi mốc |

## Mốc
| Mốc | Trạng thái | Kiểm toán | Ghi chú |
|---|---|---|---|
| M0 Khung dự án | xong | ĐẠT (29/10) | build Debug universal cần `-destination generic/platform=macOS` |
| M1 Engine | xong | ĐẠT (29/10, lần 2) | Telex, Telex đơn giản, VNI, 75 test; release ~0,15 µs/phím; 0 từ sai / 474 từ, 0 khôi phục nhầm / 15.796 âm tiết, fuzz 800k thao tác không crash |
| M2 Bộ gõ tối thiểu | xong | ĐẠT (30/10, lần 3; lần 1, 2 CHƯA ĐẠT vì tài liệu) | cách A; tự gõ 30 ms/phím đúng ở TextEdit, Safari, Chrome, VS Code, Terminal, Telegram (thay Slack); Sublime gõ tay; selectedRange p50 0,2–0,6 ms (Debug). M2-TESTING mục 4 ĐẠT trừ việc hoãn (VoiceOver, biểu tượng V → M3; Telegram Return bỏ qua). Test engine 76, IMK 25 |
| M3 Độ tin cậy | chưa | — | |
| M4 App Cài đặt | xong | ĐẠT (30/10, lần 3) | DauShared + cửa sổ 4 mục (2d6206e, c731c61); bộ gõ đọc cài đặt chung (0aa4872). App Group chạy với Team ID M58DANM3ZP (958a5a8). Bỏ chế độ Anh, quy tắc theo app chỉ còn gạch chân (9680c68, ea676ae, b23b266). M4-TESTING ĐẠT trừ việc hoãn sang M7 (máy tiếng Anh hẳn, sheet tối, VoiceOver/Tab). Ma trận UI 12/12. Test DauShared 21, IMK 25, snapshot-settings 10 |
| M5 Onboarding, cài, gỡ | chưa | — | |
| M6 Hiệu năng dưới tải | chưa | — | |
| M7 Phát hành | chưa | — | |
| M8 Website | chưa | — | |

## Ghi nhớ cho M7 (từ kiểm toán M0)
- Bản Release ký ad-hoc vẫn có `get-task-allow`; phải bỏ trước notarize. Hardened runtime mới chỉ ở Release.
- `.gitignore` bỏ qua `Package.resolved` → ghim phiên bản Sparkle chính xác trong `project.yml`.
- Thêm `*.p8`, `*.pem`, `*.key`, `*.xcarchive` vào `.gitignore`.
- UI.md onboarding viết cứng "⌃Space" — phải hiện phím tắt hệ thống thật (N5), xử lý ở M5.
- `en.lproj` khiến menu hệ thống có thể hiện tiếng Anh trên máy tiếng Anh — quyết định ở M4.

## Ghi nhớ cho M2 (từ kiểm toán M1)
- Phím xoá gọi `backspace()`; `handle` coi 0x7F là reset.
- Enter bàn phím số (0x03), Return, Tab: dùng `endWord()` nếu để app tự xử lý phím.
- Từ seed dạng NFD: `deleteCount` phải đổi sang UTF-16 theo chuỗi đã seed.
- M7: đưa phép đếm cấp phát (`malloc_logger`) vào CI.

## Số đo
(engine µs/phím, chi phí selectedRange theo app, độ trễ p50/p99 dưới tải, bộ nhớ…)
| Ngày | Số đo | Giá trị | Cách đo |
|---|---|---|---|
| 29/10/2026 | `VietEngine.handle` Telex, release | 0,148 µs/phím (8,9 ms / 60.325 phím, best of 5) | `swift test -c release`, `PerformanceTests` (văn bản Việt/Anh trộn, có Backspace), Mac arm64 |
| 29/10/2026 | `VietEngine.handle` Telex, debug | 3,0–3,4 µs/phím | như trên, debug |
| 29/10/2026 | `VietEngine.handle` VNI, release | 0,142 µs/phím (8,5 ms / 60.071 phím, best of 5) | `PerformanceTests`, đoạn VNI dài; Telex đo lại cùng lượt 0,154 µs/phím |
| 29/10/2026 | IMK cách A, Sublime Text 4 (Debug, sơ bộ) | `selectedRange` p50 334 / p99 3.718 µs; `insertText` p50 1.466 / p99 7.787 µs; cả phím có thay p50 2.002 / p99 8.087 µs (n=35) | `scripts/perf-report.sh`, người dùng gõ tay |
| 29/10/2026 | IMK cách A, TextEdit (Debug, sơ bộ) | `selectedRange` p50 288 / p99 7.306 µs; `insertText` p50 3.760 / p99 8.546 µs; cả phím có thay p50 4.536 / p99 15.933 µs (n=11) | như trên |
| 29/10/2026 | IMK cách A, Safari (Debug, sơ bộ) | `selectedRange` p50 333 / p99 1.639 µs; `insertText` p50 4.298 / p99 13.696 µs; cả phím có thay p50 4.790 / p99 14.242 µs (n=11) | `scripts/perf-report.sh`, người dùng gõ tay |
| 29/10/2026 | IMK cách A, Chrome (Debug, sơ bộ) | `selectedRange` p50 380 / p99 3.976 µs; `insertText` p50 4.581 / p99 11.309 µs; cả phím có thay p50 5.013 / p99 14.964 µs (n=11); không có `event_client-not-text-input` | `scripts/perf-report.sh --last 5m --app Chrome` |
| 29/10/2026 | IMK cách A, VS Code (Debug, tự gõ bằng System Events) | `selectedRange` p50 224 / p99 732 µs; `insertText` p50 346 µs; **4 lần lệch dự đoán con trỏ** → kết quả sai: "arroi yeu tiengs Vietj, ?indows Haki c" | `scripts/perf-report.sh --app Code` |
| 29/10/2026 | IMK cách A, Terminal (Debug, tự gõ) | `selectedRange` p50 179 / p99 314 µs; `insertText` p50 243 µs; **3 lần lệch** → "tôi yêu tiêngs Viêtj, windows Hấki car" (sai từ thứ 3) | `--app Terminal` |
| 29/10/2026 | TextEdit (tự gõ lại) | đúng: "tôi yêu tiếng Việt, windows Hasaki car" | |
| 29/10/2026 | Cấp phát trong `handle` VNI | 0 lần / 37.200 phím | như đo Telex |
| 29/10/2026 | Cấp phát bộ nhớ trong `handle` | 0 lần / 41.600 phím | chương trình ngoài repo móc `malloc_logger`, có đối chứng dương; chưa có trong CI |
| 29/10/2026 | Cách A theo tốc độ gõ (Debug), câu mẫu `tooi yeeu tieengs Vieetj, windows Hasaki carr ` | 0 ms/phím (System Events gõ cả chuỗi, ~1–2 ms): TextEdit, Safari đúng; Chrome, VS Code, Terminal SAI (mismatch 3–4, thay nhầm vùng ở lần thay đầu của từ). 5 và 10 ms: Chrome, Terminal đúng; VS Code sai từ đầu ("ôoi"). 20, 30, 60, 120 ms: cả 5 app đúng | `scripts/selftest-typing/run.sh --delay N all`, log `diag` |
| 29/10/2026 | Cách A, 30 ms/phím, phím có thay (n=12 mỗi app) | `selectedRange` p50/p99 µs: TextEdit 327/606, Safari 622/1.057, Chrome 415/694, VS Code 230/885, Terminal 408/637; cả phím có thay p50/p99 µs: 3.406/7.617, 1.494/4.731, 1.081/5.296, 617/1.236, 1.165/1.669; mismatch 0 | như trên |
| 30/10/2026 | IMK cách A, Telegram (Debug, tự gõ 30 ms/phím) | `selectedRange` p50 240 / p99 1.670 µs; `insertText` p50 1.830 / p99 3.491 µs; cả phím có thay p50 2.171 / p99 5.313 µs; replace 12, pass 34; mismatch 0, unsupported 0; câu mẫu đúng, không gạch chân, không nhảy chữ | `scripts/perf-report.sh --app Telegram`; agent tự gõ qua System Events trong Saved Messages (`ru.keepcoder.Telegram`), chỉ gõ, không gửi |

## Nhật ký
(ngày — việc — agent — kết quả — commit)
- 29/10/2026 — người dùng duyệt đề xuất khởi động: ranh giới từ (D4, D21), D26 gõ đúp phím dấu, D27 bỏ `[` `]`, ô trống cho nhãn web editor (UI.md, N5), đưa D18 về đúng thứ tự — phiên chính — xong (6e4f17a)
- 29/10/2026 — M1a OPENKEY-NOTES — researcher — xong (b0739c7)
- 29/10/2026 — M0 khung + sửa tên hiển thị en (D24) — release-eng — xong (b2a331d, 06f0dcb, 6fe660b, 0b188dd); kiểm toán M0 ĐẠT
- 29/10/2026 — người dùng duyệt 13 điểm engine từ OPENKEY-NOTES mục 7: D28 bỏ dấu tự do, D29 Telex đơn giản, D30 chính tả luôn chạy, D31 âm tiết hợp lệ, D32 Backspace, D33 độ dài từ; sửa D4 (ranh giới: mọi ký tự in ra khôi phục; mũi tên/Esc/chuột/⌘ chỉ reset), D20, D21, D22, D23, D26; Quick Telex và tạm tắt ⌃/⌘ vào mục loại bỏ — phiên chính — xong
- 29/10/2026 — người dùng duyệt 8 điểm từ kiểm toán M0 + OPENKEY-NOTES: D4 mốc khôi phục, D26 khoá giữ sau ⌫, D28 phím không cần sát + tắt thì dd liền, D29 câu chữ, D30 tiền tố hợp lệ, D33 khôi phục ngay, D34 chữ hoa với phím biến đổi — phiên chính — xong
- 29/10/2026 — M1b engine Telex + Telex đơn giản — engine-dev — 50 test xanh debug/release, 0,148 µs/phím, 0 cấp phát (cf5c2bb, ebfce9a). Phát hiện: D26 + mốc khôi phục làm từ Anh có ss/ff/rr mất một chữ — chờ người dùng. Chốt theo cách engine đang làm (không đổi DECISIONS câu chữ, ghi ở đây): tắt bỏ dấu tự do vẫn tự dời dấu; "uow" đứng riêng → "uơ", gõ tiếp → ươ
- 29/10/2026 — M1c VNI — engine-dev — 68 test xanh debug/release, 0,142 µs/phím (8bddba8, ecd81b3)
- 29/10/2026 — người dùng chọn giữ cách A: chữ cái lặp trùng phím dấu gõ 3 lần (passsword); ghi vào D26 — phiên chính — xong
- 29/10/2026 — người dùng duyệt 4 điểm: D33 khi tắt tự khôi phục chỉ ngừng biến đổi; D20 hợp lệ theo mức tiền tố + gõ đúp là bỏ dấu; D28 tắt vẫn dời dấu; D35 uơ/ươ — phiên chính — xong
- 29/10/2026 — sửa engine theo D20/D33 mới, 70 test xanh, Telex 0,151 / VNI 0,141 µs/phím release (a59c44f, ba6a2b8); làm rõ câu chữ D20 cho khớp ví dụ "viet" + j → "vietj" người dùng đã duyệt — engine-dev, phiên chính
- 29/10/2026 — kiểm toán M1 lần 1 — auditor — CHƯA ĐẠT (ARCHITECTURE DauEngine lệch mã; OPENKEY-NOTES `uow` + 3 chỗ cũ) → phiên chính sửa tài liệu
- 29/10/2026 — siết D31 (iê/yê, c + oa/uy) + test VNI hoa, hofa kiểu cũ, ⌫ hết từ — engine-dev — 72 test xanh, Telex 0,152 / VNI 0,144 µs/phím (19fd8f1, 48c839c)
- 29/10/2026 — người dùng duyệt: D28 tắt vẫn cho phím biến đổi từ xa; D31 nới k/âm cuối k/kr cho địa danh (đo ảnh hưởng); D36 VNI chữ số sau âm tiết thành dấu — phiên chính — xong
- 29/10/2026 — M2 mã bộ gõ (cách A, chỉ hỏi selectedRange khi deleteCount > 0; dự đoán con trỏ trong từ, lệch thì reset), menu Kiểu gõ, icon V/E tạm (TIFF), script cài Debug + perf-report, checklist 6 app — imk-dev — build universal, 14 test IMK + 72 test engine xanh, không quyền mạng, log perf không chứa chữ gõ (9999122, 0420967, 49936c2, a775289, d5f0123). Mở: khe hở click trước lần thay đầu tiên của từ (D11), D17 để sau khi thử VoiceOver, App Group dời sang M4, icon PDF vs TIFF (M7), gạch chân D13 chưa làm
- 29/10/2026 — D31 nới địa danh: đo 3 phương án (đầy đủ hỏng 19 từ Anh; d hỏng 6; a hỏng 3) — engine-dev — người dùng chọn d
- 29/10/2026 — D31 phương án d vào mã + test địa danh — engine-dev — 75 test xanh, Telex 0,156 / VNI 0,147 µs/phím (31a04b3)
- 29/10/2026 — kiểm toán M1 lần 2 — auditor — **ĐẠT** (75 test, 512 từ Việt: chỉ "ăk" + phím biến đổi sau k; 16.960 âm tiết: 0 khôi phục nhầm từ chuẩn; fuzz 800k không crash; 0 cấp phát). Đóng M1. Người dùng chọn giữ: "lakws" không biến đổi, gõ "lawks" (ghi vào D31)
- 29/10/2026 — gõ thử TextEdit (người dùng): câu mẫu ra đúng, không gạch chân, không nhảy chữ — tiêu chí M2 còn Safari
- 29/10/2026 — gõ thử Safari (người dùng): câu mẫu ra đúng, không gạch chân, không nhảy chữ → tiêu chí "TextEdit và Safari không gạch chân" của M2 đạt. Còn: đo Chrome, Slack, VS Code, Terminal để chốt A/B và câu hỏi Chrome/Terminal, rồi kiểm toán M2
- 29/10/2026 — gõ thử Chrome (người dùng): câu mẫu ra đúng, không gạch chân, không nhảy chữ; selectedRange trả vị trí hợp lệ → Chrome không cần quyền Trợ năng/gạch chân. Còn Slack, VS Code, Terminal
- 29/10/2026 — M4 model cài đặt chung + cửa sổ Cài đặt 4 mục — app-ui-dev — build universal, 25 test DauShared xanh, không quyền mạng (2d6206e, c731c61). Phiên chính đổi APP_GROUP_ID thành `.shared` (trùng bundle ID app chủ thì UserDefaults từ chối) (3ffaee1). Quyết định kỹ thuật: giữ `en.lproj` (D24) và ép ngôn ngữ app = vi bằng registration domain
- 29/10/2026 — M4: sidebar đủ chữ, cửa sổ tối thiểu 820×520 (0cbef3c); app chủ ép bản địa hoá vi qua argument domain, tôn trọng `-AppleLanguages` dòng lệnh, `--print-localizations` ra ["vi"]/["en"] (0c8e44b); chế độ tối đúng (lỗi do bộ chụp). Còn: người dùng xem menu/Finder trên máy tiếng Anh; imk-dev nối DauShared vào bộ gõ
- 29/10/2026 — bộ gõ đọc DauShared, đổi options kèm reset, menu Kiểu gõ ghi store, D5 chế độ theo app bằng `selectInputMode:` (IMK), nhớ chế độ lưu trong defaults của bộ gõ — imk-dev — 30 test IMK, build universal, không quyền mạng (0aa4872). Mở: D20 seed (M3), D13 marked text (M3), D17, mục "Cài đặt Dấu…" trong menu; App Group ad-hoc có thể hỏng im lặng / hiện hộp thoại
- 29/10/2026 — người dùng chốt D5: quy tắc/chế độ nhớ chỉ áp khi chuyển sang app khác, giữ chế độ trong cùng app, nhớ chế độ lúc rời app — phiên chính — xong
- 29/10/2026 — icon app tạm + phiên bản 0.1.0 — release-eng — build universal trong worktree sạch, Assets.car đủ cỡ (1426f85). Đang làm lại 2 dấu theo hình học artboard AppIcon (stroke tròn, không dùng dấu của font). Người dùng chê giao diện Cài đặt không giống mockup → app-ui-dev đang làm lại theo HTML artboard
- 29/10/2026 — icon app khớp artboard AppIcon (dấu vẽ nét tròn theo toạ độ mockup, lệch 0,54% pixel trong tấm) — release-eng (b447b5d). M7: Icon Composer từ `Resources/Brand/AppIcon.svg`; script `scripts/make-app-icon.sh`
- 29/10/2026 — dựng lại Cài đặt theo HTML artboard (a89ef37) + bộ chụp `scripts/snapshot-settings` (1bc88c8) — app-ui-dev — build xanh; trong sandbox: input source enabled, phím tắt đọc được (⌃ Space, entitlement shared-preference.read-only cho com.apple.symbolichotkeys/HIToolbox — báo M7 khi notarize); phiên chính đã so ảnh với artboard. Sửa gợi ý Bỏ dấu tự do thành "…sau nguyên âm" cho đúng D28 (N5). Còn: người dùng xem app thật (tiêu đề toolbar, Tab/VoiceOver, Delete); gỡ `SettingsExamples` thừa trong DauShared
- 29/10/2026 — sửa nhảy bố cục (toolbar đổi theo mục → header cố định trong nội dung) + màu theo HIG (Form grouped, màu ngữ nghĩa, accent hệ thống) — app-ui-dev (693271d, 72ead82); đo khung 4 mục lệch 0 pt. Chọn giữ `.secondary` cho chữ gợi ý như Cài đặt hệ thống/HIG (3.9:1 ở chế độ sáng; người cần hơn dùng Tăng độ tương phản của hệ thống)
- 29/10/2026 — Cài đặt bỏ Form, tự dựng card bằng màu ngữ nghĩa (underPage/controlBackground/separator), toolbar trở lại có đèn giao thông, tiêu đề mục là ToolbarItem, SegmentedPicker bọc NSSegmentedControl trải ngang, nút capsule large, cửa sổ 820×600 — app-ui-dev (d6aa417, ddb38c8); bộ chụp dựng artboard bằng WKWebView + ghép mockup|app. Còn chờ người dùng: màu segmented khi cửa sổ active, sidebar vibrancy thật
- 29/10/2026 — icon sidebar vẽ lại đúng path + mã màu mockup, hàng sidebar tự dựng (ô 22, khe 9), segmented phần chọn trung tính (`controlColor`) — app-ui-dev (a5045dc, fab8b95). Chờ người dùng xem trạng thái active
- 29/10/2026 — người dùng chốt giữ control hệ thống (D9) dù segmented macOS 27 khác hình viên thuốc của mockup — phiên chính — ghi vào D9
- 29/10/2026 — tách ô tìm và nút + ở header Ứng dụng (ToolbarSpacer), bỏ mọi phần tự vẽ theo D9 — app-ui-dev (0cdcffa, 439e0b1)
- 29/10/2026 — nút + ở header Ứng dụng méo (bezel 36 cao, label hẹp) → nới label, đo lại bezel tròn — phiên chính
- 29/10/2026 — header che nội dung cuộn (scrollEdgeEffectStyle .hard) + thanh cuộn nằm trong cửa sổ (trước nằm ngoài vì ScrollView macOS 26 trải dưới sidebar), chừa cột scroller khi luôn hiện để không nhảy — app-ui-dev (da3ae8d)
- 29/10/2026 — bỏ khoảng chừa 17 pt (gây dải hở phải); scroll view tới mép cửa sổ; ma trận cửa sổ thật `scripts/check-settings-window/run.sh` + `docs/UI-CHECKS.md` — app-ui-dev (62a07f5, 9e0dbf3). Chốt: thanh cuộn legacy làm mục có cuộn hẹp 17 pt như macOS chuẩn (x/y không đổi)
- 29/10/2026 — người dùng xác nhận giao diện Cài đặt (mép phải, thanh cuộn) đã ổn
- 29/10/2026 — đẩy repo công khai lên https://github.com/thevuong/dau (nhánh main, theo yêu cầu người dùng); đã quét lịch sử không có khoá/token — phiên chính
- 29/10/2026 — người dùng cấp quyền Trợ năng cho Claude; phiên chính tự gõ thử bằng System Events: TextEdit đúng; VS Code và Terminal SAI (lệch dự đoán con trỏ → reset). Slack không cài. Chờ chẩn đoán (imk-dev)
- 29/10/2026 — kiểm toán M4 lần 1 — auditor — CHƯA ĐẠT; ma trận UI mã 0, test 25/76/30/9 xanh. Giao app-ui-dev sửa N5 + mã chết + ARCHITECTURE; imk-dev thêm "Cài đặt Dấu…" sau chẩn đoán VS Code/Terminal; hỏi người dùng D9/D25 (ngoại lệ màu, banner cam, nút Nâng cao)
- 29/10/2026 — người dùng chốt: không ngoại lệ màu (icon sidebar dùng màu hệ thống), banner cam hệ thống, chấp nhận nút "Nâng cao" ghép — ghi vào D9 — phiên chính
- 29/10/2026 — sửa kiểm toán M4: N5 (gạch chân, D20 tạm tắt kèm ô trống), màu hệ thống cho icon sidebar, banner cam hệ thống, gỡ SettingsExamples, ARCHITECTURE — app-ui-dev (d922a70, 373db68, 073bc75); ma trận UI mã 0. Chờ imk-dev (App Group selftest, chẩn đoán VS Code/Terminal, "Cài đặt Dấu…") rồi kiểm toán lại M4
- 29/10/2026 — chẩn đoán VS Code/Terminal — imk-dev — không phải lỗi dự đoán: app áp phím bất đồng bộ (Chromium/Electron, Terminal chờ shell echo) nên `selectedRange` là ảnh chụp cũ khi phím đến dồn (< ~10 ms; VS Code < ~20 ms); ảnh chụp không cập nhật trong lúc `handle` chạy (hỏi lại 10 × 2 ms vẫn y nguyên). Đã thử và bỏ: hỏi lại chờ app; so chữ trước con trỏ bằng `attributedSubstring` (Safari trả chữ cũ → hỏng cả Safari; VS Code textarea chỉ là cửa sổ nhỏ nên so khớp vô nghĩa). Từ 20 ms/phím cả 5 app đúng. Chờ phiên chính chốt A/B + gạch chân D13
- 29/10/2026 — người dùng chốt A/B: cách A, sửa N3 "tối thiểu lời gọi"; M3 thử D13 cho app bất đồng bộ. App Group ad-hoc bị từ chối → người dùng sẽ dùng Personal Team miễn phí để lấy Team ID — phiên chính
- 30/10/2026 — Team ID `M58DANM3ZP` (Personal Team) vào project.yml, ký tự động; `scripts/selftest-app-group.sh` PASS (cả khi bộ gõ vừa khởi động). Sửa script: chờ `settings-loaded` thay cho `sleep 1` (bộ gõ mới chạy mất ~7 s mới nạp cài đặt), `synchronize=failed` chỉ ghi chú, thêm kiểm tra tiến trình app mới đọc lại giá trị. M4-TESTING bước 1 (store=appGroup, không hộp thoại) và bước 2 (app đặt VNI, gõ `Vie65t` trong TextEdit ra "Việt") ĐẠT — phiên chính
- 30/10/2026 — kiểm toán M2 lần 1 — auditor — CHƯA ĐẠT chỉ vì tài liệu (mã khớp N1–N5, D4, D5, D8, D13, D24). Người dùng duyệt: D11 theo cách A, sửa tỉ lệ selectedRange theo số đo từng app, trả lời câu Accessibility (không cần), D4 thêm các sự kiện chỉ reset; thay Slack bằng Telegram. Đã sửa DECISIONS, ROADMAP, M2-TESTING, ghi chú canvas — phiên chính
- 30/10/2026 — người dùng duyệt bỏ chế độ "Dấu – Tiếng Anh" (D2). Thử TIS từ bộ gõ có sandbox (imk-dev): `TISSelectInputSource` đổi được nguồn nhưng bước báo app đang gõ bị chặn (`deny mach-lookup com.apple.tsm.portname`, temporary-exception không gỡ được) → theo phương án dự phòng đã duyệt: quy tắc theo app chỉ còn gạch chân, bỏ nhớ chế độ theo app, dùng tuỳ chọn macOS "Tự động chuyển sang nguồn đầu vào của tài liệu". Sửa D2, D5, D14, D17 và ghi chú canvas. M2-TESTING mục 4: 11 ĐẠT, 0 hỏng (agent tự gõ); Telegram tự gõ 30 ms đúng, selectedRange p50 240 / p99 1.670 µs, insertText p50 1.830 µs, mismatch 0; test IMK 34 xanh — phiên chính
- 30/10/2026 — kiểm toán lại M2+M4 — auditor — CHƯA ĐẠT (tài liệu, bằng chứng); sửa README, ROADMAP, OPENKEY-NOTES, điền M2/M4-TESTING — general-purpose (agent tài liệu) — xong (9162fd8)
- 30/10/2026 — M4 bước 5, 6, 8 ĐẠT, bước 7 không áp dụng; M2 dòng 9–10 ĐẠT với ⌃Space (agent tự gõ). Sửa popup gạch chân của quy tắc vẫn chọn được "Có gạch chân" (`.disabled` trên mục Picker kiểu menu không có tác dụng trên macOS; binding giờ từ chối). Câu mẫu `selftest-typing` đổi thành "windows carr tooi yeeu tieengs Vieetj, Hasaki " (3/3 ĐẠT) để né tự sửa chính tả. Ma trận UI 12/12 ĐẠT trên bản mới. M3 thêm: reset khi đổi nguồn mà không có `activateServer` — phiên chính
- 30/10/2026 — kiểm toán lần 3 M2 + M4 — auditor — ĐẠT cả hai (sửa dòng tóm tắt trong commit đóng mốc); ma trận UI 12/12, test 76/21/25/10 xanh. Đóng M2, M4 — phiên chính
- 30/10/2026 — đổi Bundle ID sang com.codefastlabs.dau (3b8864b): cài đè cùng đường dẫn `~/Library/Input Methods/DauInputMethod.app` với ID khác làm bộ đệm TIS lệch (ID nguồn mới nhưng `kTISPropertyBundleID` vẫn là ID cũ, báo enabled trong khi `AppleEnabledInputSources` không có) → thêm nguồn không kích hoạt được. Cách sửa: đăng xuất/đăng nhập. Ghi cho M5 (cài/gỡ, cập nhật): không đổi ID bộ gõ giữa các bản; nếu phải đổi thì hướng dẫn đăng xuất — phiên chính
