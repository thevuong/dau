# Thử M4 trên máy thật

Mục tiêu: kiểm chứng app Cài đặt và bộ gõ dùng chung cài đặt (App Group), quy tắc theo ứng dụng (D5), và ngôn ngữ của app chủ. Ghi kết quả vào cột trống rồi gửi lại.

## Chuẩn bị
1. Cài lại bản Debug: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/install-debug.sh`.
2. Mở Console.app, lọc subsystem `com.example.dau.inputmethod.Dau`, category `settings` và `perf`.
3. Chạy app chủ bản Debug (`Dau.app` trong thư mục build mà script in ra).

Lưu ý: kiểu gõ đã chọn ở M2 không được chuyển sang cài đặt mới, nên bộ gõ quay về Telex.

## Các bước

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| 1 | Gõ một phím trong TextEdit, xem Console | Có dòng `store=appGroup` (hoặc `store=standard reason=no-app-group`); **không** có hộp thoại hệ thống xin quyền truy cập dữ liệu. Có hộp thoại thì chụp lại | |
| 2 | Trong app Dấu: Kiểu gõ → VNI; quay lại TextEdit gõ `Vie65t` | Ra "Việt", không cần đổi app/cửa sổ | |
| 3 | Vị trí dấu → Kiểu cũ; gõ `hoaf` (Telex) | Ra "hòa" | |
| 4 | Chọn VNI trong menu nguồn nhập liệu của Dấu, rồi mở app Dấu | Mục Kiểu gõ hiện VNI | |
| 5 | Thêm quy tắc Terminal = Tiếng Anh. Từ TextEdit (chế độ Việt) chuyển sang Terminal | Biểu tượng đổi sang E, gõ ra chữ Anh | |
| 6 | Trong Terminal đổi về Việt, mở tab mới | Vẫn chế độ Việt (cùng app) | |
| 7 | Sang app khác rồi quay lại Terminal | Về E (quy tắc riêng luôn áp dụng) | |
| 8 | Console trong bước 5–7 | Không có `start-mode-en` / `mode-en` lặp liên tục | |
| 9 | Bật "Nhớ chế độ theo từng ứng dụng". Safari chọn Tiếng Anh, Notes chọn Tiếng Việt, quay lại Safari | Safari về Tiếng Anh | |
| 10 | Thêm quy tắc có gạch chân cho TextEdit, chuyển sang TextEdit | Console có `event=underline-rule-ignored`; gõ như cũ (gạch chân làm ở M3) | |
| 11 | Máy để tiếng Anh: mở app Dấu | Menu của app (Ẩn/Thoát, Sửa, Cửa sổ) và hộp thoại chọn ứng dụng hiện tiếng Việt; Finder vẫn hiện tên "Dấu" | |
| 12 | Chế độ tối | Cài đặt và các sheet đọc rõ | |
| 13 | Bật VoiceOver, đi qua cửa sổ Cài đặt; bật "Điều hướng bàn phím" của macOS rồi dùng Tab | Mọi control được đọc tên; Tab đi hết control | |
