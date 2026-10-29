# Dấu — bộ gõ tiếng Việt cho macOS

Dấu là input method tiếng Việt **chỉ dành cho macOS**, dựng trên InputMethodKit (IMK). Nó thay chữ tại chỗ bằng `insertText(_:replacementRange:)` thay vì giả lập phím Backspace như OpenKey. Tên chính thức: **Dấu** (đã chốt). Quy tắc dùng tên và định danh kỹ thuật: xem D24.

Đọc theo thứ tự trước khi làm bất cứ việc gì:
1. `docs/DECISIONS.md` — sổ quyết định (nguồn chuẩn duy nhất).
2. `docs/ARCHITECTURE.md` — kiến trúc, target, luồng xử lý phím.
3. `docs/ROADMAP.md` — các mốc, tiêu chí hoàn thành.
4. `docs/UI.md` — mô tả màn hình (mockup gốc nằm trên canvas, xem link trong file).
5. `docs/BRAND.md` — biểu tượng, màu, chữ, danh sách file nhận diện cần xuất.
6. `docs/PROGRESS.md` — đang ở đâu, việc đang chờ, số đo. **Đọc đầu tiên khi bắt đầu một phiên mới.**

## Điều phối

Phiên chính là **người điều phối**: lập kế hoạch, giao việc cho subagent trong `.claude/agents/`, kiểm chứng kết quả, commit, cập nhật `docs/PROGRESS.md`. Phiên chính hạn chế tự viết mã lớn để giữ ngữ cảnh gọn.

| Agent | Phụ trách |
|---|---|
| `researcher` | đọc OpenKey, tài liệu Apple; viết `docs/OPENKEY-NOTES.md` |
| `engine-dev` | `Packages/DauEngine` và test |
| `imk-dev` | `Apps/DauInputMethod` |
| `app-ui-dev` | `Apps/Dau` (SwiftUI) |
| `release-eng` | XcodeGen, CI, ký, notarize, Sparkle, Homebrew, xuất file nhận diện |
| `auditor` | kiểm tra độc lập, chỉ đọc; phải ĐẠT trước khi đóng mốc |

- Lệnh `/milestone M#` chạy trọn một mốc; `/audit` kiểm tra toàn repo.
- Subagent không thừa hưởng ngữ cảnh của phiên chính: mỗi lần giao việc phải nêu phạm vi, file được sửa, tiêu chí xong.
- Giao song song các việc độc lập (ví dụ M1 engine song song với M0 khung dự án; M4 giao diện song song M3 khi model cài đặt chung đã xong).
- Mỗi việc xong → kiểm chứng lại bằng lệnh thật → commit nhỏ (Conventional Commits, tiếng Anh). Không commit khi test đỏ.
- **Điểm dừng bắt buộc — hỏi người dùng:** Bundle ID / Team ID / tên cask / tên miền; mọi thao tác cần tài khoản Apple Developer hay chứng chỉ; bật nguồn nhập liệu, đăng xuất, cấp quyền, gõ thử trong ứng dụng thật (không thao tác được giao diện macOS); mọi thay đổi `DECISIONS.md`. Trong lúc chờ, tiếp tục các việc không bị chặn.
- Ngữ cảnh dài: trước khi ngữ cảnh đầy, ghi trạng thái vào `docs/PROGRESS.md` để có thể tiếp tục ở phiên sau.

## Nguồn chuẩn

- `docs/DECISIONS.md` là nguồn chuẩn **duy nhất** cho quyết định. Canvas mockup có một ghi chú tóm tắt sổ quyết định, và lịch sử trò chuyện trên claude.ai có nhiều đề xuất đã bị thay thế (Rust/WASM, nhúng UniKey, từ điển tiếng Anh, `NSSpellChecker`, phím chuyển nhấn-nhả ⇧, chạy OpenKey làm đáp án test…). Gặp thông tin trái với `DECISIONS.md` ở bất kỳ đâu thì theo `DECISIONS.md`, và sửa hoặc báo chỗ lệch.
- Khi một quyết định thay đổi: sửa `DECISIONS.md` trước, rồi cập nhật ghi chú trên canvas và các tài liệu khác cho khớp trong cùng lượt làm việc.

## Quy tắc làm việc

- **Đối chiếu sổ quyết định trước mọi đề xuất hay thay đổi.** Nếu một thay đổi mâu thuẫn với một nguyên tắc (N1–N5) hoặc quyết định (D1–D…) thì dừng lại và nêu mâu thuẫn, không tự ý làm. Nếu một quyết định cần đổi, cập nhật `docs/DECISIONS.md` trong cùng commit, ghi lý do.
- **Sau mỗi mốc, tự rà soát cơ học:** grep code, chuỗi giao diện và tài liệu để tìm chỗ trái với sổ quyết định (ví dụ: lời hứa về mạng, tính năng đã bỏ, phím tắt riêng).
- **Kiểm tra chéo các tính năng cùng tác động lên một đầu vào.** Với mỗi cặp tính năng như vậy, liệt kê các đầu vào mà chúng cho kết quả trái nhau và quyết định bên nào thắng, ghi vào `DECISIONS.md` (bài học từ D4).
- **Đo trước khi tối ưu.** Mọi khẳng định về hiệu năng phải có số đo (os_signpost / Instruments / test hiệu năng).
- **Không ghi lời hứa chưa kiểm chứng vào giao diện** (N5). Dùng ô trống dạng `[Kết quả bài test tải nặng]`.
- Làm theo mốc trong `docs/ROADMAP.md`, mỗi mốc kết thúc bằng test xanh và một bản tóm tắt ngắn: đã làm gì, đã đo được gì, còn mở gì.
- Những việc cần tài khoản Apple Developer, chứng chỉ ký, hoặc thao tác trong Cài đặt hệ thống: chuẩn bị sẵn và dừng lại hỏi người dùng.

## Quy ước mã nguồn (đề xuất, người dùng có thể đổi)

- Swift 6, strict concurrency. Engine là Swift package thuần, **không import Foundation/AppKit**.
- Dự án Xcode sinh từ `project.yml` bằng XcodeGen, không commit thủ công thay đổi trong `.xcodeproj`.
- Test bằng Swift Testing. Tên định danh, comment và commit message bằng tiếng Anh; chuỗi giao diện bằng tiếng Việt (String Catalog).
- Giấy phép GPLv3 cho toàn bộ repo. Engine là của Dấu, viết từ đầu bằng Swift. Không chép mã từ OpenKey hay UniKey.

## OpenKey là tài liệu tham khảo, không phải đáp án

- Khi cần hiểu tường tận một tính năng (quy tắc đặt dấu, chính tả, khôi phục, gõ tắt…), clone OpenKey **ra ngoài repo** (ví dụ `/tmp/OpenKey`) và đọc mã nguồn, chủ yếu `Sources/OpenKey/engine/`.
- Ghi lại hiểu biết **bằng lời của mình** vào `docs/OPENKEY-NOTES.md`: tính năng, hành vi, ca biên, lỗi phát hiện được, và Dấu làm hay không làm (dẫn số quyết định).
- Kết quả mong đợi trong test viết theo quy tắc chính tả tiếng Việt và `DECISIONS.md`, không lấy từ kết quả chạy OpenKey. Chỗ nào Dấu cố ý khác OpenKey thì ghi rõ trong `OPENKEY-NOTES.md`.

## Lệnh thường dùng (cập nhật khi dự án có thật)

- `brew install xcodegen && xcodegen generate` — sinh `Dau.xcodeproj`.
- `swift test --package-path Packages/DauEngine` — test engine.
