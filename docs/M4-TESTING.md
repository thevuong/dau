# Thử M4 trên máy thật

Mục tiêu: kiểm chứng app Cài đặt và bộ gõ dùng chung cài đặt (App Group), quy tắc theo ứng dụng (D5: chỉ còn lựa chọn gạch chân), và ngôn ngữ của app chủ. Ghi kết quả vào cột trống rồi gửi lại.

## Chuẩn bị
1. Cài lại bản Debug: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/install-debug.sh`.
2. Mở Console.app, lọc subsystem `com.example.dau.inputmethod.Dau`, category `settings` và `perf`.
3. Chạy app chủ bản Debug (`Dau.app` trong thư mục build mà script in ra).

Lưu ý: kiểu gõ đã chọn ở M2 không được chuyển sang cài đặt mới, nên bộ gõ quay về Telex.

## Các bước

Kết quả (30/10/2026): agent tự thao tác trên máy, trừ chỗ ghi khác. 5, 6, 8 ĐẠT; 7 không áp dụng trên máy này. Hoãn sang M7 (kiểm tra trước phát hành, cần người): 9 phần máy để tiếng Anh hẳn, 10 phần các sheet ở chế độ tối, 11 (VoiceOver, Tab).

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| 1 | Gõ một phím trong TextEdit, xem Console | Có dòng `store=appGroup` (hoặc `store=standard reason=no-app-group`); **không** có hộp thoại hệ thống xin quyền truy cập dữ liệu. Có hộp thoại thì chụp lại | ĐẠT (30/10): `store=appGroup`, không có hộp thoại; `scripts/selftest-app-group.sh` PASS |
| 2 | Trong app Dấu: Kiểu gõ → VNI; quay lại TextEdit gõ `Vie65t` | Ra "Việt", không cần đổi app/cửa sổ | ĐẠT (30/10): đặt VNI trong app, gõ `Vie65t` trong TextEdit ra "Việt" |
| 3 | Vị trí dấu → Kiểu cũ; gõ `hoaf` (Telex) | Ra "hòa" | ĐẠT: `hoaf` → "hòa" |
| 4 | Chọn VNI trong menu nguồn nhập liệu của Dấu, rồi mở app Dấu | Mục Kiểu gõ hiện VNI | ĐẠT, cả khi app đang mở lẫn khi mở app lần đầu |
| 5 | Thêm quy tắc cho Terminal (không gạch chân). Chuyển qua lại TextEdit ↔ Terminal, gõ `tooi` ở mỗi app | Nguồn nhập liệu không tự đổi (vẫn "Dấu – Tiếng Việt", biểu tượng V); ra "tôi" ở cả hai (D5: Dấu không đổi Việt/Anh theo app) | ĐẠT (30/10, agent tự gõ): nguồn giữ `Dau.vi`; Terminal ra "tôi", TextEdit ra "Tôi tôi" (TextEdit tự viết hoa); log chỉ có `activate` |
| 6 | Trang Ứng dụng của app Dấu | Mỗi quy tắc chỉ có lựa chọn gạch chân; không có chế độ khi mở app, không có "Nhớ chế độ theo từng ứng dụng"; có chỉ dẫn tới tuỳ chọn macOS "Tự động chuyển sang nguồn đầu vào của tài liệu" (D5) | ĐẠT (30/10): mỗi quy tắc chỉ có popup gạch chân; dòng "Nhớ nguồn nhập liệu theo từng cửa sổ" hiện "Đang bật" khớp cài đặt thật; "Đổi…" mở Cài đặt Bàn phím, giá trị không đổi |
| 7 | (Chỉ máy đã chạy bản trước 30/10/2026) Mở trang Ứng dụng | Các quy tắc tạo ở bản cũ vẫn còn, giữ nguyên lựa chọn gạch chân; app không báo lỗi đọc cài đặt (D18) | Không áp dụng trên máy này (không còn quy tắc của bản cũ); đọc cài đặt cũ có unit test `legacyModeKeys` |
| 8 | Thêm quy tắc cho TextEdit, chọn "Có gạch chân" ở popup của quy tắc | Không chọn được (N5, gạch chân làm ở M3): popup về lại "Không gạch chân", giá trị lưu vẫn là không gạch chân | ĐẠT (30/10, sau sửa ở b23b266): popup về lại "Không gạch chân", không có `settings-reloaded` hay `underline-rule-ignored`, gõ như cũ |
| 9 | Máy để tiếng Anh: mở app Dấu | Menu của app (Ẩn/Thoát, Sửa, Cửa sổ) và hộp thoại chọn ứng dụng hiện tiếng Việt; Finder vẫn hiện tên "Dấu" | Máy en-VN: ĐẠT, menu của app tiếng Việt; hộp thoại "Chọn ứng dụng khác…" mở được sau khi sửa ở 4fdd7ea, thử lại ĐẠT. Máy để tiếng Anh hẳn và tên trong Finder: cần người |
| 10 | Chế độ tối | Cài đặt và các sheet đọc rõ | Một phần: 4 mục Cài đặt đọc rõ (ma trận cửa sổ thật); các sheet chưa xem |
| 11 | Bật VoiceOver, đi qua cửa sổ Cài đặt; bật "Điều hướng bàn phím" của macOS rồi dùng Tab | Mọi control được đọc tên; Tab đi hết control | Cần người |
