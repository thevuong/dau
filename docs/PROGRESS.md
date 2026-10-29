# Tiến độ

Nhật ký điều phối, để phiên sau (hoặc sau khi ngữ cảnh bị nén) tiếp tục đúng chỗ. Phiên chính cập nhật file này sau mỗi bước.

## Trạng thái hiện tại
- Mốc đang làm: M2 chờ người dùng gõ thử. M1 đã đóng (kiểm toán lần 2 ĐẠT). Ghi chú cũ về M1: — M1b Telex xong (cf5c2bb, ebfce9a, 50 test xanh); M1c VNI xong; engine 70 test xanh (HEAD a59c44f/ba6a2b8). Kiểm toán M1 lần 1: CHƯA ĐẠT chỉ vì 2 tài liệu lệch — đã sửa (7d28fb2). Siết D31 + test bổ sung (19fd8f1, 48c839c): 72 test xanh. Người dùng đã chốt 3 câu (D28, D31 nới địa danh, D36); engine-dev đang làm D31 + đo ảnh hưởng, sau đó kiểm toán lại. M2 bắt đầu song song (imk-dev).
- Việc đang chờ người dùng: Bundle ID / Team ID (placeholder `com.example.dau`, Team ID trống — người dùng sẽ gửi sau)
- M1a xong: `docs/OPENKEY-NOTES.md` (commit b0739c7).
- M0: khung xong (commit b2a331d, 06f0dcb, 6fe660b), phiên chính đã kiểm chứng lại: xcodegen + build Debug 2 target với `-destination 'generic/platform=macOS'` ra `x86_64 arm64`, swift test 2 package xanh, bộ gõ không có network.client. Tên hiển thị "Dấu" cho locale `en` đã sửa (0b188dd). **Kiểm toán M0: ĐẠT.**
- Chốt kỹ thuật M0: Debug lệnh trơn chỉ build arm64 (Xcode 27.1 build package local theo kiến trúc máy); Debug universal dùng `-destination 'generic/platform=macOS'`, Release luôn universal. CI (M7) phải dùng destination này. ID input mode viết cứng trong `Apps/DauInputMethod/Info.plist` và `InfoPlist.xcstrings` — đổi Bundle ID phải sửa cả hai.
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
| M2 Bộ gõ tối thiểu | đang làm | — | mã xong (9999122…d5f0123), 14 test IMK xanh; chờ người dùng cài và gõ thử theo `docs/M2-TESTING.md` để đo A/B |
| M3 Độ tin cậy | chưa | — | |
| M4 App Cài đặt | đang làm | — | app-ui-dev: DauShared settings model + cửa sổ Cài đặt 4 mục (song song, chờ M2) |
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
| 29/10/2026 | Cấp phát trong `handle` VNI | 0 lần / 37.200 phím | như đo Telex |
| 29/10/2026 | Cấp phát bộ nhớ trong `handle` | 0 lần / 41.600 phím | chương trình ngoài repo móc `malloc_logger`, có đối chứng dương; chưa có trong CI |

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
