# Sổ quyết định

Nguồn chuẩn duy nhất cho mọi quyết định của dự án. Mỗi quyết định ghi nguyên tắc nó dựa vào. Muốn đổi một quyết định: sửa ở đây, ghi lý do và ngày, trong cùng commit với thay đổi mã.

## Nguyên tắc

- **N1. Hệ thống đã có thì không tự làm lại.** Ngoại lệ phải có lý do đo được (xem D4).
- **N2. Tiến trình bộ gõ không có quyền mạng.** Mọi kết nối nằm ở app chủ (cập nhật, danh sách tương thích).
- **N3. Không hỏi ngược ứng dụng đích khi đang gõ liên tục.** Mỗi phím tối đa một lần gọi `insertText`.
- **N4. Không tự ý đổi cài đặt hệ thống của người dùng.** Chỉ hướng dẫn hoặc mở đúng màn hình Cài đặt.
- **N5. Chữ hiển thị cho người dùng phải là lời hứa đã kiểm chứng được.**

## Quyết định

- **D1. Nền tảng:** chỉ macOS, tối thiểu macOS 14, binary universal (Apple silicon + Intel). Swift, Xcode. Không làm Windows/Linux/web.
- **D2. Chuyển Việt/Anh:** "Tiếng Việt" và "Tiếng Anh" là hai input mode của cùng nguồn nhập liệu Dấu, chuyển bằng phím tắt nguồn nhập liệu của macOS; chỉ báo dưới con trỏ do hệ thống hiển thị (N1). Không có phím chuyển riêng, không thông báo nổi, không âm thanh.
- **D3. Không làm:** macro (macOS có Thay thế văn bản), viết hoa đầu câu, bảng mã cũ (TCVN3, VNI-Windows…), công cụ chuyển mã (N1). Chỉ xuất Unicode dựng sẵn (NFC).
- **D4. Từ nước ngoài:** một quy tắc duy nhất — khi kết thúc từ (nhấn Space hoặc ký tự kết thúc từ khác, xem "Ranh giới từ" cuối mục), từ không phải âm tiết tiếng Việt hợp lệ được khôi phục đúng như phím đã gõ (windows, Hasaki). Từ vừa là tiếng Anh vừa là tiếng Việt hợp lệ thì tiếng Việt thắng (car → cả, sex → sẽ, as → á); muốn giữ chữ gốc thì gõ đúp phím dấu theo chuẩn Telex (carr → car). Không dùng từ điển tiếng Anh: nó chỉ có tác dụng ở đúng nhóm từ trùng, và ở đó nó làm hỏng các từ tiếng Việt rất phổ biến như "cả", "sẽ". (Sửa ngày 29/10/2026; bản trước dùng danh sách từ tiếng Anh nhúng sẵn.) **Ranh giới từ:** mọi ký tự kết thúc từ (Space, dấu câu, Enter, Tab) kích hoạt kiểm tra và khôi phục như nhau, không riêng Space ("windows," → "windows,"). (Bổ sung 29/10/2026: ARCHITECTURE.md ghi "Space/dấu câu" trong khi D4 chỉ ghi Space; thống nhất theo cách này.)
- **D5. Quy tắc theo ứng dụng:** quy tắc riêng (chế độ khi mở app, có/không gạch chân) luôn áp dụng. "Nhớ chế độ theo từng ứng dụng" mặc định tắt và chỉ áp dụng cho app không có quy tắc riêng.
- **D6. Phát hành:** GPLv3. DMG ký Developer ID + notarize trên GitHub Releases, Homebrew cask (khai báo `auto_updates true`). Không có Mac App Store (Apple không hỗ trợ phân phối input method qua đó).
- **D7. Cập nhật:** Sparkle 2 nằm trong app chủ, appcast ký EdDSA, kênh Ổn định/Beta, có phát hành theo đợt. Danh sách ứng dụng tương thích là file JSON có chữ ký, cập nhật riêng (N2). Cài bản mới lúc người dùng không gõ, sau đó dừng tiến trình bộ gõ cũ để hệ thống nạp bản mới.
- **D8. Không telemetry.** Báo lỗi qua GitHub issue điền sẵn hoặc "Sao chép nội dung" để gửi email. Không bao giờ gửi nội dung người dùng đã gõ. Log chẩn đoán dùng `os.Logger`, nằm trên máy.
- **D9. Giao diện:** theo macOS hiện hành (mockup vẽ theo macOS 27), dùng control hệ thống qua SwiftUI, cửa sổ Cài đặt có sidebar, không tự vẽ control (N1).
- **D10. Engine:** tự viết bằng Swift thuần (struct, hàm thuần, không Foundation). OpenKey chỉ là tài liệu tham khảo: đọc mã nguồn để hiểu tính năng và ca biên, ghi vào `docs/OPENKEY-NOTES.md`; không nhúng mã, không dùng kết quả chạy OpenKey làm đáp án test. UniKey không dùng.
- **D11. Kiểm tra ngữ cảnh:** engine tự theo dõi trạng thái trong bộ nhớ. Chỉ đọc lại text từ ứng dụng (`selectedRange`, `attributedSubstring`) khi có dấu hiệu lệch: click chuột, đổi ứng dụng/phiên, hoặc người dùng gõ phím dấu khi bộ đệm rỗng (tính năng "Thêm dấu cho từ đã gõ") (N3). Việc lấy vị trí tuyệt đối để thay chữ còn để ngỏ, xem câu hỏi mở A/B bên dưới.
- **D12. Ưu tiên tiến trình:** không bật `.latencyCritical` hay `beginActivity` mặc định. Chỉ thêm khi bài test tải nặng chứng minh có App Nap hoặc bị xếp vào nhân tiết kiệm điện.
- **D13. Ứng dụng không hỗ trợ thay chữ tại chỗ:** chuyển sang marked text (có gạch chân) theo bundle ID trong danh sách tương thích.
- **D14. Onboarding:** bước 1 phát hiện bộ gõ cũ đang chạy (OpenKey, EVKey, GoTiengViet…) qua `NSWorkspace` và hướng dẫn tắt (N4). Bước 2 bật Dấu. Bước 3 chọn kiểu gõ và gõ thử.
- **D15. Mặc định:** Telex, đặt dấu kiểu mới (hoà, thuý), bỏ dấu tự do bật, tự khôi phục từ không phải tiếng Việt bật, "Thêm dấu cho từ đã gõ" bật, nhóm Nâng cao (gõ tắt phụ âm, cho phép z/f/w/j) tắt.
- **D16. Bảo trì:** app có "Quay về bản trước" và "Gỡ cài đặt" (bộ gõ nằm trong `~/Library/Input Methods`, không gỡ được bằng cách kéo vào Thùng rác).
- **D17. Trợ năng:** thông báo cho VoiceOver mỗi khi đổi chế độ Việt/Anh.
- **D18. Phòng thủ với IMK:** coi mọi tham số từ IMK là có thể nil hoặc bất thường (ví dụ bảng Emoji từng truyền NSEvent rỗng); không bao giờ crash vì đầu vào.
- **D19. Quay về bản trước:** tạm tắt tự động cập nhật cho tới khi có bản mới hơn bản lỗi, để Sparkle không cài lại bản vừa gặp lỗi. Cài đặt và quy tắc ứng dụng được giữ nguyên.
- **D20. "Thêm dấu cho từ đã gõ":** đọc chữ đang hiển thị như chữ cái, không như chuỗi phím đã gõ, và chỉ áp dụng khi kết quả là âm tiết tiếng Việt hợp lệ; nếu không thì phím đi thẳng. Nhờ vậy không xung đột với D4 (ví dụ "car" giữ bằng "carr", sau đó gõ thêm "s" vẫn ra "cars").
- **D21. Gõ tắt phụ âm** (nâng cao, mặc định tắt): chỉ áp dụng khi kết thúc từ (ranh giới theo D4) và chỉ khi kết quả là âm tiết tiếng Việt hợp lệ; nếu không thì D4 khôi phục. Khác OpenKey, nơi gõ tắt chạy trước và chặn luôn bước khôi phục ("big" thành "bing" dù không hợp lệ — xem nhánh xử lý phím Space trong `Engine.cpp` của OpenKey). Từ trùng như "bag" → "bang" vẫn xảy ra vì người dùng đã chủ động bật.
- **D22. Gõ tắt phụ âm và "Cho phép z, f, w, j" loại trừ nhau** (cùng tác động lên f, j, w ở đầu từ): bật mục này thì tắt mục kia, ghi rõ trong giao diện.
- **D23. w → qu chỉ có ở VNI.** Với Telex, w ở đầu từ luôn là ư/ơ ("wa" → "ưa"); trong OpenKey quy tắc w → qu không bao giờ kích hoạt ở Telex nên không đưa vào Telex.
- **D24. Tên:** "Dấu" (chốt 29/10/2026), luôn viết có dấu ở mọi chỗ người dùng nhìn thấy: tên app, tên nguồn nhập liệu ("Dấu – Tiếng Việt"), website, logo. Bản không dấu "dau" chỉ dùng cho định danh kỹ thuật (bundle ID, tên target, repo, cask) và không bao giờ đứng một mình trước người dùng, vì dễ đọc thành "đau"/"dầu". Tên miền và tên cask Homebrew: chọn sau khi tra (xem câu hỏi mở).
- **D25. Nhận diện:** biểu tượng "ấ" màu Giấy trên nền Mực, riêng dấu sắc màu Son; logo chữ "Dấu" Be Vietnam Pro một màu; Son chỉ dùng trong biểu tượng; app vẫn dùng phông và màu hệ thống (D9). Chi tiết: `docs/BRAND.md`.
- **D26. Sau khi gõ đúp phím dấu** để giữ chữ gốc (chuẩn Telex, D4), các phím dấu tiếp theo trong cùng từ đi thẳng như chữ cái cho tới khi kết thúc từ (ranh giới theo D4): "carr" → "car", "carrs" → "cars". Khớp với ví dụ ở D20. (29/10/2026)
- **D27. Không có phím gõ nhanh `[` → ơ, `]` → ư trong Telex.** `[` và `]` luôn là dấu câu, kết thúc từ. (29/10/2026)

## Đã cân nhắc và loại bỏ

Rust/WASM và đa nền tảng; thử gõ trên trang web; Mac App Store; event tap + Backspace giả (cách của OpenKey); status item riêng trên thanh menu và mục "Thoát"; phím chuyển nhấn-nhả ⌃ hoặc ⇧; thông báo nổi và âm thanh khi chuyển; `NSSpellChecker` trong đường nóng; từ điển tiếng Anh nhúng sẵn (xem D4); nhúng engine UniKey qua C++ interop; chạy engine OpenKey làm đáp án cho test (oracle); MIT/MPL tách riêng cho engine.

## Câu hỏi mở (phải kiểm chứng trên máy thật)

- **Quan trọng nhất — xung đột giữa N3 và tính đúng đắn.** `insertText(_:replacementRange:)` cần vị trí tuyệt đối của từ đang gõ. Có hai cách:
  - **A.** Hỏi `selectedRange` ở mỗi phím có xử lý dấu: đơn giản, an toàn khi app tự sửa chữ (autocorrect, autocomplete), nhưng thêm một lần gọi đồng bộ mỗi phím (trái N3).
  - **B.** Hỏi một lần khi bắt đầu phiên hoặc sau khi lệch, rồi tự cộng dồn vị trí từ mọi phím đi qua bộ gõ: không gọi thêm, nhưng nếu app tự sửa chữ mà bộ gõ không biết thì sẽ thay **sai vùng** — lỗi nặng hơn chậm.
  - Hướng xử lý: bắt đầu với A để đúng trước; mốc M2 đo chi phí của A trên các app phổ biến khi máy tải nặng. Nếu A đủ nhanh thì sửa N3 thành "tối thiểu lần gọi"; nếu không thì làm B kèm cơ chế phát hiện lệch. Ghi kết quả đo vào đây.

- `TISRegisterInputSource` / `TISEnableInputSource` trên macOS 14–27: có cần người dùng xác nhận không? Ảnh hưởng tới bước 2 onboarding.
- App chủ có sandbox được không khi phải chép bundle bộ gõ vào `~/Library/Input Methods`? Truy cập App Group giữa app chủ và bộ gõ có phát sinh hộp thoại hệ thống không?
- Ngưỡng hiệu năng (độ trễ p99, bộ nhớ) — chốt sau khi đo, so với gõ bằng ABC.
- Độ ổn định của "Thêm dấu cho từ đã gõ" trên các web editor (Google Docs, Notion…).
- Tên "Dấu": tra nhãn hiệu (Cục Sở hữu trí tuệ VN), tên miền (cân nhắc tên miền tiếng Việt có dấu "dấu.vn" bên cạnh một bản không dấu), tên cask Homebrew và tên tổ chức GitHub. Bundle ID và Team ID.
- **Chrome/Terminal có cần quyền Accessibility không?** Ít nhất một bộ gõ IMK khác (VietTelex) ghi trong README rằng phải bật Accessibility mới gõ được trong Terminal, iTerm và các trình duyệt Chromium. Mốc M2 phải kiểm chứng `insertText(_:replacementRange:)` trên các app này. Mặc định nếu không được: dùng gạch chân cho các app đó (D13), không xin quyền Accessibility (N4, bảo mật). Mọi câu trên giao diện và website về gạch chân hay quyền truy cập để ô trống cho tới khi có kết quả (N5).
