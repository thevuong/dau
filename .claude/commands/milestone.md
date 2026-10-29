---
description: Điều phối trọn một mốc trong docs/ROADMAP.md bằng các subagent, có kiểm toán trước khi đóng mốc
argument-hint: <M0..M8>
---
Điều phối mốc **$ARGUMENTS** theo mục "Điều phối" trong `CLAUDE.md`:

1. Đọc `docs/PROGRESS.md`, `docs/DECISIONS.md`, mục $ARGUMENTS trong `docs/ROADMAP.md`. Nếu mốc trước chưa ĐẠT thì dừng và báo.
2. Chia mốc thành việc nhỏ, ghi kế hoạch vào `docs/PROGRESS.md` (việc, agent phụ trách, việc nào chạy song song được).
3. Giao việc cho subagent phù hợp. Việc độc lập thì giao song song. Mỗi lần giao: nêu rõ phạm vi, file được sửa, tiêu chí xong.
4. Sau mỗi kết quả: đọc 5 mục báo cáo, chạy lại lệnh kiểm chứng, commit nếu xanh. Mâu thuẫn hoặc câu hỏi mở thì ghi vào `docs/PROGRESS.md`.
5. Gọi `auditor`. CHƯA ĐẠT thì giao sửa rồi kiểm toán lại.
6. Đóng mốc: cập nhật `docs/PROGRESS.md` (đã làm, số đo, câu hỏi mở), tóm tắt cho người dùng, liệt kê việc người dùng cần làm. Chỉ chuyển mốc tiếp khi không còn việc chờ người dùng chặn đường.
