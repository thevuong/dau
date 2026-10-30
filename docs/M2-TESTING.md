# M2 — Gõ thử trên máy thật

Danh sách việc người dùng làm trên máy để kiểm chứng mốc M2. Kết quả ở đây là đầu vào để giải **câu hỏi mở A/B** (chi phí `selectedRange`) và câu hỏi **Chrome/Terminal** trong `DECISIONS.md`. Mọi ô kết quả để trống cho tới khi đo (N5); không chép kết quả vào giao diện hay website trước khi phiên chính tổng hợp và cập nhật `DECISIONS.md`.

## 0. Chuẩn bị

1. Thoát các bộ gõ tiếng Việt khác đang chạy (OpenKey, EVKey, GoTiengViet…), kể cả trong Mục đăng nhập.
2. Trong Terminal, ở thư mục repo: `scripts/install-debug.sh`. Script build bản Debug, chép `DauInputMethod.app` vào `~/Library/Input Methods`, dừng tiến trình bộ gõ cũ và in các bước bật nguồn nhập liệu.
3. Làm theo các bước script in ra: Cài đặt hệ thống › Bàn phím › Nguồn đầu vào › Sửa… › "+" › Tiếng Việt › "Dấu – Tiếng Việt" › Thêm. Dấu chỉ có nguồn này (D2); gõ tiếng Anh bằng ABC/U.S. của macOS, nên giữ ABC (hoặc U.S.) trong danh sách. Nếu còn "Dấu – Tiếng Anh" từ bản cũ thì bỏ nó. Không thấy "Dấu" thì đăng xuất, đăng nhập lại rồi làm lại.
4. Chọn "Dấu – Tiếng Việt" ở menu nguồn nhập liệu trên thanh menu. Nếu máy bật "Tự động chuyển sang nguồn đầu vào của tài liệu" (Cài đặt hệ thống › Bàn phím › Nguồn đầu vào), mỗi ứng dụng/cửa sổ nhớ nguồn riêng: phải chọn lại "Dấu – Tiếng Việt" **sau khi** chuyển sang từng ứng dụng thử, và nhìn biểu tượng V trên thanh menu trước khi gõ.
5. (Tuỳ chọn, để xem lỗi nếu bộ gõ không chạy) mở một cửa sổ Terminal riêng:
   `/usr/bin/log stream --predicate 'process == "DauInputMethod"'` (trong zsh, `log` là lệnh có sẵn khác, phải gõ đường dẫn đầy đủ)

Bản Debug ghi một dòng log cho mỗi phím, category `perf`, chỉ gồm loại sự kiện, thời gian (ns) và bundle ID của ứng dụng đang gõ. **Không** ghi chữ bạn gõ (D8). Có thể tự kiểm: `/usr/bin/log show --last 5m --predicate 'category == "perf"' --style compact`.

## 1. Câu mẫu

Gõ đúng chuỗi phím sau (Telex), kết thúc bằng một dấu cách:

```
tooi yeeu tieengs Vieetj, windows Hasaki carr␣
```

Kết quả mong đợi (theo D4, D26, D30):

```
tôi yêu tiếng Việt, windows Hasaki car␣
```

- "windows", "Hasaki": trong lúc gõ có thể thấy chữ bị biến đổi tạm (ví dụ "ư…", "Há…"); khi nhấn dấu cách hoặc dấu câu, từ trở về đúng như đã gõ (D4).
- "carr" → "car" (gõ đúp phím dấu giữ chữ gốc, D4/D26).

## 2. Từng ứng dụng

Mỗi ứng dụng: mở một ô soạn thảo trống, gõ câu mẫu, ghi lại. Sau đó trong Terminal chạy lệnh perf của ứng dụng đó (mục 3) và dán p50/p99 của `selectedRange_us`.

- **Gạch chân:** chữ đang gõ có bị gạch chân không. Dấu không dùng marked text ở M2, nên gạch chân (nếu có) là điều bất thường cần ghi lại.
- **Nhảy chữ:** có ký tự bị lặp, mất, đảo thứ tự, con trỏ nhảy, hoặc chữ bị thay sai chỗ không.

Kết quả (30/10/2026): agent tự gõ câu mẫu qua System Events, 30 ms/phím, bản Debug. Số đo là phím có thay (n=12 mỗi app ở 5 app đầu), chép từ `docs/PROGRESS.md` mục "Số đo". "—" ở cột `count_unsupported`: lượt đo 29/10 không ghi riêng số này.

| Ứng dụng | Bundle ID (cho `--app`) | Kết quả thực tế | Gạch chân? | Nhảy chữ? | `selectedRange` p50 / p99 (µs) | `count_unsupported` / `count_mismatch` | Ghi chú |
|---|---|---|---|---|---|---|---|
| TextEdit | `com.apple.TextEdit` | Đúng ở 30 ms/phím | Không | Không | 327 / 606 | — / 0 | `scripts/selftest-typing`, 29/10. Người dùng gõ tay 29/10 cũng đúng |
| Safari (ô tìm kiếm + một ô soạn thảo trên web) | `com.apple.Safari` | Đúng ở 30 ms/phím | Không | Không | 622 / 1.057 | — / 0 | `scripts/selftest-typing`, 29/10. Người dùng gõ tay 29/10 cũng đúng |
| Chrome (thanh địa chỉ + một ô soạn thảo trên web) | `com.google.Chrome` | Đúng ở 30 ms/phím | Không | Không ở 30 ms; có khi phím đến dồn | 415 / 694 | — / 0 | `scripts/selftest-typing`, 29/10. Sai khi phím đến cách nhau < 10 ms (app áp phím bất đồng bộ; M3 thử D13). Người dùng gõ tay 29/10 đúng |
| Telegram (thay Slack) | `ru.keepcoder.Telegram` | "tôi yêu tiếng Việt, windows Hasaki car" | Không | Không | 240 / 1.670 | 0 / 0 | 30/10, tự gõ 30 ms/phím trong Saved Messages, chỉ gõ, không gửi. `insertText` p50 1.830 / p99 3.491 µs; cả phím có thay p50 2.171 / p99 5.313 µs; replace 12, pass 34 |
| VS Code | `com.microsoft.VSCode` | Đúng ở 30 ms/phím | Không | Không ở 30 ms; có khi phím đến dồn | 230 / 885 | — / 0 | `scripts/selftest-typing`, 29/10. Sai khi phím đến cách nhau < 20 ms (Electron áp phím bất đồng bộ; M3 thử D13) |
| Terminal | `com.apple.Terminal` | Đúng ở 30 ms/phím | Không | Không ở 30 ms; có khi phím đến dồn | 408 / 637 | — / 0 | `scripts/selftest-typing`, 29/10. Sai khi phím đến cách nhau < 10 ms (chờ shell echo; M3 thử D13) |

Bundle ID thật mà bộ gõ nhận được có thể khác cột trên (ví dụ tiến trình con của trình duyệt). `--app` nhận tên app hoặc một phần bundle ID, không phân biệt hoa thường (`--app TextEdit`, `--app chrome`), **không nhận PID**. Nếu `--app` không ra số, script in danh sách app có số đo trong khoảng thời gian đó.

Ý nghĩa các loại sự kiện trong báo cáo:
- `replace`: hỏi `selectedRange` rồi thay chữ tại chỗ bằng một lần `insertText` (cách A).
- `insert`: chèn tại con trỏ, không cần hỏi vị trí (ví dụ "w" → "ư").
- `unsupported`: ứng dụng trả `NSNotFound` cho `selectedRange` (không hỗ trợ truy cập văn bản). Bộ gõ bỏ từ đang gõ và để phím đi thẳng; chữ ra gần như không dấu. Đây là dấu hiệu ứng dụng cần gạch chân (D13) — ghi lại số lần.
- `mismatch`: vị trí con trỏ khác vị trí bộ gõ dự đoán (D11), hoặc đang có vùng chọn. Bộ gõ bỏ từ đang gõ để không thay sai chỗ.
- `reset`: phím tắt ⌘/⌃/⌥, mũi tên, Esc hoặc click chuột.
- `event_client-changed`: số lần client đổi dưới cùng một controller. Nếu số này tăng theo từng phím thì là lỗi (bộ gõ sẽ không bỏ dấu được) — báo lại ngay.
- `event_client-not-text-input`: client không trả lời được giao thức nhập văn bản — báo lại ngay.

## 3. Lấy số đo

Ngay sau khi gõ xong ở một ứng dụng:

```
scripts/perf-report.sh --last 5m --app com.apple.TextEdit
```

Các dòng cần chép vào bảng: `selectedRange_us` (chi phí của cách A), `handle_replace_us` (tổng thời gian xử lý một phím có thay chữ), `insertText_us`, và các dòng `count_…`. Muốn có p99 đáng tin hơn, gõ thêm vài đoạn văn tiếng Việt dài (tối thiểu vài trăm phím có dấu) trong cùng ứng dụng rồi chạy lại.

**Tuỳ chọn — máy đang tải nặng** (bài test đầy đủ ở M6): mở Terminal và chạy
`for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`, gõ lại câu mẫu trong TextEdit và Chrome, chạy `perf-report.sh`, rồi dừng tải bằng `killall yes`.

## 4. Kiểm tra hành vi

Làm trong TextEdit (và lặp lại ở ứng dụng nào có kết quả lạ ở mục 2).

Kết quả (30/10/2026): agent tự gõ qua System Events. Chưa chạy: 9, 10 (chạy lại sau khi bỏ chế độ Anh ở 9680c68), 16 (VoiceOver, cần người); 3 bỏ qua; 14 mới xong một phần.

| # | Thao tác | Mong đợi | Kết quả |
|---|---|---|---|
| 1 | Gõ `hoaf`, rồi ⌫ | "hoà" rồi "hò" (D32) | ĐẠT: "hoà" → ⌫ → "hò" |
| 2 | Gõ `windows` rồi nhấn Return | "windows" rồi xuống dòng | ĐẠT: lúc gõ hiện "ưindows", Return → "Windows⏎" (chữ hoa do TextEdit tự viết hoa đầu dòng, không phải Dấu) |
| 3 | Trong Telegram (Saved Messages): gõ `carr` rồi nhấn Return | tin nhắn gửi đi là "car" (thay chữ xong trước khi Return được xử lý) | Bỏ qua: người dùng không cho gửi tin nhắn |
| 4 | Gõ `to`, click chuột vào chỗ khác trong văn bản, gõ `o` | chỉ thêm "o" ở chỗ mới; chữ "to" cũ không đổi | ĐẠT |
| 5 | Gõ `tooi`, click vào chỗ khác, gõ `s` | chỉ thêm "s" ở chỗ mới; "tôi" cũ không đổi | ĐẠT |
| 6 | Gõ `tooi`, nhấn ←, gõ `s` | thêm "s" ở vị trí con trỏ, không bỏ dấu vào "tôi" (D4: mũi tên chỉ reset) | ĐẠT. Ghi chú: lần ← đầu sau một từ gõ dở bị macOS/TextEdit nuốt (với U.S. cũng vậy); lần ← thứ hai mới chạy, Dấu ghi log reset |
| 7 | Chọn một đoạn chữ bằng chuột, gõ `tooi` | đoạn chọn bị thay bằng "tôi" | ĐẠT |
| 8 | Gõ `tooi`, nhấn ⌘Z | ứng dụng hoàn tác bình thường, không lỗi | ĐẠT (⌘Z hoàn tác bình thường) |
| 9 | Chuyển sang ABC (hoặc U.S.) bằng phím tắt nguồn nhập liệu của macOS, gõ `tooi` | "tooi" (D2: tiếng Anh dùng nguồn của hệ thống) | ĐẠT (30/10, ⌃Space, 2/2 lần): "tôi" → U.S. → "tooi" giữ nguyên |
| 10 | Chuyển lại "Dấu – Tiếng Việt", gõ `tooi` | "tôi"; chữ đang gõ dở trước khi chuyển không bị sửa (D4: đổi nguồn chỉ reset) | ĐẠT với ⌃Space: `to`, đổi nguồn đi rồi về, `o` ra "too" (đã reset). Chọn lại Dấu bằng `TISSelectInputSource` từ tiến trình khác thì không reset ("tô") — việc của M3 (ROADMAP) |
| 11 | Menu nguồn nhập liệu: có nhóm "Kiểu gõ" với Telex ✓ / VNI / Telex đơn giản và mục "Mở cài đặt Bàn phím…" | đúng như mô tả, chữ có dấu, tên "Dấu" | ĐẠT: Kiểu gõ Telex ✓ / VNI / Telex đơn giản, "Cài đặt Dấu…", "Mở cài đặt Bàn phím…"; chữ có dấu đúng |
| 12 | Chọn VNI trong menu, gõ `to6i` | "tôi"; mở menu lại thấy VNI ✓. Chọn lại Telex sau khi thử | ĐẠT: `to6i` → "tôi", menu VNI ✓, đã chọn lại Telex |
| 13 | Bấm "Mở cài đặt Bàn phím…" | Cài đặt hệ thống mở đúng mục Bàn phím (N4) | ĐẠT |
| 14 | Biểu tượng trên thanh menu khi chọn Dấu; danh sách "+" của Nguồn đầu vào | "V" đơn sắc, đổi màu theo nền sáng/tối. Dấu chỉ có "Dấu – Tiếng Việt" trong nhóm Tiếng Việt, không có "Dấu – Tiếng Anh" ở nhóm Tiếng Anh (D2) | Một phần: không chụp được thanh menu; bundle khai báo biểu tượng V. Danh sách "+" chưa xem lại sau 9680c68 |
| 15 | Mở bảng Emoji (fn/🌐 E hoặc ⌃⌘Space), chèn một emoji, gõ tiếp `tooi` | không treo, không mất chữ (D18) | ĐẠT: "❤️ tôi", không treo |
| 16 | Bật VoiceOver (⌘F5), chuyển "Dấu – Tiếng Việt" ↔ ABC bằng phím tắt nguồn nhập liệu | hệ thống tự đọc tên nguồn; Dấu không đọc thêm (D17). Hệ thống không đọc thì ghi lại để xét lại D17 | Chưa chạy (cần người) |
| 17 | Gõ ở ô mật khẩu (ví dụ ô mật khẩu trong Safari) | ghi lại hành vi (macOS thường tự chuyển bàn phím ASCII ở ô bảo mật) | Ghi lại: ở ô bảo mật macOS giữ `com.apple.keylayout.US`, Dấu không nhận phím nào |

## 5. Gửi lại

Gửi lại bảng ở mục 2 và 4 (có thể chép nguyên văn kết quả `perf-report.sh`). Phiên chính dùng số liệu này để:
- quyết định giữ cách A hay chuyển sang cách B (câu hỏi mở A/B), và ghi số đo vào `DECISIONS.md` / `PROGRESS.md`;
- quyết định ứng dụng nào cần gạch chân (D13) và trả lời câu hỏi Chrome/Terminal (không xin quyền Accessibility, N4).
