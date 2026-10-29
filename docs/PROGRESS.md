# Tiến độ

Nhật ký điều phối, để phiên sau (hoặc sau khi ngữ cảnh bị nén) tiếp tục đúng chỗ. Phiên chính cập nhật file này sau mỗi bước.

## Trạng thái hiện tại
- Mốc đang làm: M1 — M1b Telex xong (cf5c2bb, ebfce9a, 50 test xanh); M1c VNI đang làm (engine-dev)
- Việc đang chờ người dùng: Bundle ID / Team ID (placeholder `com.example.dau`, Team ID trống — người dùng sẽ gửi sau); quyết định D26 × mốc khôi phục D4 (password → pasword) và 2 điểm nhỏ (D33 khi tắt tự khôi phục, D20 với gõ đúp sau seed)
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
| M1 Engine | đang làm | — | OPENKEY-NOTES xong; 13 điểm đã chốt (D28–D33 + sửa D4, D20–D23, D26); engine Telex đang làm |
| M2 Bộ gõ tối thiểu | chưa | — | câu hỏi mở A/B, Chrome/Terminal |
| M3 Độ tin cậy | chưa | — | |
| M4 App Cài đặt | chưa | — | |
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

## Số đo
(engine µs/phím, chi phí selectedRange theo app, độ trễ p50/p99 dưới tải, bộ nhớ…)
| Ngày | Số đo | Giá trị | Cách đo |
|---|---|---|---|
| 29/10/2026 | `VietEngine.handle` Telex, release | 0,148 µs/phím (8,9 ms / 60.325 phím, best of 5) | `swift test -c release`, `PerformanceTests` (văn bản Việt/Anh trộn, có Backspace), Mac arm64 |
| 29/10/2026 | `VietEngine.handle` Telex, debug | 3,0–3,4 µs/phím | như trên, debug |
| 29/10/2026 | Cấp phát bộ nhớ trong `handle` | 0 lần / 41.600 phím | chương trình ngoài repo móc `malloc_logger`, có đối chứng dương; chưa có trong CI |

## Nhật ký
(ngày — việc — agent — kết quả — commit)
- 29/10/2026 — người dùng duyệt đề xuất khởi động: ranh giới từ (D4, D21), D26 gõ đúp phím dấu, D27 bỏ `[` `]`, ô trống cho nhãn web editor (UI.md, N5), đưa D18 về đúng thứ tự — phiên chính — xong (6e4f17a)
- 29/10/2026 — M1a OPENKEY-NOTES — researcher — xong (b0739c7)
- 29/10/2026 — M0 khung + sửa tên hiển thị en (D24) — release-eng — xong (b2a331d, 06f0dcb, 6fe660b, 0b188dd); kiểm toán M0 ĐẠT
- 29/10/2026 — người dùng duyệt 13 điểm engine từ OPENKEY-NOTES mục 7: D28 bỏ dấu tự do, D29 Telex đơn giản, D30 chính tả luôn chạy, D31 âm tiết hợp lệ, D32 Backspace, D33 độ dài từ; sửa D4 (ranh giới: mọi ký tự in ra khôi phục; mũi tên/Esc/chuột/⌘ chỉ reset), D20, D21, D22, D23, D26; Quick Telex và tạm tắt ⌃/⌘ vào mục loại bỏ — phiên chính — xong
- 29/10/2026 — người dùng duyệt 8 điểm từ kiểm toán M0 + OPENKEY-NOTES: D4 mốc khôi phục, D26 khoá giữ sau ⌫, D28 phím không cần sát + tắt thì dd liền, D29 câu chữ, D30 tiền tố hợp lệ, D33 khôi phục ngay, D34 chữ hoa với phím biến đổi — phiên chính — xong
- 29/10/2026 — M1b engine Telex + Telex đơn giản — engine-dev — 50 test xanh debug/release, 0,148 µs/phím, 0 cấp phát (cf5c2bb, ebfce9a). Phát hiện: D26 + mốc khôi phục làm từ Anh có ss/ff/rr mất một chữ — chờ người dùng. Chốt theo cách engine đang làm (không đổi DECISIONS câu chữ, ghi ở đây): tắt bỏ dấu tự do vẫn tự dời dấu; "uow" đứng riêng → "uơ", gõ tiếp → ươ
