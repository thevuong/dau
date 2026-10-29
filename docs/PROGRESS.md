# Tiến độ

Nhật ký điều phối, để phiên sau (hoặc sau khi ngữ cảnh bị nén) tiếp tục đúng chỗ. Phiên chính cập nhật file này sau mỗi bước.

## Trạng thái hiện tại
- Mốc đang làm: M0 (release-eng) song song M1 bước nghiên cứu (researcher)
- Việc đang chờ người dùng: Bundle ID / Team ID (M0 dùng placeholder `com.example.dau`, Team ID trống — người dùng sẽ gửi sau); chốt các điểm M1–M17 trong `docs/OPENKEY-NOTES.md` mục 7 (đã gửi đề xuất, chặn engine-dev ở phần âm tiết hợp lệ, Telex đơn giản, bỏ dấu tự do, D20)
- M1a xong: `docs/OPENKEY-NOTES.md` (commit b0739c7).
- M0: khung xong (commit b2a331d, 06f0dcb, 6fe660b), phiên chính đã kiểm chứng lại: xcodegen + build Debug 2 target với `-destination 'generic/platform=macOS'` ra `x86_64 arm64`, swift test 2 package xanh, bộ gõ không có network.client. Đang sửa: tên hiển thị "Dấu" cho locale `en` (D24). Sau đó kiểm toán M0.
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
| M0 Khung dự án | đang làm | — | khung xong, chờ sửa D24 + kiểm toán |
| M1 Engine | đang làm | — | OPENKEY-NOTES xong; chờ người dùng chốt 13 điểm |
| M2 Bộ gõ tối thiểu | chưa | — | câu hỏi mở A/B, Chrome/Terminal |
| M3 Độ tin cậy | chưa | — | |
| M4 App Cài đặt | chưa | — | |
| M5 Onboarding, cài, gỡ | chưa | — | |
| M6 Hiệu năng dưới tải | chưa | — | |
| M7 Phát hành | chưa | — | |
| M8 Website | chưa | — | |

## Số đo
(engine µs/phím, chi phí selectedRange theo app, độ trễ p50/p99 dưới tải, bộ nhớ…)

## Nhật ký
(ngày — việc — agent — kết quả — commit)
- 29/10/2026 — người dùng duyệt đề xuất khởi động: ranh giới từ (D4, D21), D26 gõ đúp phím dấu, D27 bỏ `[` `]`, ô trống cho nhãn web editor (UI.md, N5), đưa D18 về đúng thứ tự — phiên chính — xong
