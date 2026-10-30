# Kiểm tra giao diện

Danh sách phải chạy hết trước khi báo xong bất kỳ thay đổi giao diện nào của app Dấu. Mỗi mục là một lỗi người dùng đã gặp ở M4, kèm cách kiểm và chỉ số đạt.

## Lệnh

1. Build Debug:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Dau.xcodeproj -scheme Dau -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData build`
2. Kiểm cửa sổ thật:
   `scripts/check-settings-window/run.sh <thư-mục-ra>`
   - Chép bản Debug và ký lại không sandbox để được ghi ảnh. Chạy `Dau --capture-window` với mọi tổ hợp: thanh cuộn {overlay `WhenScrolling`, `Always`, `Automatic`} × cuộn {0, 60 pt}. Mỗi lần chụp 4 mục × {sáng, tối}.
   - Ảnh lấy từ window server nên có material, vibrancy và hiệu ứng mép cuộn.
   - Kiểm (a)–(e) bên dưới. Ghi `matrix-grid.png` (mỗi hàng một tổ hợp). Thoát với mã 0 chỉ khi mọi kiểm tra đạt.
   - Cửa sổ được đưa ra ngoài màn hình nhưng vẫn tồn tại vài giây mỗi lần chạy.
   - Chụp thêm cửa sổ onboarding (`Dau --capture-onboarding <thư-mục>`, dịch vụ giả: OpenKey đang chạy, Dấu đã cài chưa bật): bước 1, 2, 2 sau "Bật Dấu", 3 × {sáng, tối} vào `onboarding/`, và một lượt `--shortcut none` vào `onboarding-no-shortcut/`; kèm `onboarding-<bước>-accessibility.txt` (cây trợ năng đọc qua AX API, cần quyền Trợ năng của Terminal). Kiểm (f).
3. So với mockup:
   `swift run --package-path scripts/snapshot-settings SnapshotSettings <ra> <thư-mục-artboard> [<thư-mục-chụp-thật>]`
   - Ghi ảnh ghép mockup | app (`*-compare-*.png`, sidebar 4×, segmented 3×, header Ứng dụng 3×) và bảng khung phần tử.
   - Thêm đối số thứ tư `<thư-mục-chụp-onboarding>` (vd. `<ra-run.sh>/onboarding`): ghi `onboarding-<bước>-compare-{light,dark}.png` so với artboard OnboardingConflict, OnboardingEnable, Onboarding (không có artboard tối: mockup sáng cạnh app tối).
   - Kiểm khung 4 mục trong cửa sổ dựng tay: in "Layout: identical in all sections", thoát 1 nếu lệch.
4. Test: `swift test --package-path scripts/snapshot-settings` (ví dụ do engine tính, phím tắt, ô tìm sidebar).

Toạ độ tính bằng pt, gốc ở góc trên-trái cửa sổ 820×600.

## Danh sách

| # | Lỗi đã gặp | Cách kiểm | Đạt khi |
|---|---|---|---|
| 1 | Nội dung co thành cột hẹp, căn giữa (do `Form(.grouped)`) | run.sh, khung `content`, `firstCard` | `content` x 220, rộng = độ rộng cột (600 với thanh cuộn overlay); `firstCard` x 248 |
| 2 | Nhảy bố cục khi đổi mục (toolbar đổi cao, tiêu đề đổi chỗ) | run.sh (a); snapshot-settings "Layout" | (a) x, y của `content`, `title`, `close` và x của `firstCard` bằng nhau ở 4 mục, lệch 0 pt. Độ rộng của `content` và `firstCard` chỉ được lệch đúng bằng độ rộng thanh cuộn legacy của hệ thống (`NSScroller.scrollerWidth`, 17 pt), và chỉ ở mục đang hiện thanh cuộn (clip view hẹp hơn scroll view). Tọa độ y của `firstCard` không so, vì phụ thuộc mục có tiêu đề nhóm đầu trang hay không. |
| 3 | Màu không theo HIG (tự pha nền, chữ cố định) | `grep -nE "Color\(red\|#[0-9a-fA-F]{6}\|\.opacity\(\|gradient\|blended" Apps/Dau/Sources` | Không có kết quả (D9: chỉ màu hệ thống, kể cả ô icon sidebar) |
| 4 | Mất đèn giao thông | run.sh (e) | `close` = 19,19 14×14 ở mọi ảnh |
| 5 | Icon sidebar sai (glyph, màu, cỡ, sát chữ) | `sidebar-compare-*.png`; khung `sidebarRow-*` | Ô 22, bo 6, màu `systemBlue` / `systemPurple` / `systemOrange` / `systemGreen`, glyph nét trắng theo SVG mockup; hàng cao 24 + 8 của list (vệt chọn 32), cách nhau 32 |
| 6 | Segmented "Kiểu gõ" hẹp, căn giữa | khung `segmented` (frames.json) | x 264, rộng 512 (trải hết card trừ 16 mỗi bên) |
| 7 | Ô tìm và "+" dính nhau thành một khối glass | run.sh (e); `apps-header-compare-*.png` | `headerSearch` rộng 200, bắt đầu sau tiêu đề ít nhất 40 pt (toạ độ tuyệt đối đổi theo bản macOS: 27.0 x 556, 27.2 x 548); `headerAdd` bắt đầu sau mép phải ô tìm ít nhất 8 pt |
| 8 | Nút "+" méo (bầu dục) | `apps-header-compare-*.png` | Viền nút tròn: rộng bằng cao, đo trên ảnh |
| 9 | Header không che nội dung khi cuộn | run.sh (d), cuộn 60 pt | Vùng header (x 390–540, y 6–46) khác ảnh chưa cuộn trung bình ≤ 4/255 |
| 10 | Thiếu thanh cuộn (nằm ngoài cửa sổ) | run.sh (b), (d); khung `scroller` | Mục có cuộn: `scroller` x ≥ 700, mép phải ≤ 820, y ≥ 51 |
| 11 | Dải hở ở mép phải (cột thanh cuộn chừa sẵn) | run.sh (b), (c) | (b) màu nền trang ở mép phải (hoặc sát trái thanh cuộn) trùng màu nền trang bên trái, lệch ≤ 6/255; vạch dưới header có ở x 600 và x 817 cùng hàng. (c) dải 24 pt ở mép phải không có điểm nào khác màu nền trang, trừ thanh cuộn |
| 12 | Onboarding lệch mockup | run.sh (f) | Cửa sổ 720×500; tên app x 20 y 50; tiêu đề x 266 y 40; thẻ x 266 rộng 418; cụm nút mép phải 684, mép dưới 472 — ở mọi bước, cả hai chế độ |

## Quy tắc thanh cuộn (chốt 29/10/2026)

Hệ thống quyết định cách hiện thanh cuộn.

- **Overlay:** không chiếm chỗ.
- **Legacy** (`Always`, hoặc `Automatic` khi có chuột): chỉ mục thực sự cần cuộn mới có rãnh thanh cuộn ở mép phải, và mục đó hẹp hơn đúng 17 pt. Vị trí x, y của mọi thứ giữ nguyên.
- Không chừa sẵn khoảng trống cho thanh cuộn: cách đó sinh lỗi 11.
