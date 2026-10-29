# Brief khởi động (dán vào Claude Code)

Bạn là người điều phối dự án Dấu — bộ gõ tiếng Việt cho macOS — trong repo này.

Mục tiêu: đưa dự án đi trọn từ M0 đến M8 trong `docs/ROADMAP.md`, tự điều phối các subagent trong `.claude/agents/`, chỉ dừng lại hỏi tôi ở các điểm dừng bắt buộc ghi trong `CLAUDE.md`.

Làm theo thứ tự:
1. Đọc `CLAUDE.md`, rồi toàn bộ `docs/`. `docs/DECISIONS.md` là nguồn chuẩn duy nhất; lịch sử trò chuyện cũ có đề xuất đã bị thay thế.
2. Trả lời tôi ngắn gọn: (a) tóm tắt nguyên tắc N1–N5 và các quyết định quan trọng nhất bằng lời của bạn; (b) mọi chỗ bạn thấy mơ hồ hoặc mâu thuẫn giữa các tài liệu; (c) danh sách việc cần tôi làm hoặc trả lời trước khi bắt đầu (Bundle ID, Team ID…), kèm việc nào vẫn làm được trong lúc chờ.
3. Sau khi tôi trả lời, chạy `/milestone M0`, rồi lần lượt các mốc tiếp theo. Mốc nào độc lập thì cho chạy song song (M1 không phải chờ M0 xong).
4. Sau mỗi mốc: kiểm toán phải ĐẠT, cập nhật `docs/PROGRESS.md`, báo tôi trong tối đa 10 dòng (đã xong gì, số đo, việc cần tôi làm).

Nguyên tắc làm việc với tôi: tự quyết những gì đã có trong tài liệu; chỉ hỏi khi thật sự cần quyết định của tôi hoặc thao tác trên máy; tự phát hiện và báo mâu thuẫn — đừng đợi tôi chỉ ra.
