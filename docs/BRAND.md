# Nhận diện thương hiệu

Mockup: các artboard "Nhận diện – …", "Ảnh chia sẻ Open Graph" và "Ảnh xem trước GitHub" trên canvas (link trong `docs/UI.md`). Quyết định gốc: D24 (tên), D25 (nhận diện).

## Biểu tượng
- Chữ "ấ" màu Giấy trên nền Mực; dấu mũ cùng màu chữ, **riêng dấu sắc màu Son** — biểu tượng tự kể tên sản phẩm.
- Bản thật dựng bằng Icon Composer của Apple (một file nguồn, đủ các kiểu Mặc định / Tối / Trong suốt / Phủ màu trên macOS 26+); xuất thêm `.icns` cho macOS 14–15.
- Chữ "a" trong biểu tượng phải chuyển thành đường nét (outline) trong file nguồn, không phụ thuộc phông khi render.
- Ở 16–32 pt tăng độ dày nét dấu để vẫn đọc ra "ấ"; kiểm tra bằng mắt ở từng cỡ.
- Trên nền tối hoặc nền Mực: thêm viền mảnh màu Giấy ~35% để tách biểu tượng khỏi nền.

## Biểu tượng thanh menu (input mode)
- Một ảnh template đơn sắc "V" (Tiếng Việt) có khung viền, để macOS tự tô màu theo nền. Không dùng màu thương hiệu (D9). Dấu chỉ có một input mode (D2); khi gõ tiếng Anh bằng ABC/U.S., biểu tượng là của hệ thống.

## Logo chữ
- "Dấu" viết bằng Be Vietnam Pro ExtraBold, **một màu**. Không tách dấu sắc ra tô màu riêng: lệch một chút là thành "Dâu".
- Không bao giờ viết "Dau"/"dau" trước người dùng (D24).

## Màu
| Tên | Mã | Dùng cho |
|---|---|---|
| Mực | `#10285A` | nền biểu tượng, nền ảnh chia sẻ, màu nhấn trên website |
| Son | `#E0533D` | chỉ dấu sắc trong biểu tượng — không dùng cho nút, chữ, nền |
| Giấy | `#F6F1E7` | chữ trên nền Mực, nền website |
| Than | `#1D1D1F` | chữ chính |

App dùng màu và phông của hệ thống (D9); bảng màu này dành cho biểu tượng, website, ảnh chia sẻ, tài liệu.

## Chữ
- Be Vietnam Pro (giấy phép OFL) cho logo, website, ảnh chia sẻ. Không dùng SF Pro ngoài giao diện app vì giấy phép của Apple không cho phép dùng cho logo hay website.

## File cần xuất
| File | Kích thước | Dùng ở |
|---|---|---|
| Biểu tượng app (Icon Composer + `.icns`) | 16–1024 pt | Finder, Dock, Launchpad, Spotlight, onboarding, hộp thoại |
| Ảnh template thanh menu V | 16×16 @1x/@2x, PDF vector | menu Nguồn nhập liệu |
| `favicon.ico` + `favicon.svg` | 16, 32 | tab trình duyệt, kết quả tìm kiếm |
| `apple-touch-icon.png` | 180×180 | ghim trang trên iPhone/iPad |
| `og-image.png` | 1200×630 | `og:image`, `twitter:image` — link chia sẻ Zalo, Messenger, Slack, iMessage, X |
| GitHub social preview | 1280×640 | Settings › Social preview của repo |
| Ảnh nền DMG | theo cửa sổ cài đặt | file DMG phát hành |

## Thẻ cho website
`<title>Dấu – Bộ gõ tiếng Việt cho macOS</title>`, `meta description`, `og:title`, `og:description`, `og:image`, `og:locale=vi_VN`, `twitter:card=summary_large_image`. Mô tả và tiêu đề không chứa lời hứa chưa kiểm chứng (N5).
