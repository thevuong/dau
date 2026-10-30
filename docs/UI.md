# Giao diện

Mockup gốc: https://claude.ai/artifact/B2xhNxL3voGwTkXkFV72Ln — xem trực tiếp canvas để đối chiếu bố cục và các trạng thái; nếu phiên làm việc không mở được link thì mô tả dưới đây đủ để dựng. Mockup vẽ theo macOS 27, nhưng app thật dùng control SwiftUI hệ thống nên tự theo phiên bản macOS đang chạy (D9). Chuỗi giao diện tiếng Việt, đặt trong String Catalog. Khi canvas và tài liệu này lệch nhau, `DECISIONS.md` quyết định; sửa bên sai cho khớp.

## Menu nguồn nhập liệu (hệ thống vẽ)
Không có status item riêng. Dấu có một input mode (D2): menu của hệ thống liệt kê "Dấu – Tiếng Việt" cùng các nguồn khác của người dùng (ví dụ "ABC" để gõ tiếng Anh); bộ gõ bổ sung qua `menu()` của IMK: nhóm "Kiểu gõ" (Telex ✓ / VNI / Telex đơn giản), "Cài đặt Dấu…", "Mở cài đặt Bàn phím…". Không icon trên từng mục.

## Onboarding (một cửa sổ, thanh bước bên trái)
Sidebar: icon app, tên, 3 bước có trạng thái (xong / đang làm / chưa), dòng về quyền cần cấp (để ô trống, điền sau khi kiểm chứng ở M2)
1. **Tắt bộ gõ cũ trước đã** — chỉ hiện khi phát hiện bộ gõ chặn phím khác đang chạy (OpenKey, EVKey, GoTiengViet, XKey, PHTV, Gõ Nhanh, GoKey; bundle ID trong `docs/research/M5-INSTALL.md` mục 5). Các bước tắt chỉ ghi tên menu đã kiểm chứng; app chưa kiểm thì ghi chung "Thoát <tên>" và đường dẫn Mục đăng nhập (N5). Thẻ app (vd. OpenKey, nhãn "Đang chạy") kèm hướng dẫn tắt ngay tại chỗ (thoát app, tắt trong Mục đăng nhập). Tự kiểm tra lại khi cửa sổ được kích hoạt. Nút: Bỏ qua / Kiểm tra lại.
2. **Bật Dấu** — chép bộ gõ vào `~/Library/Input Methods`, đăng ký, và chỉ khi người dùng bấm "Bật Dấu" mới bật nguồn nhập liệu; có Hoàn tác (N4, D37). Kết quả đọc lại từ hệ thống, không báo thành công khi chưa thấy bật (N5): macOS vẫn để tắt → mở Cài đặt Bàn phím và hiện các bước tự thêm "Dấu – Tiếng Việt"; macOS chưa liệt kê Dấu (lần cài đầu) → hướng dẫn đăng xuất rồi đăng nhập lại một lần. Có nguồn tiếng Việt kiểu IMK khác đang bật (ví dụ Telex của Apple) thì chỉ nhắc nhẹ dưới thẻ, không chặn (D14).
3. **Chọn kiểu gõ và gõ thử** — segmented Telex | VNI | Telex đơn giản, ô gõ thử, gợi ý "tooi yeeu tieengs Vieetj". Nút: Quay lại / Bắt đầu gõ.

## Cửa sổ Cài đặt (sidebar + ô tìm kiếm)
Sidebar có icon màu: Gõ phím (xanh dương), Thông minh (tím), Ứng dụng (cam), Cập nhật & hỗ trợ (xanh lá). Thanh tiêu đề hiện tên mục.

**Gõ phím**
- Thẻ "Xem trước": chuỗi gõ → kết quả, cập nhật ngay theo kiểu gõ và vị trí dấu; chip hiện cấu hình hiện tại.
- Kiểu gõ: segmented 3 lựa chọn. Vị trí dấu thanh: segmented Kiểu mới | Kiểu cũ (gợi ý "hoà, thuý · hòa, thúy"). Bỏ dấu tự do: công tắc.
- Chuyển Tiếng Việt ↔ Tiếng Anh: là chuyển nguồn nhập liệu (Dấu ↔ ABC/U.S.…); hàng "Phím tắt nguồn nhập liệu" hiện phím tắt hệ thống hiện tại dạng keycap, nút "Đổi…" mở Cài đặt Bàn phím (N4). Không có phím chuyển riêng (D2).

**Thông minh**
- Gõ lẫn từ nước ngoài: một công tắc "Tự khôi phục từ không phải tiếng Việt" (khi kết thúc từ, từ không phải âm tiết tiếng Việt hợp lệ trở về đúng như đã gõ); ví dụ windows → windows, Sunrise → Sunrise, vieetj → việt; ghi chú: từ trùng thì tiếng Việt thắng (car → cả), gõ đúp phím dấu để giữ chữ gốc (carr → car).
- Sửa từ đã gõ: "Thêm dấu cho từ đã gõ", nhãn "Mới", ghi chú "Đặt con trỏ ngay sau từ rồi gõ phím dấu. Không áp dụng ở ứng dụng có quy tắc “Có gạch chân”." (phạm vi D20) rồi ô trống về độ ổn định trên web editor `[Kết quả kiểm chứng trên Google Docs, Notion…]` cho tới khi đo (N5, câu hỏi mở trong DECISIONS.md); ví dụ hoc + j → học. Lưu ý: "dep" + j ra "dẹp", không phải "đẹp" — ví dụ phải đúng quy tắc Telex.
- "Nâng cao" thu gọn (có artboard trạng thái mở): "Gõ tắt phụ âm" — đầu từ f → ph, j → gi (VNI thêm w → qu), cuối từ g → ng, h → nh, k → ch, áp dụng khi kết thúc từ và chỉ khi ra từ hợp lệ (D21, D23); "Cho phép phụ âm z, f, w, j" — ghi chú "Bật mục này sẽ tắt Gõ tắt phụ âm" (D22); khi kiểu gõ là Telex, thêm ghi chú w luôn thành ư nên mục này chỉ tác dụng với z, f, j (D22, D23). Cả hai mặc định tắt. Tóm tắt bên phải tiêu đề: "2 tuỳ chọn, đang tắt".

**Ứng dụng**
- Thanh tiêu đề: ô tìm ứng dụng, nút +.
- "Việt/Anh theo cửa sổ": một hàng "Nhớ nguồn nhập liệu theo từng cửa sổ", gợi ý "Tuỳ chọn “Tự động chuyển sang nguồn đầu vào của tài liệu” của macOS", bên phải chữ trạng thái "Đang bật"/"Đang tắt" (đọc, không ghi, từ cài đặt hệ thống; không đọc được thì không hiện chữ, N5) và nút "Đổi…" mở Cài đặt Bàn phím (D5, N4).
- "Quy tắc riêng": chỉ các quy tắc đã lưu (người dùng tự thêm, hoặc đề xuất đã bật). Mỗi hàng: icon app, tên, nhãn "Đề xuất" nếu đến từ danh sách tương thích, một popup "Không gạch chân/Có gạch chân" (D5, D13); xoá bằng menu chuột phải hoặc phím Delete. Đặt về "Không gạch chân" vẫn giữ quy tắc; xoá quy tắc thì app đề xuất trở lại mục "Đề xuất". Không có quy tắc thì hiện "Chưa có quy tắc riêng. Bấm + để thêm." Mục này không có ghi chú.
- "Đề xuất": chỉ hiện khi có ít nhất một app trong danh sách tương thích (cờ `suggestUnderline`) đã cài trên máy mà chưa có quy tắc. Mỗi hàng: icon app (28), tên, dòng phụ "Có thể sai chữ khi gõ rất nhanh" (giống mọi hàng; ghi chú trong danh sách là cho người bảo trì, không hiện, N5), nút "Bật gạch chân" (nút hệ thống như "Đổi…"; VoiceOver đọc "Bật gạch chân cho <tên app>"). Bấm nút mới lưu quy tắc "Có gạch chân" nguồn đề xuất, app chuyển lên "Quy tắc riêng"; trước đó không lưu gì (mặc định không gạch chân, D13). App chưa cài không hiện. Ô tìm lọc cả hai mục. Ghi chú dưới mục (người dùng duyệt 30/10/2026; M3 đã đo, D13: thay tại chỗ chỉ sai khi phím cách nhau dưới 10 ms; gạch chân sửa được Chrome, VS Code nhưng không sửa được Terminal, nên chỉ nói khi nào chọn, không hứa sửa được): "“Đề xuất” đến từ danh sách tương thích: app có thể sai chữ khi gõ rất nhanh. Chỉ chọn “Có gạch chân” khi một app bị lỗi chữ lúc gõ."

**Cập nhật & hỗ trợ**
- Thẻ đầu: icon app, phiên bản, trạng thái kiểm tra, nút "Kiểm tra ngay".
- Cập nhật: tự kiểm tra, tự tải và cài (cài lúc không gõ), kênh Ổn định | Beta.
- Hỗ trợ: Báo lỗi…, Quay về…, Gỡ cài đặt… (màu đỏ).
- Chú thích quyền riêng tư (giữ đúng nội dung): "Dấu không gửi chữ bạn gõ ra khỏi máy. Bộ gõ không có quyền truy cập mạng; chỉ phần cập nhật kết nối để tải bản mới và danh sách ứng dụng tương thích. Mã nguồn mở theo giấy phép GPLv3."

## Các trạng thái bổ sung
- **Dấu chưa được bật** (người dùng gỡ khỏi Nguồn nhập liệu): banner màu cam đầu mọi mục Cài đặt, "Bạn vẫn chỉnh được cài đặt, nhưng chưa gõ được tiếng Việt.", nút "Bật lại". Bấm "Bật lại" thì bật Dấu và đọc lại trạng thái (N4): bật được → banner xanh "Đã bật Dấu trong Nguồn nhập liệu" kèm nút "Hoàn tác"; macOS vẫn để tắt → mở Cài đặt Bàn phím, banner hiện các bước tự thêm; chưa cài hoặc macOS chưa liệt kê Dấu → mở cửa sổ thiết lập.
- **Chế độ tối:** toàn bộ Cài đặt và onboarding phải có giao diện tối (dùng màu hệ thống của SwiftUI là tự có).
- **Thêm quy tắc ứng dụng** (nút +): sheet với ô tìm, danh sách ứng dụng chưa có quy tắc đã lưu (app trong danh sách tương thích có nhãn "Đề xuất" và khi thêm thì giữ nhãn đó), một segmented "Khi đang gõ" (Không gạch chân | Có gạch chân), nút Huỷ / Thêm.
- **Thẻ cập nhật** có 6 trạng thái: đã mới nhất; đang kiểm tra; đang tải (thanh tiến trình, "Bạn vẫn gõ bình thường", nút Huỷ); chờ cài ("Sẽ cài khi bạn ngừng gõ", nút Cài ngay); không có mạng (nút Thử lại, "Dấu vẫn gõ bình thường"); chữ ký không hợp lệ ("Đã huỷ bản cập nhật", nút Báo lỗi…).
- **Xác nhận quay về bản trước** (D19) và **xác nhận gỡ cài đặt** (alert hệ thống: "Gỡ Dấu khỏi máy?", nút đỏ "Gỡ cài đặt", "Huỷ", checkbox "Xoá cả cài đặt và quy tắc ứng dụng"). Câu "Bàn phím đang dùng trước đó được giữ nguyên" để ô trống `[…]` cho tới khi M5 T4 kiểm chứng (N5). macOS 27 vẽ alert căn trái, hai nút nằm ngang, nút "Gỡ cài đặt" chữ đỏ trên nền đỏ nhạt; mockup vẽ căn giữa, nút xếp dọc, nền đỏ chữ trắng — theo hệ thống (D9). Gỡ xong: alert "Đã gỡ bộ gõ Dấu" nêu những gì đã làm (đọc lại từ hệ thống) và nút "Thoát Dấu"; app không tự xoá chính nó, chỉ hướng dẫn kéo Dấu vào Thùng rác.
- **Khi gõ trong ứng dụng:** không gạch chân (mặc định), có gạch chân (từ đang gõ được gạch, chốt khi Space), gõ tiếng Anh bằng ABC (chỉ báo của hệ thống), thêm dấu cho từ đã gõ.
- **Onboarding bước 2:** giải thích sẽ thấy biểu tượng V, và chuyển sang ABC để gõ tiếng Anh bằng phím tắt nguồn nhập liệu của macOS: hiện **phím tắt thật** đọc từ cài đặt hệ thống dạng keycap (không viết cứng phím nào, N5); chưa đặt phím tắt thì nói vậy và có nút mở Cài đặt Bàn phím; không đọc được thì keycap trống kèm nút đó. Chỗ dành cho hướng dẫn nếu macOS yêu cầu xác nhận (hộp thoại "Cho phép … bật …?", kiểm chứng ở M5 T4).

## Thông báo cập nhật (alert nhỏ, căn giữa)
Icon app, "Đã có Dấu x.y.z", mô tả (cài lúc không gõ, quay về được), "Có gì mới", dòng "Đã xác minh chữ ký số của bản cập nhật", checkbox "Tự động cài các bản sau", nút xếp dọc: Cài đặt / Nhắc sau / Bỏ qua bản này.

## Báo ứng dụng gõ lỗi (sheet)
Ứng dụng (tự điền), Trang web (không bắt buộc), Loại lỗi (segmented: Mất chữ | Lặp chữ | Sai dấu | Khác), Ví dụ đã gõ; mục "Gửi kèm" liệt kê phiên bản macOS, Dấu, kiểu gõ, phiên bản app — và câu "Không gửi nội dung bạn đã gõ." Ghi rõ issue GitHub là công khai. Nút: Huỷ / Sao chép nội dung / Mở trên GitHub (URL issue điền sẵn, không có backend).

## Trang tải về (web)
Phông Be Vietnam Pro, nền Giấy, màu nhấn Mực (D25, `docs/BRAND.md`). Một mã nguồn responsive cho cả máy tính và điện thoại (hai artboard trên canvas). Thứ tự mục:
1. **Thanh điều hướng:** logo, Tính năng / Bảng gõ / Hỏi đáp / GitHub (ẩn trên điện thoại), nút "Tải về".
2. **Hero:** dòng nhỏ chứa cụm "Bộ gõ tiếng Việt cho macOS" (cho tìm kiếm), tiêu đề "Gõ tiếng Việt như thể macOS vốn đã làm vậy.", nút "Tải cho macOS" + "Xem mã nguồn", dòng yêu cầu hệ thống. Bên phải: **hoạt ảnh phát lại** chuỗi phím "tooi yeeu tieengs Vieetj" ra "tôi yêu tiếng Việt" kèm phím vừa gõ — chỉ là hoạt ảnh CSS dựng sẵn, không phải engine chạy trên web (quyết định đã loại bỏ thử gõ trên web). Tắt hoạt ảnh khi người dùng bật giảm chuyển động (`prefers-reduced-motion`).
3. **Vì sao lại thêm một bộ gõ:** 3 cột so sánh theo **loại** bộ gõ (bộ gõ có sẵn: gạch chân; bộ gõ chặn phím rồi gõ lại: có thể nhảy chữ, thường cần quyền Trợ năng; Dấu: thay chữ tại chỗ). Không gọi tên sản phẩm khác. Phạm vi ứng dụng của Dấu để ô trống tới M2 (N5).
4. **Tính năng:** 4 thẻ 2×2 có minh hoạ — giữ nguyên từ nước ngoài, thêm dấu cho từ đã gõ, theo từng ứng dụng, như một phần của macOS.
5. **Bảng gõ Telex/VNI:** bảng thật (`<table>`), cột "Tên" ẩn trên điện thoại.
6. **Quyền riêng tư:** nền Mực, 3 cam kết (giữ đúng nội dung D8/N2).
7. **Đo được:** 4 ô số liệu để trống, chỉ điền từ kết quả test thật (N5).
8. **Tải về:** phiên bản, ngày, dung lượng, yêu cầu hệ thống, nút "Tải DMG", "Lịch sử phiên bản", lệnh Homebrew (tên cask chưa chốt, D24), SHA-256. Phát hiện nền tảng: nếu không phải Mac thì nút chính đổi thành "Sao chép liên kết" kèm câu "Dấu chỉ chạy trên Mac" (không có backend gửi email, D8).
9. **Hỏi đáp:** 6 câu dạng `<details>` (miễn phí, thu thập dữ liệu, quyền cần cấp [chờ M2], khác bộ gõ có sẵn, chuyển từ bộ gõ khác, gỡ cài đặt).
10. **Chân trang:** nền Than, logo có viền, liên kết mã nguồn, báo lỗi, lịch sử phiên bản, hướng dẫn gỡ, ủng hộ.

Không dùng logo Apple trên nút tải (nhãn hiệu của Apple); dùng biểu tượng mũi tên tải xuống.
