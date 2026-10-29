# Ghi chú đọc mã nguồn OpenKey

Tài liệu tham khảo cho mốc M1. Viết bằng lời của Dấu, **không chép mã**. Theo D10, OpenKey chỉ là tài liệu tham khảo: mọi kết quả mong đợi trong test viết theo chính tả tiếng Việt và `DECISIONS.md`, không lấy từ việc chạy OpenKey.

- Nguồn: https://github.com/tuyenvm/OpenKey, commit `89c2fd3` (15/06/2026), clone ra `/tmp/OpenKey` (ngoài repo).
- Phạm vi đọc: `Sources/OpenKey/engine/` (`Engine.cpp`, `Engine.h`, `Vietnamese.cpp`, `DataType.h`, `Macro.cpp`, `SmartSwitchKey.cpp`, `ConvertTool.cpp`, `platforms/mac.h`), thêm `macOS/ModernKey/OpenKey.mm` để biết engine được gọi thế nào.
- **OpenKey chưa được chạy.** Mọi hành vi dưới đây có được bằng cách lần theo mã. Chỗ nào chỉ là suy luận, chưa chạy thử để xác nhận, sẽ ghi "(suy luận)". Ta cũng cố ý không chạy để kiểm chứng, vì D10 cấm dùng OpenKey làm đáp án.
- Quy ước: `␣` là phím Space. "Bộ đệm" là từ đang gõ.
- Cập nhật 29/10/2026 theo DECISIONS.md (commit `495544d`): các điểm mơ hồ M1–M17 đã được chốt thành D4 (ranh giới từ), D20–D23 (sửa) và D26–D33. Mục 2, 3, 6, 7 đã đổi nhãn tương ứng.

---

## 1. Kiến trúc engine OpenKey (tóm tắt)

- **Toàn bộ trạng thái là biến toàn cục** (`Engine.cpp`): mọi ứng dụng dùng chung một bộ đệm. Dấu thì mỗi client có một `VietEngine` riêng (ARCHITECTURE).
- **Đầu vào là mã phím vật lý** (virtual keycode, xếp theo vị trí bàn phím US trong `platforms/mac.h`), không phải ký tự. Vì vậy trên Dvorak/AZERTY engine hiểu sai phím, trừ khi bật tuỳ chọn "layout compat" (`OpenKey.mm`, hàm đổi ký tự ngược về keycode). Engine của Dấu nhận `Unicode.Scalar` nên không mắc lỗi này.
- **Đầu ra** là một bản ghi gồm: mã hành động (không làm gì / xử lý / khôi phục / thay macro / khôi phục rồi mở từ mới), số Backspace cần gửi, và danh sách ký tự mới. Tầng macOS gửi Backspace giả rồi gõ chuỗi mới qua event tap. Dấu đã loại cách này, xem "Đã cân nhắc và loại bỏ". Khi mã là "khôi phục", tầng macOS **tự gõ thêm ký tự của phím vừa nhấn** sau chuỗi khôi phục.
- **Hai bộ đệm song song**:
  - bộ đệm chữ: mỗi phần tử là một chữ cái kèm các cờ hoa, mũ (^), móc/trăng, một trong 5 dấu thanh, "w đứng riêng";
  - bộ đệm phím gốc: chuỗi phím thật đã gõ, dùng để khôi phục.

  Cả hai giới hạn 32 phần tử. Bài học cho Dấu: phải giữ cả chữ hiển thị lẫn phím gốc.
- **Cờ "tạm tắt xử lý"** (`tempDisableKey`): được bật khi từ sai chính tả hoặc khi vừa gõ đúp để huỷ biến đổi. Khi cờ bật, mọi phím biến đổi còn lại trong từ đều đi thẳng như chữ thường. Bộ đệm chỉ được reset khi gặp ranh giới từ.
- **Lịch sử từ trong dòng** (`_typingStates`): lưu các từ đã gõ trong dòng hiện tại, để Backspace lùi qua dấu cách có thể sửa tiếp từ trước. Xem mục 3.17.
- OpenKey thường gửi lại cả đoạn từ vị trí đổi sớm nhất (thường là nguyên âm đầu của cụm) tới cuối từ, không tính phần chênh tối thiểu. Dấu có thể so phần đầu chung để `deleteCount` nhỏ nhất (đề xuất, xem N3).

## 2. Danh sách tính năng và quyết định của Dấu

| # | Tính năng OpenKey (biến cấu hình) | Dấu | Căn cứ |
|---|---|---|---|
| 1 | Kiểu gõ Telex | Làm, mặc định | D15 |
| 2 | Kiểu gõ VNI | Làm | ARCHITECTURE, UI.md |
| 3 | Simple Telex 1 và Simple Telex 2 | Làm một kiểu "Telex đơn giản" = Simple Telex 1 (w chỉ biến đổi sau a/o/u, không `[ ]`, không w → qu) | D29 |
| 4 | Đặt dấu kiểu mới/cũ (`vUseModernOrthography`) | Làm, mặc định kiểu mới | D15 |
| 5 | Bỏ dấu tự do (`vFreeMark`) | Làm, mặc định bật. Nghĩa khác biến của OpenKey (mục 3.7) | D15, D28 |
| 6 | Kiểm tra chính tả (`vCheckSpelling`) | Luôn chạy bên trong, không có công tắc riêng; định nghĩa âm tiết hợp lệ theo D31 | D30, D31 |
| 7 | Khôi phục khi sai chính tả (`vRestoreIfWrongSpelling`) | Làm ("Tự khôi phục từ không phải tiếng Việt"), mặc định bật | D4, D15 |
| 8 | Gõ đúp phím dấu để giữ chữ gốc | Làm; sau gõ đúp phím dấu đi thẳng tới hết từ | D4, D26 |
| 9 | Gõ nhanh / Quick Telex (`vQuickTelex`: cc→ch, gg→gi, kk→kh, nn→ng, qq→qu, pp→ph, tt→th) | Không làm | DECISIONS, mục "Đã cân nhắc và loại bỏ" |
| 10 | Gõ tắt phụ âm đầu (`vQuickStartConsonant`: f→ph, j→gi, w→qu) | Làm, có khác biệt; w→qu chỉ ở VNI (không ở Telex, Telex đơn giản) | D21, D22, D23, D29 |
| 11 | Gõ tắt phụ âm cuối (`vQuickEndConsonant`: g→ng, h→nh, k→ch) | Làm, có khác biệt | D21 |
| 12 | Cho phép phụ âm z, f, w, j (`vAllowConsonantZFWJ`) | Làm, loại trừ với mục 10–11 | D22, D15 |
| 13 | Macro / gõ tắt văn bản, kể cả trong chế độ Anh, tự viết hoa macro | Không làm | D3 |
| 14 | Viết hoa chữ đầu câu (`vUpperCaseFirstChar`) | Không làm | D3 |
| 15 | Bảng mã: Unicode, TCVN3, VNI-Windows, Unicode tổ hợp, CP1258 (`vCodeTable`) | Không làm, chỉ xuất NFC | D3 |
| 16 | Công cụ chuyển mã (`ConvertTool.cpp`) và phím tắt của nó | Không làm | D3 |
| 17 | Smart switch: nhớ Việt/Anh theo ứng dụng (`vUseSmartSwitchKey`, `SmartSwitchKey.cpp`) | Làm khác: quy tắc riêng luôn thắng, "Nhớ chế độ" mặc định tắt | D5 |
| 18 | Nhớ bảng mã theo ứng dụng (`vRememberCode`) | Không làm (vì không có bảng mã) | D3 |
| 19 | Phím chuyển Việt/Anh riêng, có tiếng bíp | Không làm | D2 |
| 20 | Tạm tắt chính tả bằng nhấn-nhả ⌃ (`vTempOffSpelling`) | Không làm (kiểm tra chính tả luôn chạy, D30) | D30, mục "Đã cân nhắc và loại bỏ" |
| 21 | Tạm tắt bộ gõ cho từ hiện tại bằng nhấn-nhả ⌘ (`vTempOffOpenKey`) | Không làm | D2, mục "Đã cân nhắc và loại bỏ" |
| 22 | Tắt tiếng Việt khi bàn phím hệ thống không phải tiếng Anh (`vOtherLanguage`) | Không cần: Dấu tự là nguồn nhập liệu (suy luận) | D2 |
| 23 | Sửa gợi ý tự hoàn thành của trình duyệt (`vFixRecommendBrowser`), gửi từng phím (`vSendKeyStepByStep`) | Không làm: đây là mẹo riêng của event tap. Dùng marked text theo danh sách tương thích | D13, mục loại bỏ |
| 24 | Phím `[` → ơ, `]` → ư (chỉ Telex) | Không làm; `[ ]` luôn là dấu câu, kết thúc từ | D27 |
| 25 | Lịch sử từ: Backspace qua dấu cách để sửa tiếp từ trước | Không làm; trường hợp này do D20 phủ | D20, D32 |
| 26 | "Thêm dấu cho từ đã gõ" (đọc chữ trong ứng dụng) | OpenKey **không có**. Dấu làm, cho cả phím dấu thanh lẫn phím biến đổi | D11, D20 |
| 27 | Giới hạn độ dài từ (OpenKey: bộ đệm 32 phần tử, dịch trái khi tràn) | Từ dài hơn 7 chữ cái thì ngừng biến đổi; bộ đệm dung lượng cố định | D33 |
| 28 | Backspace trong từ | Bỏ chữ cuối, đặt lại dấu; mốc khôi phục là chữ đang hiển thị | D32 |

---

## 3. Chi tiết từng tính năng

### 3.1 Telex: các phím biến đổi

Các phím được xử lý (`IS_SPECIALKEY` trong `DataType.h`): `a e o w d s f r x j z` và (chỉ ở Telex) `[ ]`. Các phím khác luôn đi thẳng vào bộ đệm.

- **aa → â, ee → ê, oo → ô** (`insertAOE`). Phím biến đổi không cần đứng sát nguyên âm: engine tìm ngược trong từ chữ cùng loại gần nhất, miễn đuôi từ khớp một mẫu vần trong bảng `_vowel`. Ví dụ "viet" + `e` → "viêt"; "tien" + `e` → "tiên". Nếu nguyên âm đang mang móc/trăng thì phím này bỏ móc/trăng và thay bằng mũ ("ă" + `a` → "â").
- **aw → ă, ow → ơ, uw → ư; "uo" + w → "ươ"** (`insertW`). Với cụm hai nguyên âm:
  - "uo": thường thì cả hai được móc → "ươ". Riêng sau "th", chỉ "o" được móc ("thuơ", dùng cho "thuở"), trừ khi theo sau là "n" ("thươn…"). Sau "q", chỉ "o" được móc.
  - "ua", "ui", "uu", "oi": móc chữ đầu → "ưa", "ưi", "ưu", "ơi".
  - "io", "oa": móc chữ sau.
  - Các cụm khác: phím w không làm gì và cả từ bị tạm tắt xử lý.

  Phím w cũng bỏ mũ nếu có ("â" + `w` → "ă").
- **Tự sửa "ưo"/"uơ" thành "ươ"** (`checkGrammar`): khi sau "uo" có n, c, i, m, p hoặc t mà chỉ một trong hai chữ có móc, engine móc nốt chữ kia. Ví dụ "tưon" → "tươn", "đưoc" → "đươc".
- **w đứng riêng → ư** (`checkForStandaloneChar`, không áp dụng ở Simple Telex 1):
  - w là phím đầu từ → "ư".
  - Sau đúng một phụ âm → "ư" ("tw" → "tư"), trừ khi phụ âm đó là w, e, y, f, j, k, z (`_standaloneWbad`; e và y thực ra là nguyên âm, lẫn vào danh sách).
  - Sau phụ âm đôi tr, th, ch, nh, ng, kh, gi, ph, gh → "ư" ("trw" → "trư").
  - Trường hợp khác → w là chữ thường.

  Chữ "ư" này mang cờ "w đứng riêng". Gõ w lần nữa thì nó trở lại chữ "w" (xem 3.3).
- **dd → đ** (`insertD`, bảng `_consonantD`): phím d thứ hai có thể đứng sau nguyên âm và phụ âm cuối, ví dụ "dinh" + `d` → "đinh", "did" → "đi". Có một luật lạ: d đứng sau một phụ âm khác luôn được nhận và còn **gỡ cờ tạm tắt xử lý** (`insertKey`, `handleMainKey`).
- **`[` → ơ, `]` → ư** (chỉ Telex). Gõ đúp `[[` hoặc `]]` cho ra ký tự ngoặc, và ngoặc được coi như ranh giới từ (khối xử lý cuối `vKeyHandleEvent`). "u" + `[` → "uơ". **Dấu không làm (D27)**: `[ ]` luôn là dấu câu, kết thúc từ.
- **w → qu không bao giờ kích hoạt ở Telex**: w đầu từ luôn bị đổi thành "ư" trước khi xét gõ tắt. Đổi lại nó (gõ `ww`) thì bật cờ tạm tắt, mà gõ tắt phụ âm lại yêu cầu cờ này tắt. Điều này khớp D23. Nhưng ở **Simple Telex 1** thì w→qu **có** kích hoạt (xem 3.5).

### 3.2 Phím dấu thanh s f r x j và z

- s sắc, f huyền, r hỏi, x ngã, j nặng. Phím dấu chỉ có tác dụng khi đuôi từ khớp một mẫu vần trong bảng `_vowelForMark`. Nếu không khớp thì nó là chữ thường ("b" + `s` → "bs").
- Đổi dấu: gõ phím dấu khác thì thay dấu cũ ("á" + `f` → "à").
- Phím dấu gõ được sau phụ âm cuối ("vieetj" → "việt"). Vị trí dấu tự tính lại sau mỗi phím (mục 3.6, 3.7).
- **Hạn chế dấu với âm cuối tắc** (`checkCorrectVowel`): không cho f, r, x khi vần kết thúc bằng c hoặc t ("tat" + `f` → "tatf"). Điều này **không áp dụng cho p**, nên "cap" + `f` → "càp". Xem lỗi B5.
- **z xoá dấu thanh** (`removeMark`). z chỉ xoá dấu thanh, không xoá mũ hay móc ("ấ" + `z` → "â"). Nếu không có dấu để xoá thì z là chữ thường ("a" + `z` → "az").

### 3.3 Gõ đúp để giữ chữ gốc, và sau khi gõ đúp

- Gõ lại cùng phím dấu (`insertMark`), cùng phím mũ (`insertAOE`), w (`insertW`) hoặc d (`insertD`) thì biến đổi bị bỏ và phím vừa gõ được thêm như chữ thường:
  - "as" + `s` → "as"; "car" + `r` → "car"; "â" + `a` → "aa"; "đ" + `d` → "dd";
  - "ư" (từ w đứng riêng) + `w` → "w" (chữ w thay chữ ư, phím w thứ hai bị nuốt); "ă" + `w` → "aw".
- Sau khi gõ đúp, **cờ tạm tắt xử lý được bật cho tới hết từ**: mọi phím biến đổi gõ sau đó đều là chữ thường.
  - "carr" + `s` → "cars" (cùng một từ). Khớp ví dụ trong D20, nhưng ở đây cơ chế là "cờ tạm tắt sau gõ đúp" (Dấu: D26), không phải D20 (D20 nói về bộ đệm rỗng). Xem M7.
  - "tess" + `t` → "test"; "sexx" → "sex"; "ddd" → "dd"; "aaa" → "aa"; "ww" → "w"; "www" → "ww".
- **Ngoại lệ "oo"**: "ô" + `o` → "oo" nhưng **không** bật cờ tạm tắt (ghi chú trong mã: dành cho "thoòng"). Vì thế "xooong" → "xoong", rồi gõ dấu tiếp vẫn được ("xooongf" → "xoòng").
- Bộ đệm phím gốc bị bớt một phím sau khi gõ đúp: nó ghi "car" chứ không phải "carr", nên lần khôi phục sau trả về đúng chữ đang hiển thị.
- **Dấu (D26)**: cùng luật. Sau gõ đúp, phím dấu đi thẳng tới hết từ ("carrs" → "cars"); áp dụng cho cả phím biến đổi ("aaa" → "aa", "ddd" → "dd", "ww" → "w") và VNI ("a11" → "a1"); ngoại lệ "ooo" → "oo" không khoá ("xooongf" → "xoòng").

### 3.4 VNI

- 1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng.
- 6 thêm mũ cho a/e/o **gần cuối từ nhất** ("toi" + `6` → "tôi").
- 7 thêm móc cho o/u, áp dụng cả cụm "uo" → "ươ".
- 8 thêm trăng cho a.
- 9 cho đ.
- 0 xoá dấu thanh.
- Gõ đúp số thì huỷ biến đổi giống Telex ("a11" → "a1").
- **Chữ số không vào được từ khi bộ đệm rỗng**: số gõ khi bộ đệm rỗng và Shift+số được coi là ranh giới từ (`vKeyHandleEvent`). Nhờ vậy "2024" đi thẳng. Số gõ giữa từ ở Telex là chữ thường và làm từ sai chính tả.
- w ở VNI là chữ thường, nên gõ tắt w→qu có tác dụng ("wen␣" → "quen␣").
- Lỗi đồng bộ khi 7 gặp "a" (không có "u" đứng trước), hoặc 8 gặp "o"/"u": engine đánh dấu là "đã xử lý" nhưng không đổi gì và không ghi phím vào bộ đệm, trong khi phím vẫn đi thẳng ra ứng dụng. Từ đó màn hình và bộ đệm lệch nhau (lỗi B13, suy luận).

### 3.5 Simple Telex (Telex đơn giản): định nghĩa chính xác theo mã

OpenKey có **hai** biến thể. Phím dấu, aa/ee/oo, aw/ow/uw, dd và z giống hệt Telex (cùng hàng trong bảng `ProcessingChar`). Chỉ khác ở các điểm sau:

| | Telex | Simple Telex 1 | Simple Telex 2 |
|---|---|---|---|
| `[` → ơ, `]` → ư | có | không (ngoặc là ký tự thường và kết thúc từ) | không (như ST1) |
| w đứng riêng → ư ("w" → "ư", "tw" → "tư", "wa" → "ưa") | có | **không**: w chỉ biến đổi khi đứng sau a/o/u, nếu không thì là chữ w | có |
| w → qu khi bật gõ tắt phụ âm đầu | không bao giờ (3.1) | **có** ("wen␣" → "quen␣"), vì w đầu từ còn nguyên là w | không |

Mã không có khác biệt nào khác (đã tìm mọi nhánh theo kiểu gõ trong `Engine.cpp` và `DataType.h`).

Bộ gõ "Telex đơn giản" có sẵn của macOS hoạt động ra sao thì **chưa kiểm chứng**: không tìm thấy tài liệu Apple mô tả. Cần người dùng gõ thử trên máy.

**Dấu (đã chốt, D29):** "Telex đơn giản" = Telex trừ hai điểm: w chỉ biến đổi khi đứng sau a, o, u (aw, ow, uw), ở chỗ khác w là chữ w ("web", "www"); không có `[ ]` (D27). Không có gõ tắt w → qu (D23 chỉ VNI). Như vậy Dấu theo Simple Telex 1 nhưng **bỏ** w → qu mà Simple Telex 1 của OpenKey có.

D29 đã sửa câu chữ (29/10/2026): w biến đổi khi trong từ có a, o, u, không cần đứng sát (D28), giống Simple Telex 1 của OpenKey ("tuongw" → "tương").

### 3.6 Đặt dấu kiểu mới / kiểu cũ

Hàm `handleModernMark` và `handleOldMark`. Engine bỏ "u" sau "q" và "i" sau "g" ra khỏi cụm nguyên âm (`findAndCalculateVowel`). Nhờ vậy "quý", "quá", "giá", "giữa" chỉ còn một hoặc hai nguyên âm thật. Riêng "gi" + dấu ("gì") đi qua một nhánh đặc biệt, khi số nguyên âm đếm được bằng 0.

**Kiểu mới**, diễn đạt lại:
- Một nguyên âm: dấu đặt lên chính nó.
- Cụm ba nguyên âm oai, oeo, uyu, uya: dấu ở giữa.
- oi, ai, ui, ay: dấu ở chữ đầu.
- Cụm có chữ thứ hai là o/u (ao, au, eo, iu, ưu…): dấu ở chữ đầu.
- Cụm bắt đầu bằng o/u (oa, oe, uy, uê…): dấu ở chữ sau. Đây là chỗ khác kiểu cũ: **hoà, hoè, thuý**.
- iê, yê, uô, ươ: dấu ở chữ thứ hai nếu sau đó còn phụ âm cuối hoặc nguyên âm ("việt", "người", "khuyến").
- ia, iu, io: dấu ở chữ đầu ("kìa"). ua không có q đứng trước và không có phụ âm cuối: dấu ở chữ đầu ("mùa", "cửa"). Có q thì dấu ở chữ sau ("quá").
- oo: dấu ở chữ cuối ("xoòng").

**Kiểu cũ**:
- Mặc định dấu ở nguyên âm đầu của cụm.
- Cụm ba nguyên âm, hoặc cụm có phụ âm cuối mà vần cho phép phụ âm cuối: dấu ở chữ thứ hai ("hoàng", "thuyền").
- Cụm có ê hoặc ơ: dấu luôn ở chữ đó.
- Kết quả: **hòa, hòe, thúy**.

Hai kiểu chỉ khác nhau ở oa, oe, uy **khi không có phụ âm cuối**. Có phụ âm cuối thì giống nhau ("hoàng", "thuyết").

Điểm lạ trong mã: xem B2, B3, B4.

### 3.7 Bỏ dấu tự do

- Sau **mỗi** phím, nếu bộ đệm có dấu thanh thì engine gỡ dấu ra và đặt lại theo cụm nguyên âm hiện tại (`checkGrammar`). Ví dụ "ho" + `f` → "hò", gõ tiếp `a` → "hoà" (kiểu mới). Nhờ vậy người dùng gõ dấu ở bất kỳ đâu sau nguyên âm đầu, kể cả sau phụ âm cuối, và dấu vẫn vào đúng chỗ.
- Biến `vFreeMark` trong engine có nghĩa **ngược** với cái tên: bật nó thì engine **không** đặt lại dấu ("dấu ở đâu để đó"). Ở bản macOS, `OpenKey.mm` luôn gán 0 khi khởi động, bỏ qua giá trị đã lưu. Nghĩa là trên thực tế dấu luôn được tự đặt lại, còn nút "FreeMark" trong cửa sổ chỉ có tác dụng tới lần mở app sau (B18).
- **Dấu (đã chốt, D28):** bật thì phím dấu thanh gõ ở bất kỳ đâu sau nguyên âm đầu, kể cả sau phụ âm cuối; dấu tự vào đúng nguyên âm và tự dời khi gõ thêm nguyên âm ("hof" + a → "hoà"). Phím d sau nguyên âm vẫn biến d đầu từ thành đ ("did" → "đi"). Tắt thì phím dấu chỉ có tác dụng khi gõ ngay sau nguyên âm (dấu đã đặt vẫn tự dời khi gõ thêm nguyên âm) và d → đ chỉ khi hai d liền nhau. Đây là nghĩa (a) ở M2, khác nghĩa biến `vFreeMark` của OpenKey.

### 3.8 Kiểm tra chính tả âm tiết

Hàm `checkSpelling`, chạy sau mỗi phím được thêm như chữ thường. Khi nhấn Space hoặc phím kết thúc từ, nó chạy thêm ở chế độ "ép", có kiểm tra tổ hợp nguyên âm.

- **Phụ âm đầu hợp lệ**: ngh, ph, th, tr, gi, ch, nh, ng, kh, gh, g, c, q, k, t, r, h, b, m, v, n, l, x, p, s, d (và đ). Thêm f, w, z, j khi bật "cho phép zfwj", hoặc f, w, j khi bật gõ tắt phụ âm đầu.
- **Nguyên âm**: tối đa 3 chữ liên tiếp. Ở chế độ ép, cụm từ hai chữ trở lên phải nằm trong bảng `_vowelCombine`. Mỗi mục trong bảng có cờ "được/không được có phụ âm cuối" (ví dụ ưa, ia, ai, ao không có phụ âm cuối; oa, uyê, iê, uô có). Nguyên âm đơn thì không kiểm tra gì.
- **Phụ âm cuối hợp lệ**: c, ch, m, n, ng, nh, p, t. Thêm g, h, k khi bật gõ tắt phụ âm cuối.
- **Ràng buộc dấu**: vần kết thúc bằng "t" hoặc "ch" không được mang huyền, hỏi, ngã.

Engine **không** kiểm tra:
- phân bố c/k/q, g/gh, ng/ngh theo nguyên âm sau ("ka", "ce", "ghu", "ngi" đều lọt);
- p cuối với huyền/hỏi/ngã, và c cuối khi phím dấu gõ trước phụ âm cuối (B5);
- ă/â đứng một mình không có phụ âm cuối ("ă", "â" lọt);
- âm tiết tắc (p/t/c/ch) không có dấu thanh.

Xem B5, B6. **Dấu:** kiểm tra chính tả luôn chạy, không có công tắc riêng; khi từ đã sai thì ngừng biến đổi (D30). Định nghĩa âm tiết hợp lệ theo chính tả chuẩn (D31): thêm "p" đầu từ; áp phân bố c/k/q, g/gh, ng/ngh; bảng vần Dấu tự lập; vần p, t, c, ch chỉ mang sắc hoặc nặng, không dấu là không hợp lệ; ă, â không đứng cuối âm tiết.

### 3.9 Khôi phục khi sai chính tả (Restore if wrong spelling)

- Chỉ hoạt động khi bật cả kiểm tra chính tả. Diễn ra khi nhấn Space (`vKeyHandleEvent`, nhánh Space) hoặc một phím ranh giới từ (mục 3.16).
- Nếu cờ tạm tắt đang bật (từ sai chính tả, hoặc vừa gõ đúp), engine thay cả từ bằng chuỗi phím gốc, rồi tầng macOS gõ thêm phím vừa nhấn. Ví dụ "Hasaki␣": trong lúc gõ hiện "Hấki", nhấn Space thì thành "Hasaki␣".
- **Điều kiện ẩn** (`checkRestoreIfWrongSpelling`): chỉ khôi phục nếu **có ít nhất một nguyên âm** đang mang dấu thanh, mũ hoặc móc. Từ sai chính tả mà chỉ bị đổi phụ âm (đ, Quick Telex) thì **không** được khôi phục (B7).
- Từ trùng giữa Anh và Việt (car → cả, sex → sẽ, test → tét, as → á, has → há) là tiếng Việt hợp lệ nên không bị khôi phục. Kết quả này khớp D4.
- Khi đã gõ đúp thì không có gì để khôi phục, vì chữ trên màn hình đã là chữ gốc.

### 3.10 Quick Telex (gõ nhanh)

- Gõ hai lần c, g, k, n, q, p hoặc t thì ra ch, gi, kh, ng, qu, ph, th (`handleQuickTelex`). Bảng có cả uu → ươ nhưng không bao giờ được dùng, vì u không nằm trong danh sách phím kích hoạt.
- Kích hoạt **ở bất kỳ vị trí nào trong từ**, không chỉ ở đầu từ: "conn" → "cong", "matt" → "math". Vì thế nó phá các từ tiếng Anh có phụ âm đôi, và theo B7 các từ này cũng không được khôi phục ("connect" → "congect").
- Chữ hoa của chữ đầu bị lấy theo phím thứ hai (B14).
- **Dấu không làm** (DECISIONS, mục "Đã cân nhắc và loại bỏ"). Gõ tắt phụ âm (D21) là tính năng **khác**.

### 3.11 Gõ tắt phụ âm (quick start / end consonant): so với D21, D23

- Hàm `checkQuickConsonant`. Chỉ chạy khi từ có từ 2 chữ trở lên:
  - Đầu từ: f → ph, j → gi, w → qu.
  - Cuối từ: g → ng, h → nh, k → ch, nếu chữ đứng trước là nguyên âm.
  - Chữ hoa: chữ thứ hai của phụ âm mở rộng chỉ viết hoa khi cả chữ gốc lẫn chữ kế tiếp đều hoa ("Fan" → "Phan", "FAN" → "PHAN"). Phụ âm cuối lấy kiểu hoa của chữ gốc. Dấu nên làm theo quy tắc này.
- **Thời điểm chạy**: khi nhấn Space, và cả khi nhấn Return , . / ; ' \ - = (`_macroBreakCode`). Không chạy với Tab, Esc, mũi tên. Dấu: chạy khi kết thúc từ theo ranh giới D4, tức Space, Enter, Tab và mọi dấu câu (D21 đã sửa).
- **Thứ tự** (nhánh Space trong `vKeyHandleEvent`): macro, rồi gõ tắt phụ âm, rồi khôi phục. Đây là chuỗi "nếu không thì", nên gõ tắt chạy được thì bước khôi phục bị bỏ.
- Trong lúc gõ, bật gõ tắt sẽ **nới lỏng kiểm tra chính tả**: f, j, w được coi là phụ âm đầu hợp lệ, còn g, h, k là phụ âm cuối hợp lệ. Hệ quả: "big" qua được kiểm tra, rồi nhấn Space thì thành "bing", dù "bing" không phải âm tiết tiếng Việt. Đúng như D21 mô tả. Sau khi mở rộng, OpenKey không kiểm tra lại.
- Trong lúc gõ, chữ hiện chưa mở rộng ("fán"). Phụ âm chỉ được thay khi nhấn Space ("fans␣" → "phán␣").
- Ở **Telex** không bao giờ có w → qu (3.1). Ở **Simple Telex 1** và VNI thì có.
- **Dấu (D21)**: mở rộng xong thì kiểm tra lại. Hợp lệ thì giữ, không hợp lệ thì khôi phục phím gốc theo D4: "big␣" → "big␣", "bag␣" → "bang␣", "fan␣" → "phan␣", "fan," → "phan,". Thêm:
  - Từ tiếng Anh mở rộng ra âm tiết hợp lệ vẫn bị đổi và được chấp nhận: "fix␣" → "phĩ␣" (x là phím ngã), ghi rõ trong test (D21).
  - Trong lúc gõ, f, j đầu từ và g, h, k cuối từ là phụ âm tạm hợp lệ để phím dấu có tác dụng ("fanf" hiện "fàn", kết thúc từ ra "phàn") (D21).
  - "bak␣" → "bak␣": "bach" không dấu không hợp lệ theo D31.

### 3.12 Cho phép phụ âm z, f, w, j

- Chỉ tác động lên kiểm tra chính tả (cho phép làm phụ âm đầu), không đổi chữ nào.
- Ở Telex, w đầu từ vẫn bị đổi thành "ư" trước khi xét chính tả, nên **"cho phép w" không có tác dụng ở Telex**. Tuỳ chọn này chỉ có tác dụng với w ở VNI và Simple Telex 1.
- z vẫn là phím xoá dấu: z đầu từ không có dấu để xoá nên thành chữ z. "za" + `s` → "zá" khi bật.
- OpenKey cho bật cùng lúc với gõ tắt phụ âm. Khi đó f/j/w hợp lệ ở cả hai đường và gõ tắt vẫn chạy trước. Dấu cho hai tuỳ chọn loại trừ nhau (D22), và giao diện ghi chú "cho phép w" không có tác dụng khi đang dùng Telex (D22).

### 3.13 Chữ hoa, Caps Lock

- Mỗi chữ trong bộ đệm có cờ hoa riêng. Shift hoặc Caps Lock đều cho chữ hoa. Shift cùng Caps Lock vẫn ra hoa, không đảo về thường.
- Phím biến đổi (aa, w, dd, phím dấu) **không** đổi kiểu hoa của chữ bị biến đổi: chữ giữ kiểu hoa của chính nó.
  - "Dd" → "Đ"; "dD" → "đ"; "VIEETJ" → "VIỆT"; "Vieetj" → "Việt".
  - Riêng w đứng riêng thì lấy kiểu hoa của chính phím w ("W" → "Ư").
- Khi khôi phục, chữ hoa giữ nguyên như đã gõ ("Hasaki").
- Lỗi phân biệt hoa thường: B4 ("thuowr" → "thuở" nhưng "THUOWR" → "THƯỞ"), B14.

### 3.14 Chữ số

- Telex: số gõ giữa từ là chữ thường, làm từ sai chính tả, các phím sau đó đi thẳng.
- Số gõ khi bộ đệm rỗng, và Shift+số, là ranh giới từ.
- VNI: xem 3.4.

### 3.15 Từ dài

- Bộ đệm giới hạn 32 phần tử. Quá giới hạn thì bộ đệm dịch trái và lưu phần đầu ra một danh sách phụ (`insertKey`, `_longWordHelper`). Bộ đệm phím gốc cũng dịch trái, nhưng theo nhịp riêng.
- Khôi phục từ dài hơn 32 ký tự vì thế có thể sai (B15, suy luận).
- **Dấu (đã chốt, D33):** từ dài hơn âm tiết dài nhất (7 chữ cái, như "nghiêng") thì ngừng biến đổi; bộ đệm có dung lượng cố định, không cấp phát thêm. Ngưỡng tính theo chữ cái, không theo số phím.

### 3.16 Space, dấu câu và ranh giới từ

Lấy từ `_breakCode` và nhánh đầu của `vKeyHandleEvent`.

- **Ranh giới từ có kèm khôi phục**:
  - Space;
  - Esc, Tab, Enter, Return;
  - 4 phím mũi tên;
  - các phím , . / ; ' \ - = và phím dấu huyền ngược (backtick) (kể cả khi giữ Shift: ? : " | _ + ~ < >);
  - nhấn chuột (chỉ reset, vì tầng macOS bỏ qua kết quả trả về).
- **Ranh giới từ không kèm khôi phục**: Shift+số (! @ # $ % ^ & * ( )) và mọi tổ hợp có ⌘, ⌃, ⌥, Fn. Ví dụ "Hasaki!" vẫn là "Hấki!" (B10).
- `[` và `]` ở Telex là phím biến đổi. Ở Simple Telex chúng kết thúc từ, nhưng không khôi phục.
- Space không reset bộ đệm ngay. Nó đếm số dấu cách để Backspace có thể quay lại (3.17). Từ mới chỉ bắt đầu khi gõ chữ tiếp theo.
- Khôi phục kích hoạt bởi phím không in ra ký tự (Tab, mũi tên…): tầng macOS gõ chuỗi khôi phục rồi gửi lại chính phím đó.
- **Dấu (đã chốt, D4 phần "Ranh giới từ"; D21):**
  - Khôi phục (D4) và gõ tắt phụ âm (D21) chạy ở **mọi ký tự kết thúc từ có in ra**: Space, Enter, Tab và **mọi** dấu câu/ký hiệu, kể cả ! ? ( ) " ("Hasaki!" → "Hasaki!").
  - Mũi tên, Esc, click chuột và tổ hợp ⌘/⌃/⌥ chỉ reset bộ đệm, **không** khôi phục, vì lúc đó con trỏ có thể đã đi chỗ khác.

### 3.17 Backspace và lịch sử từ

- Backspace bỏ một chữ hiển thị khỏi bộ đệm và một phím khỏi bộ đệm phím gốc, rồi kiểm tra chính tả và đặt lại dấu (`checkGrammar`). Ví dụ "hoà" ⌫ → "ho", dấu chuyển về "hò".
- Bỏ một chữ hiển thị nhưng chỉ bỏ một phím gốc: với chữ được tạo từ nhiều phím ("ệ" = e, e, j) thì hai bộ đệm lệch nhau (suy luận).
- Khi bộ đệm rỗng, hoặc khi Backspace xoá dấu cách/ký tự ngắt vừa gõ, engine lấy từ trước đó ra khỏi lịch sử để sửa tiếp. Ví dụ "viet␣" ⌫ rồi `j` → "việt". Lịch sử bị xoá khi gặp Enter, Tab, mũi tên, Esc, chuột hoặc tổ hợp phím.
- Lấy từ trong lịch sử ra thì **chỉ khôi phục bộ đệm chữ, không khôi phục phím gốc**. Khôi phục sau đó có thể xoá cả từ mà chỉ ghi lại các phím mới gõ (B12, suy luận).
- **Dấu (D32, D20):** Backspace bỏ chữ cuối đang hiển thị và đặt lại dấu ("hoà" ⌫ → "hò"); từ đó mốc khôi phục là chữ đang hiển thị, không giữ phím gốc cũ. Không làm lịch sử từ: lùi về sau một từ rồi gõ phím dấu đã được D20 phủ.
- OpenKey **không có tương đương** của "Thêm dấu cho từ đã gõ" (D20): khi bộ đệm rỗng (sau khi click vào chữ có sẵn), phím dấu chỉ là chữ thường ("hoc" + `j` → "hocj"). Lịch sử từ ở trên chỉ phủ trường hợp từ vừa gõ qua bộ gõ và lùi bằng Backspace.

### 3.18 Mũi tên, chuột, tổ hợp phím

Tất cả đều reset bộ đệm. Mũi tên thì còn khôi phục (3.16). Chuột nhấn hoặc kéo đều reset. Tổ hợp có ⌘/⌃/⌥ reset bộ đệm. Riêng tổ hợp mà phím chính là dấu câu (⌘, chẳng hạn) thì còn chạy khôi phục (B11, suy luận).

### 3.19 Smart switch (nhớ chế độ theo ứng dụng)

- Lưu Việt/Anh (cùng bảng mã) theo bundle ID. Ứng dụng gặp lần đầu được ghi theo chế độ hiện tại, và mỗi lần người dùng đổi chế độ thì cập nhật cho ứng dụng đang dùng (`SmartSwitchKey.cpp`; `OpenKey.mm`, phần đổi ứng dụng).
- Độ dài bundle ID lưu trong 1 byte, nên ID dài hơn 255 bị cắt (lỗi nhỏ).
- Dấu: D5 (quy tắc riêng luôn thắng, "Nhớ chế độ" mặc định tắt). Chuyển chế độ qua input mode của hệ thống (D2), không tự đổi biến toàn cục.

### 3.20 Macro, viết hoa đầu câu, bảng mã, chuyển mã

- **Macro**: tra cụm vừa gõ khi gặp Space hoặc dấu câu. Có tuỳ chọn tự viết hoa theo kiểu gõ ("Btw" → "By the way", "BTW" → "BY THE WAY") và có thể chạy cả ở chế độ Anh. Dấu không làm (D3, vì macOS đã có Thay thế văn bản).
- **Viết hoa đầu câu**: viết hoa chữ đầu sau ". " hoặc Enter. Không làm (D3).
- **Bảng mã** TCVN3, VNI-Windows, Unicode tổ hợp, CP1258 và công cụ chuyển mã: không làm (D3), chỉ xuất NFC.

---

## 4. Lỗi và điểm lạ tìm thấy

Mọi mục đều từ đọc mã. Mục có ghi "(suy luận)" chưa được chạy thử để xác nhận. Đây là danh sách để Dấu **tránh**, không phải để sửa OpenKey.

- **B1.** `checkForStandaloneChar` (Engine.cpp): khi w, `[` hoặc `]` là phím đầu tiên của từ, hàm đọc phần tử **ngay trước đầu mảng** bộ đệm. Đây là hành vi không xác định trong C++. Kết quả thường vẫn đúng chỉ vì nhánh xử lý bộ đệm rỗng chạy sau đó.
- **B2.** `handleModernMark`, nhánh iê/yê: dùng phép AND bit giữa phần tử bộ đệm và mã phím "e kèm cờ mũ" thay cho phép so bằng. Điều kiện vì thế đúng với cả những chữ có mã phím trùng bit với e (ví dụ o). Hậu quả thực tế được che bởi các luật chạy sau (suy luận).
- **B3.** `handleModernMark`: hai nhóm điều kiện **luôn sai**, vì chúng so cùng một vị trí với hai chữ khác nhau. Đó là phần "ch/nh/ng sau iê" và nhóm "ia/ya/ua" ở luật 3.2. Kết quả đúng là nhờ các luật khác. Mã chết, dễ gây hiểu nhầm khi đọc.
- **B4.** `insertW`: kiểm tra "th" và "q" đứng trước "uo" bằng cách so cả giá trị kèm cờ hoa, nên chữ hoa không khớp: "thuowr" → "thuở" nhưng "THUOWR" → "THƯỞ". Ngoài ra chỉ "th" được ngoại lệ: "huow" → "hươ" thay vì "huơ" (huơ tay). Dấu nên dùng luật: "uo" + w, không có phụ âm cuối và không có nguyên âm theo sau → "uơ"; có phụ âm cuối hoặc i/u theo sau → "ươ" (đề xuất).
- **B5.** Ràng buộc dấu với âm cuối tắc không nhất quán.
  - Lúc gõ phím dấu, `checkCorrectVowel` chặn f/r/x khi vần kết thúc bằng c, t hoặc ch, nhưng không chặn với p. Vì thế "capf" → "càp" và "capr" → "cảp" lọt.
  - Nếu phím dấu gõ **trước** phụ âm cuối, chỉ còn `checkSpelling` kiểm tra, mà hàm này chỉ chặn t và ch. Vì thế "carc" → "cảc" lọt (suy luận).

  Chính tả đúng: vần tắc p, t, c, ch chỉ mang sắc hoặc nặng.
- **B6.** Không kiểm tra phân bố c/k/q, g/gh, ng/ngh, và ă/â đứng một mình (3.8).
- **B7.** Chỉ khôi phục khi có nguyên âm mang dấu/mũ/móc. Từ sai chính tả mà chỉ có đ, hoặc chỉ bị Quick Telex đổi, thì giữ nguyên chữ đã biến đổi. Ví dụ "pdd␣" → "pđ␣" (suy luận). Với Quick Telex: "connect␣" → "congect␣".
- **B8.** Khi bật gõ tắt phụ âm, nhánh xử lý dấu câu (, . / …) gọi gõ tắt **thay vì** kiểm tra chính tả ở chế độ ép. Từ có tổ hợp nguyên âm sai mà theo sau là dấu phẩy sẽ không được khôi phục, trong khi theo sau là Space thì có (suy luận).
- **B9.** Gõ tắt phụ âm chạy trước và chặn khôi phục. Kiểm tra chính tả bị nới lỏng nên kết quả không hợp lệ vẫn được giữ: "big" → "bing" (D21 đã ghi).
- **B10.** Tập phím kết thúc từ không nhất quán: "Hasaki," được khôi phục, "Hasaki!" thì không (3.16).
- **B11.** Tổ hợp ⌘ với phím dấu câu (⌘, ⌘. ⌘/) sau một từ sai chính tả vẫn chạy khôi phục và gõ thêm ký tự dấu câu, trong khi phím tắt gốc có thể bị nuốt (suy luận từ `vKeyHandleEvent` và `OpenKeyCallback`).
- **B12.** Lấy từ trong lịch sử ra (Backspace qua dấu cách) không khôi phục bộ đệm phím gốc. Ví dụ: gõ "nhaf␣x", ⌫ ⌫ để về "nhà", gõ `k` rồi Space. Khôi phục xoá "nhàk" nhưng chỉ ghi lại "k", mất chữ (suy luận). Bài học cho D20: khi sửa một từ không có phím gốc, mốc để khôi phục phải là **chữ đang hiển thị + phím mới gõ**.
- **B13.** VNI: 7 sau "a", hoặc 8 sau "o"/"u", làm bộ đệm lệch với màn hình (3.4, suy luận). Ví dụ "a71" có thể cho kết quả mất ký tự.
- **B14.** Quick Telex: "Cc" → "ch" (mất chữ hoa), trong khi bộ đệm vẫn ghi "Ch" (suy luận).
- **B15.** Từ dài hơn 32: bộ đệm chữ và bộ đệm phím dịch theo nhịp khác nhau, khôi phục có thể sai vùng (suy luận).
- **B16.** Trạng thái toàn cục, dùng chung cho mọi ứng dụng. Các bảng toàn cục còn bị **ghi thêm khoá rỗng** ngay trên đường nóng, vì tra bằng toán tử `[]` của `std::map` (`checkSpelling`, `canHasEndConsonant`). Không an toàn đa luồng.
- **B17.** Engine dựa trên mã phím vật lý, nên sai với bố cục không phải QWERTY nếu không bật "layout compat".
- **B18.** Nút FreeMark lưu được giá trị nhưng app luôn ghi đè 0 khi khởi động (3.7).
- **B19.** Luật "d sau phụ âm" gỡ cờ tạm tắt xử lý, làm từ đã sai có thể bị biến đổi tiếp. Ví dụ "pd" + `d` → "pđ". Không rõ mục đích.

## 5. Ghi chú API Apple liên quan (cho M2, M3)

Nguồn chính thức. Header SDK đọc trong Xcode 27.1, `MacOSX27.0.sdk`.

- `IMKServerInput.handle(_:client:)`: tham số `NSEvent!` và `Any!` (kiểu tự mở có thể nil). Trả `true` nếu đã xử lý sự kiện, `false` để hệ thống xử lý. Phương thức nhận cả sự kiện phím xuống lẫn chuột, nên chuột là tín hiệu reset (D11). Tham số có thể nil cũng là cơ sở cho D18. https://developer.apple.com/documentation/objectivec/nsobject-swift.class/handle(_:client:) và https://developer.apple.com/documentation/inputmethodkit/imkserverinput
- `NSEvent.characters` **ném `NSInternalInconsistencyException`** nếu đọc trên sự kiện không phải phím. Với phím chết (dead key, ví dụ ⌥e) nó là chuỗi rỗng. Phải kiểm tra loại sự kiện trước khi đọc (D18). https://developer.apple.com/documentation/appkit/nsevent/characters
- `NSEvent.keyCode` là mã phím ảo, không phụ thuộc phần cứng. Còn `characters` được suy ra từ bảng ánh xạ bàn phím. Dấu dùng ký tự thay cho mã phím để tránh B17. https://developer.apple.com/documentation/appkit/nsevent/keycode
- `IMKTextInput` (header `HIToolbox.framework/Headers/IMKInputSession.h`; trang tài liệu web của protocol này trả 404 khi tra):
  - `insertText(_:replacementRange:)`: `replacementRange` tính từ đầu tài liệu của client. Truyền `NSNotFound` thì chèn tại vùng chọn hiện tại. **Nếu client không hỗ trợ TSMDocumentAccess thì `replacementRange` bị bỏ qua.** Đây là dữ kiện trực tiếp cho câu hỏi mở A/B và cho D13: ở các ứng dụng như vậy, thay chữ tại chỗ không thể đúng, cần marked text.
  - `selectedRange()` trả `{NSNotFound, NSNotFound}` nếu client không hỗ trợ TSMDocumentAccess.
  - `attributedSubstring(from:)` có thể trả chuỗi dài hơn hoặc ngắn hơn phạm vi yêu cầu khi phạm vi cắt ngang một cặp surrogate. "Thêm dấu cho từ đã gõ" (D20) phải kiểm tra độ dài.
  - `setMarkedText(_:selectionRange:replacementRange:)`: chuỗi thường sẽ có gạch chân mặc định (D13).
  - `overrideKeyboard(withKeyboardNamed:)`: input method có thể chỉ định bố cục bàn phím dùng để dịch phím, và "nên gọi mỗi lần được kích hoạt". Suy luận, cần kiểm chứng ở M2: nếu không gọi thì ký tự Dấu nhận được theo bố cục nào, và người dùng Dvorak gõ Telex ra sao.
- `IMKStateSetting.recognizedEvents(_:)` quyết định loại sự kiện bộ gõ nhận được. Nếu cần biết Shift/Caps riêng thì phải xét mask này (suy luận). https://developer.apple.com/documentation/inputmethodkit/imkstatesetting
- `NSTextInputClient.insertText(_:replacementRange:)` (phía ứng dụng): "chỉ phù hợp cho văn bản do người dùng gõ" và yêu cầu view cho phép sửa. https://developer.apple.com/documentation/appkit/nstextinputclient/inserttext(_:replacementrange:)
- Phạm vi `NSRange` tính theo đơn vị UTF-16. Chữ Việt dựng sẵn (NFC) đều nằm trong BMP nên một chữ = một đơn vị. Nhưng nếu ứng dụng lưu chữ ở dạng tổ hợp (NFD) thì số đơn vị khác số chữ, và `deleteCount` của engine phải đổi cho đúng (suy luận, cần kiểm chứng ở M2/M3).

---

## 6. Ca biên đề xuất cho bộ test

Kết quả mong đợi viết theo chính tả tiếng Việt và DECISIONS.md, **không** lấy từ OpenKey (D10). Cấu hình mặc định theo D15: Telex, kiểu mới, bỏ dấu tự do bật, tự khôi phục bật, nâng cao tắt. Dòng nào khác cấu hình mặc định thì ghi rõ.

Cột "So với OpenKey" theo ba mức:
- **Khác (cố ý)**: Dấu cố ý khác OpenKey.
- **Chờ chốt**: không còn ca nào (`dD` → D34, `duo7c59` → D28, chốt 29/10/2026).
- Ca do phiên chính thêm theo các quyết định mới gom ở 6.9 (đã duyệt 29/10/2026).
- Bỏ trống: kết quả được dự đoán là giống OpenKey.

Cột "Ghi chú" dẫn số quyết định khi kết quả do quyết định đó định ra.

### 6.1 Nhóm từ trùng Anh–Việt và khôi phục (D4)

| Chuỗi phím | Mong đợi | Ghi chú | So với OpenKey |
|---|---|---|---|
| `car␣` | `cả␣` | tiếng Việt thắng | |
| `carr␣` | `car␣` | gõ đúp giữ chữ gốc | |
| `carrs␣` | `cars␣` | sau gõ đúp, phần còn lại của từ là chữ thường (D26) | |
| `sex␣` | `sẽ␣` | | |
| `sexx␣` | `sex␣` | | |
| `has␣` | `há␣` | | |
| `as␣` | `á␣` | | |
| `ass␣` | `as␣` | | |
| `test␣` | `tét␣` | "tét" hợp lệ (t cuối + sắc) | |
| `tesst␣` | `test␣` | | |
| `windows␣` | `windows␣` | không hợp lệ → khôi phục | |
| `Hasaki␣` | `Hasaki␣` | giữ chữ hoa như đã gõ | |
| `Hasaki,` | `Hasaki,` | | |
| `Hasaki!` | `Hasaki!` | mọi dấu câu là ranh giới từ (D4) | **Khác (cố ý)**. OpenKey: "Hấki!" |
| `vieetj␣` | `việt␣` | | |
| `did␣` (bỏ dấu tự do bật) | `đi␣` | d sau nguyên âm biến d đầu từ thành đ; "đi" hợp lệ nên tiếng Việt thắng (D28, D4) | |
| `pdd␣` | `pdd␣` | "pđ" không hợp lệ → khôi phục | Khác (cố ý), B7, B19 |

### 6.2 Phím biến đổi Telex và gõ đúp

| Chuỗi phím | Mong đợi | Ghi chú | So với OpenKey |
|---|---|---|---|
| `dd` | `đ` | | |
| `ddd` | `dd` | D26 | |
| `ddi` / `did` | `đi` | (`did`: xem 6.1) | |
| `aa` / `aaa` | `â` / `aa` | | |
| `ee`, `oo` | `ê`, `ô` | | |
| `aw`, `ow`, `uw` | `ă`, `ơ`, `ư` | | |
| `aww` | `aw` | | |
| `w` | `ư` | w đứng riêng | |
| `ww` | `w` | D26 | |
| `wa` | `ưa` | Telex (D23), kể cả khi bật gõ tắt phụ âm | |
| `tw` / `trw` | `tư` / `trư` | | |
| `aaw` | `ă` | w thay mũ bằng trăng | |
| `asz` | `a` | z xoá dấu | |
| `az` | `az` | không có dấu để xoá | |
| `asf` | `à` | đổi dấu | |
| `xooong␣` | `xoong␣` | ooo → oo, vẫn gõ dấu được (`xooongf` → `xoòng`) (D26) | |
| `uow` | `uơ` | D35: cặp đứng cuối từ ("huơ", "thuở"); gõ tiếp thì thành ươ (`uown` → `ươn`) | |
| `tuwongf` | `tường` | ưo + phụ âm cuối → ươ | |
| `thuowr` | `thuở` | | |
| `THUOWR` | `THUỞ` | | Khác (cố ý), B4 |
| `huow` | `huơ` | | Khác (cố ý), B4 |
| `huowu` | `hươu` | | |
| `nguoiwf` | `người` | | |
| `nguwowif` | `người` | | |
| `dduowcj` | `được` | | |
| `truwowngf` | `trường` | | |

### 6.3 Đặt dấu

| Chuỗi phím | Mới | Cũ | Ghi chú |
|---|---|---|---|
| `hoaf` | `hoà` | `hòa` | D15 |
| `hoef` | `hoè` | `hòe` | |
| `khoer` | `khoẻ` | `khỏe` | |
| `thuys` | `thuý` | `thúy` | |
| `quys` | `quý` | `quý` | u sau q không tính là nguyên âm |
| `hoangf` | `hoàng` | `hoàng` | có phụ âm cuối thì hai kiểu như nhau |
| `thuyeenf` | `thuyền` | `thuyền` | |
| `quyeets` | `quyết` | `quyết` | |
| `gias` | `giá` | `giá` | |
| `gif` | `gì` | `gì` | |
| `ginf` | `gìn` | `gìn` | |
| `giuwax` | `giữa` | `giữa` | |
| `muaf` | `mùa` | `mùa` | |
| `cuwar` | `cửa` | `cửa` | |
| `quas` | `quá` | `quá` | |
| `kiaf` | `kìa` | `kìa` | |
| `hoaif` | `hoài` | `hoài` | |
| `khuyur` | `khuỷu` | `khuỷu` | cụm ba nguyên âm uyu: dấu ở giữa (y) |
| `ho` `f` `a` (gõ dấu trước khi đủ nguyên âm) | `hoà` | `hòa` | dấu tự đặt lại (bỏ dấu tự do) |
| `vieejt` | `việt` | `việt` | dấu gõ trước phụ âm cuối |

### 6.4 Chữ hoa, chữ số, từ dài

| Chuỗi phím | Mong đợi | So với OpenKey |
|---|---|---|
| `VIEETJ` | `VIỆT` | |
| `Vieetj` | `Việt` | |
| `Dd` / `DD` | `Đ` | |
| `dD` | `đ` (phím biến đổi không đổi kiểu hoa) | D34 |
| `W` | `Ư` | |
| `a1␣` (Telex) | `a1␣` | |
| `2024␣` (VNI) | `2024␣` | |
| `a1` (VNI) | `á` | |
| `a11` (VNI) | `a1` (D26) | |
| `a71␣` (VNI) | `a71␣` | Khác (cố ý), B13 |
| `toi6` (VNI) | `tôi` | |
| `d9uo7c5` (VNI) | `được` | |
| `duo7c59` (VNI, 9 gõ sau cùng) | `được` | D28 (VNI 9 không cần đứng sát) |
| `supercalifragilistic␣` | giữ nguyên | |
| từ 40 chữ cái bất kỳ + `␣` | giữ nguyên, không mất chữ (D33) | Khác (cố ý), B15 |

### 6.5 Gõ tắt phụ âm (bật Nâng cao → Gõ tắt phụ âm)

| Chuỗi phím | Mong đợi | Ghi chú | So với OpenKey |
|---|---|---|---|
| `fan␣` | `phan␣` | | |
| `Fan␣` / `FAN␣` | `Phan␣` / `PHAN␣` | | |
| `fanf␣` | `phàn␣` | trước khi nhấn Space hiện `fàn` (D21) | |
| `big␣` | `big␣` | "bing" không hợp lệ → khôi phục | **Khác (cố ý)**, D21. OpenKey: "bing" |
| `bag␣` | `bang␣` | từ trùng, chấp nhận (D21) | |
| `vih␣` | `vinh␣` | | |
| `jas␣` | `giá␣` | | |
| `baks␣` | `bách␣` | | |
| `bak␣` | `bak␣` | "bach" không dấu thanh không hợp lệ (D31) → khôi phục | **Khác (cố ý)**. OpenKey: "bach" |
| `fix␣` | `phĩ␣` | từ tiếng Anh bị đổi vì "phĩ" hợp lệ, chấp nhận (D21) | |
| `wa␣` (Telex) | `ưa␣` | D23 | |
| `wen␣` (VNI) | `quen␣` | D23 | |
| `fan,` | `phan,` | dấu phẩy là ranh giới từ (D4, D21) | |

### 6.6 Cho phép z, f, w, j (bật; gõ tắt phụ âm tắt theo D22)

| Chuỗi phím | Mong đợi |
|---|---|
| `fanf␣` | `fàn␣` |
| `zas␣` | `zá␣` |
| `wa␣` (Telex) | `ưa␣` (w đầu từ vẫn là ư, D23) |

### 6.7 Ràng buộc chính tả (D31, D30)

| Chuỗi phím | Mong đợi | Lý do | So với OpenKey |
|---|---|---|---|
| `tatf␣` | `tatf␣` | vần t không mang huyền | |
| `capf␣` | `capf␣` | vần p không mang huyền | **Khác (cố ý)**. OpenKey: "càp" |
| `cacr␣` | `cacr␣` | vần c không mang hỏi | |
| `kas␣` | `ká␣` | D31 nới cho địa danh: k đứng trước mọi nguyên âm | Giống OpenKey (sau khi nới) |
| `DDawks Lawks␣`, `Bawsc Kajn␣`, `Kroong Pawsc␣`, `Kow Tu␣` | `Đắk Lắk␣`, `Bắc Kạn␣`, `Krông Pắc␣`, `Kơ Tu␣` | D31 phương án d (âm cuối k chỉ sau ă, phụ âm đầu kr) | |
| `ask␣`, `task␣`, `desk␣`, `hawk␣` | giữ nguyên | D31: âm cuối k không nhận sau a/e; "ăk" không dấu không hợp lệ | |
| `karma␣`, `hawks␣`, `awkward␣` | `kẩm␣`, `hắk␣`, `akward␣` | hệ quả đã chấp nhận của D31 phương án d | |
| `ghus␣` | `ghus␣` | gh chỉ đứng trước i, e, ê | **Khác (cố ý)** |
| `aw␣` | `aw␣` | ă không đứng cuối âm tiết (D31) | **Khác (cố ý)**. OpenKey: "ă" |
| `pin␣` / `pins␣` | `pin␣` / `pín␣` | "p" đơn là phụ âm đầu hợp lệ (D31) | |

### 6.8 "Thêm dấu cho từ đã gõ" (D20; bộ đệm rỗng, chữ đọc từ ứng dụng)

| Chữ có sẵn + phím | Mong đợi | Ghi chú |
|---|---|---|
| `hoc` + `j` | `học` | |
| `dep` + `j` | `dẹp` | không phải "đẹp" (UI.md) |
| `car` + `s` | `cars` | "cár" không hợp lệ → phím đi thẳng (D20) |
| `viet` + `j` | `vietj` | "viẹt" không hợp lệ; không tự thêm mũ (D20) |
| `viet` + `e` + `j` | `việt` | phím biến đổi cũng áp dụng (D20) |
| `nha` + `f` (ra `nhà`), rồi `k␣` | `nhafk␣` | Mốc khôi phục = chữ hiển thị trước khi sửa + các phím gõ sau đó (D4 mốc khôi phục; bài học B12) |

### 6.9 Ca thêm theo quyết định mới (đã duyệt 29/10/2026)

Người dùng đã duyệt câu chữ DECISIONS cho các ca này (D4 mốc khôi phục, D26, D28, D29, D30, D33). Dùng làm tiêu chí đóng mốc.

| Chuỗi phím | Mong đợi | Căn cứ | Ghi chú |
|---|---|---|---|
| `vieetj␣` | `việt␣` | D30 (tiền tố), D28 | |
| `hocj␣` | `học␣` | D30 (tiền tố) | |
| `trawngf␣` | `trằng␣` | D30 (tiền tố), D31 | |
| `aw␣` | `aw␣` | D31 | trùng 6.7 |
| `carr␣` | `car␣` | D4, D26 | trùng 6.1 |
| `tesst␣` | `test␣` | D4, D26 | trùng 6.1 |
| `tesst` ⌫ `s` | `tess` | D26 (khoá giữ sau ⌫), D32 | "test" ⌫ → "tes"; "tes" không hợp lệ (s không là phụ âm cuối) nên `s` đi thẳng |
| `tuongw` (Telex) | `tương` | D29 cho Telex | |
| `tuongw` (Telex đơn giản) | `tương` | D29 | |
| `did␣` (bỏ dấu tự do **tắt**) | `did␣` | D28 | |
| từ vượt 7 chữ cái (ví dụ `windowsx`) | khôi phục ngay về đúng phím đã gõ | D33 | |
| `nha` + `f` + `k␣` (D20) | `nhafk␣` | D4 mốc khôi phục | mốc là chữ đọc từ ứng dụng |
| `dD` | `đ` | D34 | |
| `password␣` / `passsword␣` | `pasword␣` / `password␣` | D26 (chữ lặp trùng phím dấu gõ 3 lần) | |
| `cofffee␣`, `errror␣` | `coffee␣`, `error␣` | D26 | |
| seed `cả` + `r` | `car` | D20 + D26 | |
| `uown`, `nguwowif` | `ươn`, `người` | D35 | |

---

## 7. Mâu thuẫn và điểm mơ hồ với DECISIONS.md

Ban đầu chỉ liệt kê. Đến 29/10/2026 (commit `495544d`) M1–M17 đã được chốt, trừ M7 và M18 là ghi chú. Mỗi mục giữ nội dung gốc để truy vết, kèm dòng "Đã chốt".

- **M1. Ranh giới từ kích hoạt khôi phục và gõ tắt phụ âm.** D4 và D21 ghi "khi nhấn Space", còn ARCHITECTURE (luồng một phím, bước 4) ghi "Space/dấu câu". OpenKey: Space cùng một tập dấu câu và Enter/Tab/Esc/mũi tên, nhưng không có ! ( ) (3.16, B10). Đề xuất ở 3.16: mọi phím kết thúc từ có in ra ký tự, gồm Space, Return, Tab và mọi dấu câu; không khôi phục khi mũi tên, Esc, chuột hoặc tổ hợp phím. Cần sửa D4/D21 hoặc ARCHITECTURE cho khớp.
  - **Đã chốt: D4 (phần "Ranh giới từ") và D21.** Mọi ký tự kết thúc từ có in ra (Space, Enter, Tab, mọi dấu câu) kích hoạt khôi phục và gõ tắt; mũi tên, Esc, chuột, tổ hợp phím chỉ reset.
- **M2. "Bỏ dấu tự do" chưa được định nghĩa** (D15 chỉ ghi mặc định bật). Có hai cách hiểu:
  - (a) cho phép gõ phím dấu và phím biến đổi ở bất kỳ đâu trong từ, kể cả sau phụ âm cuối, và dấu tự vào đúng chỗ. Khi tắt thì phím dấu phải gõ ngay sau nguyên âm.
  - (b) theo nghĩa của biến engine OpenKey: không tự dời dấu khi gõ thêm nguyên âm.

  Đề xuất (a). Cần chốt thêm: dd (đ) đặt sau nguyên âm ("did" → "đi") có thuộc phạm vi này không, vì nó làm "did" → "đi".
  - **Đã chốt: D28.** Theo nghĩa (a); "did" → "đi" khi bật; tắt thì phím dấu chỉ có tác dụng ngay sau nguyên âm.
- **M3. "Telex đơn giản" chưa được định nghĩa.** OpenKey có hai biến thể (3.5). Đề xuất: Telex bỏ w đứng riêng và bỏ `[ ]`. Cần chốt thêm: D23 có áp dụng cho Telex đơn giản không. Với định nghĩa đề xuất, w đầu từ là chữ w, nên câu hỏi là có cho gõ tắt w → qu hay không.
  - **Đã chốt: D29.** Simple Telex 1, không `[ ]`, không w → qu.
- **M4. Không có công tắc "kiểm tra chính tả" riêng.** Khi người dùng tắt "Tự khôi phục từ không phải tiếng Việt": engine có còn ngừng biến đổi sau khi từ đã sai chính tả không ("Hasaki" hiện "Hấki" hay "Hấsaki"…)? Đề xuất: luôn kiểm tra chính tả bên trong, công tắc chỉ điều khiển việc khôi phục khi kết thúc từ.
  - **Đã chốt: D30.** Kiểm tra chính tả luôn chạy; công tắc chỉ điều khiển khôi phục.
- **M5. "Âm tiết tiếng Việt hợp lệ" chưa được định nghĩa**, trong khi D4, D20 và D21 đều dựa vào nó. Cần chốt:
  - (a) có áp phân bố c/k/q, g/gh, ng/ngh không;
  - (b) vần tắc p, t, c, ch: chỉ cho sắc/nặng, và có chấp nhận khi chưa có dấu thanh không (ảnh hưởng `bak␣` → `bach␣`);
  - (c) ă/â có bắt buộc phụ âm cuối không (`aw␣`);
  - (d) phụ âm đầu "p" đơn (pin, pa-tê) có hợp lệ không;
  - (e) danh sách vần hợp lệ. Đề xuất engine-dev lập bảng vần riêng theo chính tả, không chép bảng OpenKey (bảng đó có mục lạ như "ôô", "uao").
  - **Đã chốt: D31.** Có "p"; áp phân bố c/k/q, g/gh, ng/ngh; bảng vần tự lập; vần tắc chỉ sắc/nặng, không dấu là sai; ă, â không đứng cuối.
- **M6. Phạm vi "gõ đúp".** D4 nói "gõ đúp phím dấu theo chuẩn Telex". Chưa nói: (a) ở VNI thì gõ đúp số có tương đương không (đề xuất có); (b) sau khi gõ đúp, phần còn lại của từ có là chữ thường không ("carrs" → "cars"); (c) gõ đúp phím mũ/móc/d (aaa, ww, ddd) có cùng luật không. Đề xuất có cho cả ba.
  - **Đã chốt: D26.** Cả ba: VNI có, phần còn lại của từ đi thẳng, cùng luật cho phím biến đổi; ngoại lệ "ooo".
- **M7. Ví dụ trong D20 dễ đọc nhầm.** "car giữ bằng carr, sau đó gõ thêm s vẫn ra cars" có thể hiểu là trong cùng một từ, khi đó do luật gõ đúp (nay là D26) chứ không phải D20. Hoặc hiểu là sau khi rời từ rồi quay lại, khi đó mới đúng là D20. Hai cách hiểu cho cùng kết quả, nên ghi rõ cả hai trong test. (D20 nay đã ghi rõ: "quay lại gõ thêm" là D20, "gõ liền trong cùng từ" là D26.)
- **M8. D21 với từ tiếng Anh mở rộng ra âm tiết hợp lệ.** "fix" → "phĩ". D21 chấp nhận "bag → bang", nên đây là hệ quả cùng loại, nhưng nên ghi vào giao diện/test để không bị coi là lỗi. Ngoài ra D21 không nói gì về **trạng thái trong lúc gõ**: khi bật gõ tắt, f/j/(w ở VNI) đầu từ và g/h/k cuối từ phải được coi là phụ âm tạm hợp lệ, thì phím dấu gõ sau đó mới có tác dụng ("fanf" hiện "fàn" trước khi nhấn Space). Đề xuất ghi rõ.
  - **Đã chốt: D21.** "fix" → "phĩ" chấp nhận, ghi trong test; f, j đầu và g, h, k cuối là phụ âm tạm hợp lệ trong lúc gõ.
- **M9. Câu chữ của D23.** D23 viết "w ở đầu từ luôn là ư/ơ". Nhưng w đứng riêng chỉ cho ra "ư"; "ơ" chỉ có từ "ow", hoặc từ `[` ở OpenKey. Đề xuất sửa thành "luôn là ư".
  - **Đã chốt: D23 (sửa câu chữ thành "luôn là ư").**
- **M10. "Cho phép w" không có tác dụng ở Telex.** Do D23, w đầu từ luôn thành ư (3.12). Giao diện "Cho phép phụ âm z, f, w, j" có thể gây hiểu nhầm ở Telex (N5). Đề xuất ghi chú hoặc chỉ hiện "w" khi dùng VNI/Telex đơn giản.
  - **Đã chốt: D22.** Giao diện ghi chú "cho phép w" không có tác dụng khi dùng Telex.
- **M11. Phím mũi tên.** ARCHITECTURE: mũi tên chỉ reset; OpenKey: mũi tên còn khôi phục. Đề xuất giữ như ARCHITECTURE (M1).
  - **Đã chốt: D4 (phần "Ranh giới từ").** Mũi tên chỉ reset, không khôi phục.
- **M12. Backspace chưa được đặc tả.** ARCHITECTURE không nói Backspace tác động lên bộ đệm và phím gốc thế nào. Đề xuất: Backspace bỏ chữ cuối hiển thị, đặt lại dấu, và đổi mốc khôi phục của từ thành "chữ đang hiển thị". Tránh lệch kiểu OpenKey (3.17, B12).
  - **Đã chốt: D32.** Backspace bỏ chữ cuối, đặt lại dấu, mốc khôi phục là chữ đang hiển thị.
- **M13. "Thêm dấu cho từ đã gõ" (D20) cần chốt chi tiết:**
  - (a) chỉ phím dấu thanh, hay cả phím biến đổi (aa, w, dd);
  - (b) "viet" + `j`: "viẹt" không hợp lệ nên phím đi thẳng ("vietj"), hay engine được tự thêm mũ thành "việt";
  - (c) mốc khôi phục khi từ trở nên không hợp lệ (đề xuất: chữ hiển thị + phím mới);
  - (d) có làm "lịch sử từ" qua Backspace như OpenKey không (3.17). Nếu có thì tránh B12.
  - **Đã chốt: D20 (chi tiết 29/10/2026).** (a) cả phím dấu thanh và phím biến đổi; (b) không tự thêm biến đổi, "viet" + j → "vietj"; (d) không làm lịch sử từ. (c) mốc khôi phục chưa ghi trực tiếp, suy ra từ D32 (xem 6.8).
- **M14. Độ dài từ tối đa.** Chưa có quyết định (3.15).
  - **Đã chốt: D33.** Dài hơn 7 chữ cái thì ngừng biến đổi; bộ đệm cố định.
- **M15. Quick Telex (cc → ch…)** không có trong DECISIONS. Đề xuất ghi vào "Đã cân nhắc và loại bỏ": phá từ tiếng Anh có phụ âm đôi, trùng mục đích với gõ tắt phụ âm.
  - **Đã chốt: mục "Đã cân nhắc và loại bỏ" (Quick Telex).**
- **M16. Phím `[` `]` ở Telex** không có trong DECISIONS. Đề xuất không làm hoặc chốt rõ: xung đột với gõ code/markdown, và "Telex đơn giản" theo đề xuất đã bỏ chúng.
  - **Đã chốt: D27.** `[ ]` luôn là dấu câu.
- **M17. Tạm tắt chính tả/bộ gõ bằng nhấn-nhả ⌃/⌘** (OpenKey). Đề xuất ghi vào "Đã cân nhắc và loại bỏ" cho rõ, cùng tinh thần D2 (không phím riêng; mục loại bỏ đã có "phím chuyển nhấn-nhả ⌃ hoặc ⇧").
  - **Đã chốt: mục "Đã cân nhắc và loại bỏ" (tạm tắt bằng nhấn-nhả ⌃/⌘), cùng D30.**
- **M18. Chưa phát hiện vi phạm N1–N5 trong bản thân DECISIONS.** Chỉ lưu ý: ví dụ giao diện "vieetj → việt" ở mục Thông minh đúng theo luật, còn "car → cả" và "carr → car" khớp D4.
