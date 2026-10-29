# Lộ trình

Mỗi mốc kết thúc khi: test xanh, đã tự rà soát với `DECISIONS.md`, và có tóm tắt ngắn (đã làm, số đo, câu hỏi còn mở).

## M0 — Khung dự án
- `git init`, `.gitignore`, `LICENSE` (GPLv3), `README.md` ngắn.
- `project.yml` (XcodeGen) với 2 target app (`Dau`, `DauInputMethod`) + 2 package local (`DauEngine`, `DauShared`). Bundle ID và Team ID để placeholder, hỏi người dùng.
- Xong khi: `xcodegen generate` và build Debug thành công cho cả hai target, universal.

## M1 — Engine
- Trước khi viết engine: đọc mã nguồn OpenKey (clone ngoài repo) và lập `docs/OPENKEY-NOTES.md` — danh sách đầy đủ tính năng của engine, hành vi từng tính năng, ca biên, lỗi tìm thấy, và Dấu làm hay không làm (dẫn D-số). Đối chiếu với `DECISIONS.md`; mâu thuẫn mới thì nêu ra trước khi code.
- `VietEngine` cho Telex (trước), rồi VNI và Telex đơn giản; đặt dấu mới/cũ; bỏ dấu tự do; chính tả âm tiết; tự khôi phục từ không phải tiếng Việt; gõ đúp phím dấu để giữ chữ gốc.
- Bộ test: (1) ca viết tay cho các quy tắc khó (ươ, uyê, gi/qu, đ, dấu trên nguyên âm đôi) và nhóm từ trùng Anh–Việt (car/cả, sex/sẽ, has/há, test/tét, as/á) kèm cách gõ đúp; tương tác gõ tắt phụ âm với khôi phục (fan → phan, big → big, bag → bang, wa → ưa); (2) ca biên rút ra từ `OPENKEY-NOTES.md`, kết quả mong đợi viết theo quy tắc chính tả và `DECISIONS.md`; (3) test hiệu năng.
- Xong khi: toàn bộ test xanh; số đo thời gian `handle` mỗi phím được ghi lại.

## M2 — Bộ gõ tối thiểu
- `DauInputMethod` với Telex, chế độ Tiếng Việt/Tiếng Anh, thay chữ tại chỗ.
- Script cài bản Debug vào `~/Library/Input Methods` và hướng dẫn người dùng bật thử.
- **Giải quyết câu hỏi mở A/B** (vị trí thay chữ): đo chi phí `selectedRange` trên TextEdit, Safari, Chrome, Slack, VS Code, Terminal; cập nhật `DECISIONS.md`.
- Xong khi: người dùng gõ được tiếng Việt trong TextEdit và Safari không gạch chân.

## M3 — Độ tin cậy
- Reset khi lệch ngữ cảnh, phòng thủ đầu vào IMK (D18), fallback marked text theo danh sách tương thích (D13), quy tắc theo ứng dụng (D5), thông báo VoiceOver (D17).
- Ma trận tương thích: bảng app × kết quả, lưu trong `docs/COMPATIBILITY.md`.

## M4 — App Cài đặt
- Dựng 4 mục theo `docs/UI.md`, App Group chia sẻ cài đặt, bộ gõ áp dụng thay đổi ngay.

## M5 — Onboarding, cài đặt, gỡ cài đặt
- 3 bước theo `docs/UI.md`; phát hiện bộ gõ cũ; cài/gỡ bộ gõ; xác minh câu hỏi mở về `TISEnableInputSource` và sandbox của app chủ.

## M6 — Hiệu năng dưới tải
- App test tự gửi phím 20 phím/giây vào TextEdit, Safari, Slack trong khi CPU đầy và `memory_pressure` đang chạy.
- Chỉ số: văn bản cuối khớp 100%; độ trễ p50/p99 phía bộ gõ; bộ nhớ ổn định theo thời gian. So với gõ bằng ABC và với OpenKey.
- Chốt ngưỡng vào `DECISIONS.md`; quyết định về D12 dựa trên số đo.

## M7 — Phát hành
- Ký Developer ID, notarize, DMG; Sparkle 2 (EdDSA, 2 kênh, phát hành theo đợt); JSON tương thích có chữ ký; GitHub Actions build từ tag + artifact attestation; Homebrew cask với `auto_updates true`.
- Báo lỗi (URL issue điền sẵn), Quay về bản trước, Gỡ cài đặt.
- Xuất bộ file nhận diện theo `docs/BRAND.md` (biểu tượng app, ảnh template thanh menu, favicon, ảnh Open Graph, ảnh xem trước GitHub, nền DMG) và gắn thẻ meta cho website.
- Việc cần tài khoản Apple Developer: chuẩn bị sẵn, dừng lại để người dùng thực hiện.

## M8 — Website
- Dựng trang tải về theo `docs/UI.md` (mục "Trang tải về") và `docs/BRAND.md`: trang tĩnh, responsive, thẻ meta và ảnh Open Graph, favicon. Công nghệ chọn ở đầu mốc và hỏi người dùng.
- Các ô số liệu và lời hứa chỉ điền từ kết quả M2/M6 (N5).
- Xong khi: Lighthouse ≥ 95 ở cả bốn hạng mục trên điện thoại; kiểm toán ĐẠT.
