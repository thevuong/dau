# M5 — Cài, bật, nâng cấp, gỡ bộ gõ; phát hiện bộ gõ cũ (nghiên cứu T1)

Ngày 30/10/2026. Máy đọc: macOS 27.2 (26B123), Xcode 27.1. Mọi thí nghiệm ở đây **chỉ đọc**: không chép, không đăng ký, không bật/tắt nguồn nhập liệu nào.

Mức tin cậy ghi sau mỗi khẳng định:
- **[Đã kiểm]**: đọc trực tiếp header SDK, file của hệ thống trên máy này, mã nguồn hoặc Info.plist của bản phát hành.
- **[Nguồn ngoài]**: dự án khác hoặc diễn đàn báo lại, Dấu chưa tự đo.
- **[Suy luận, cần kiểm chứng]**: chưa ai đo; phải thử ở T3/T4.

Bản sao mã nguồn tham khảo (ngoài repo): Squirrel 46962d2, McBopomofo 18e2060, vChewing 7c82f5f, macSKK 539cce3, fcitx5-macos 3466612, Gureum 46c62e5, XKey 398e78e, goxkey b197c57, OpenKey 89c2fd3. Không chép mã nào vào Dấu.

## 0. Tóm tắt

1. App chủ có sandbox **chép được** vào `~/Library/Input Methods` nếu có temporary exception, nhưng file nó tạo ra **luôn bị gắn quarantine**, và nó không gỡ được nhãn này. Nó cũng không dừng được tiến trình bộ gõ cũ. Đề xuất: **app chủ không sandbox**, bộ gõ giữ sandbox và không có quyền mạng (N2). Việc này cần người dùng chốt (mục 6).
2. Cài lần đầu: **phải đăng xuất rồi đăng nhập một lần** thì nguồn mới hiện ra. Apple DTS đã xác nhận (6/2026), và Dấu đã gặp đúng chuyện này khi đổi Bundle ID. Các bản cập nhật sau giữ nguyên ID thì không cần.
3. `TISEnableInputSource` không chắc có tác dụng. macOS có hộp thoại "Cho phép “…” bật “…”?" (thấy trong chuỗi giao diện của Cài đặt Bàn phím, macOS 27.2). Một dự án khác lại đo được trên macOS 27.0 là lệnh trả noErr mà input mode vẫn tắt. Vì vậy nút "Bật Dấu" phải đọc lại TIS để biết đã bật thật chưa, và luôn có đường lui là mở Cài đặt › Bàn phím kèm các bước hướng dẫn.
4. Nâng cấp: chép bản mới vào chỗ tạm rồi đổi chỗ cả khối, sau đó dừng tiến trình cũ. Không được đổi bundle ID, ID nguồn, ID mode, tên kết nối, tên file bundle. Không dừng `imklaunchagent`.
5. Bộ gõ cũ: lấy bundle ID từ Info.plist của bản phát hành thật (bảng ở mục 5). UniKey, VietKey, Laban Key không có bản macOS.

## 1. App chủ có sandbox có chép được bộ gõ vào `~/Library/Input Methods` không?

### 1.1 Entitlement
- `com.apple.security.temporary-exception.files.home-relative-path.read-write`, giá trị là mảng đường dẫn tính từ `~`, bắt đầu bằng `/`, và **kết thúc bằng `/` nếu là thư mục**. Với Dấu sẽ là `/Library/Input Methods/` **[Đã kiểm — tài liệu Apple, Entitlement Key Reference, mục App Sandbox Temporary Exception Entitlements]**. Apple gọi đây là ngoại lệ "tạm" và khuyên gửi báo lỗi. Hướng dẫn kê khai trong App Store Connect chỉ áp dụng cho App Store.
- **Notarize: được.** Apple viết: "Notarization of macOS software is not App Review. The Apple notary service is an automated system…" Yêu cầu chỉ gồm ký Developer ID, Hardened Runtime, secure timestamp, không có `get-task-allow` **[Đã kiểm — trang "Notarizing macOS software before distribution"]**. Dịch vụ notarize không xét entitlement sandbox. Đây là suy luận từ danh sách yêu cầu đó, chưa thấy câu nào của Apple nói thẳng **[Suy luận, cần kiểm chứng ở M7]**.

### 1.2 Vướng mắc thật sự: quarantine và dừng tiến trình
- **Sandbox luôn gắn quarantine lên file app tạo ra.** Một lệnh `move` cũng tính là tạo file mới. App trong sandbox **không** gỡ được nhãn này (Quinn, Apple DTS, 1/2026). Một tiến trình sandbox "không thể tạo file thực thi không bị quarantine" (Quinn, 3/2022) **[Nguồn ngoài — Apple Developer Forums 811450, 701687]**.
  - Hệ quả: bản bộ gõ được chép sẽ mang quarantine. Lần đầu hệ thống chạy nó, Gatekeeper sẽ kiểm tra, và bộ gõ có thể bị **App Translocation** (chạy từ một đường dẫn ngẫu nhiên, chỉ đọc). Bằng chứng gián tiếp: trình cài McBopomofo có mã riêng để chờ hết translocation của bộ gõ cũ (`BundleTranslocate.m`), còn vChewing gỡ quarantine bằng `xattr -drs com.apple.quarantine` sau khi chép **[Đã kiểm — mã nguồn hai dự án]**. Bộ gõ đã notarize thì có chạy được không, có hiện hộp thoại "tải từ Internet" cho một tiến trình nền không, có bị translocate không: **[Suy luận, cần kiểm chứng]**. Chỉ thử được với bản ký Developer ID đã notarize (M7). Bản Personal Team hiện tại chưa notarize nên khi bị quarantine nhiều khả năng bị chặn hẳn.
- **App sandbox không dừng được app khác.** Tài liệu `NSRunningApplication.terminate()` và `forceTerminate()` ghi rõ: "Sandboxed applications can't use this method to terminate other applications" **[Đã kiểm — tài liệu Apple]**. `kill()` sang tiến trình khác cũng bị sandbox chặn **[Suy luận, cần kiểm chứng]**. D7 cần dừng tiến trình bộ gõ cũ sau khi cập nhật.
- `TISRegisterInputSource`/`TISEnableInputSource` gọi từ app có sandbox: chưa ai đo. Thử trước đây với chính bộ gõ của Dấu (có sandbox) cho thấy `TISSelectInputSource` đổi được nguồn, nhưng bước báo cho app đang gõ bị chặn (`docs/PROGRESS.md`, 30/10/2026) **[Suy luận, cần kiểm chứng]**.

### 1.3 Các phương án

| Phương án | Được | Vướng |
|---|---|---|
| A. App chủ sandbox + temporary exception `/Library/Input Methods/` | Giữ sandbox | Bản chép mang quarantine, không gỡ được; không dừng được tiến trình cũ; chỉ kiểm được ở M7 |
| B. Người dùng tự chọn thư mục bằng `NSOpenPanel` (powerbox) + bookmark | Không cần ngoại lệ | `~/Library` bị ẩn, người dùng phải tìm đúng thư mục; file tạo ra vẫn bị quarantine (Quinn: `user-selected.executable` chỉ có tác dụng với vị trí chọn qua bảng *lưu*); vẫn không dừng được tiến trình |
| C. App chủ sandbox + XPC service không sandbox lo việc cài | Giữ sandbox cho phần có mạng | Thêm một tiến trình, giao thức XPC, ký riêng. Sparkle làm đúng kiểu này để "cài bản cập nhật bên ngoài sandbox của app" |
| D. App chủ **không** sandbox (bộ gõ vẫn sandbox, không mạng) | Đơn giản nhất: chép, kiểm chữ ký, gỡ quarantine, dừng tiến trình, gỡ cài đặt (kể cả tự chuyển app vào Thùng rác) đều làm trực tiếp; Sparkle không cần cấu hình XPC | Mất lớp sandbox ở app có kết nối mạng (Sparkle, danh sách tương thích) |
| E. Gói `.pkg` | Squirrel, macSKK, Gureum, fcitx5 dùng cách này (cài vào `/Library/Input Methods`, cần mật khẩu quản trị; Squirrel đặt `RequireLogout`) | Trái D6 (DMG) và D16 (`~/Library/Input Methods`); Sparkle cài `.pkg` phải xin quyền quản trị |
| F. Cask `input_method` | Homebrew chuyển bundle vào `~/Library/Input Methods` | Bộ gõ nằm trong `Dấu.app`; rút nó ra làm hỏng chữ ký của app chủ **[Suy luận]**; trùng việc với app chủ và Sparkle (`auto_updates true`) |

Các bộ gõ khác: XKey (tiếng Việt) có app chủ **không sandbox** tự chép `XKeyIM.app` vào `~/Library/Input Methods`. Khi chép lỗi, XKey chuyển sang hướng dẫn kéo-thả tay. Trình cài của McBopomofo và vChewing cũng không sandbox. **Không thấy dự án nào dùng phương án A** **[Đã kiểm — entitlements và mã nguồn]**.

**Đề xuất: D** (app chủ không sandbox, Hardened Runtime, ký Developer ID, notarize). Bộ gõ giữ sandbox, App Group, không mạng (N2). Nếu người dùng muốn giữ sandbox cho app chủ thì chọn **C**, không chọn A. Cần kiểm lại App Group khi app chủ không sandbox bằng `scripts/selftest-app-group.sh` **[Suy luận, cần kiểm chứng]**.

### 1.4 Homebrew
- `input_method`: "Relative path to an Input Method that should be moved into the `~/Library/Input Methods` folder on installation". `uninstall quit:` gửi Apple Event thoát. `signal:` chỉ dùng khi `quit` không có tác dụng. `zap` chỉ chạy khi gõ `--zap` **[Đã kiểm — Homebrew Cask Cookbook]**.
- Đề xuất cask (tên cask chọn sau, D24): chỉ `app "Dấu.app"` và `auto_updates true`. `uninstall` gọi lệnh gỡ của chính app (ví dụ cờ `--uninstall-input-method`: tắt nguồn, dừng bộ gõ) rồi `trash "~/Library/Input Methods/DauInputMethod.app"`. `zap` xoá Group Container `M58DANM3ZP.com.codefastlabs.dau.shared` (sẽ đổi theo Team ID của bản phát hành), các container, và các tuỳ chọn. Không dùng stanza `input_method`.

## 2. `TISRegisterInputSource` / `TISEnableInputSource` / `TISSelectInputSource`

### 2.1 Header (nguồn chính thức duy nhất; Apple không có trang tài liệu web cho các hàm TIS)
`…/HIToolbox.framework/Headers/TextInputSources.h` trong SDK của Xcode 27.1 **[Đã kiểm]**:
- `TISRegisterInputSource` chỉ đăng ký được bundle bộ gõ nằm trong `/Library/Input Methods/` hoặc `~/Library/Input Methods/`. Nghĩa là **phải chép vào đó trước**. Header ghi: code gọi hàm này "is part of an application or service that has already been validated in some way (e.g. by the user)".
- `TISEnableInputSource` "is mainly intended for input methods, or for applications that supply their own input sources". Muốn bật một input mode thì **input method cha phải được bật trước**.
- `TISSelectInputSource` cần nguồn đã bật và chọn được (select-capable); với mode thì cha cũng phải đang bật.
- `TISDisableInputSource` gỡ nguồn khỏi giao diện hệ thống.

### 2.2 Hộp thoại xác nhận
- Trong `KeyboardSettings.appex` (phần Bàn phím của Cài đặt hệ thống, macOS 27.2) có các chuỗi: "Allow “%@” to enable “%@”?" (tiếng Việt: "Cho phép “%1$@” bật “%2$@”?"), hai nút "Cho phép"/"Không cho phép", và câu "Nhà phát triển của nguồn đầu vào sẽ có thể truy cập mọi thứ bạn nhập với nguồn đầu vào này…". Trong mã có các ký hiệu `_showingThirdPartyPrompt`, `thirdPartyInputSource` **[Đã kiểm — đọc file `.loctable` và chuỗi trong binary]**. Hộp thoại này hiện khi một app bật nguồn của bên thứ ba, %1 là tên app gọi lệnh, %2 là tên nguồn **[Suy luận, cần kiểm chứng ở T4]**.
- McBopomofo (11/2025) ghi trong mã: "System Settings now asks the user whether to activate the IME", rồi cho trình cài tự đóng sau 60 giây **[Đã kiểm — commit a21ba98]**. Một dự án khác (low-talker, đo trên macOS 15.0.1, 9/2026) thấy hộp thoại Allow hiện lại sau khi người dùng bấm "Không" **[Nguồn ngoài]**.
- Ngược lại, msime đo trên macOS 27.0 (26A428, 27/9/2026): với nguồn kiểu `TISTypeKeyboardInputMode`, `TISEnableInputSource` **trả noErr nhưng mode vẫn tắt**. Mode `SCIM.Shuangpin` của chính Apple cũng vậy, còn bàn phím `com.apple.keylayout.US` thì bật được. Họ đã bỏ nút "Bật" và chỉ còn hướng dẫn mở Cài đặt **[Nguồn ngoài — msime PR #2492, `platforms/macos/README.md`]**. Nguồn của Dấu (`….Dau.vi`) chính là một input mode, nên Dấu nhiều khả năng gặp đúng trường hợp này. Hai báo cáo này mâu thuẫn nhau. Có thể msime chạy tự động nên không ai bấm "Cho phép" **[Suy luận, cần kiểm chứng ở T4, người dùng quan sát]**.
- Cờ `kTISPropertyInputSourceIsEnabled` không đáng tin: McBopomofo và vChewing đều ghi từ macOS 12 cờ này có thể báo sai, nên họ bật luôn không cần xét. Trên máy này, mode Telex của Apple báo enabled=1 trong khi input method cha báo 0. `AppleEnabledInputSources` trong `com.apple.HIToolbox` thì **không có** Dấu, dù TIS báo Dấu đang bật và đang được chọn **[Đã kiểm — đọc TIS và `defaults read`]**. Kết luận: kiểm trạng thái bằng TIS, đọc lại vài lần (msime: sau khi thay bundle có khoảng vài phút danh sách TIS không ổn định), và không đọc plist.

### 2.3 Lần cài đầu có phải đăng xuất không: **có**
- Apple DTS (6/2026): "without the user logging off the system, System Settings doesn't pick up a new input source any more. I don't see anything that can avoid the logoff." (FB23026482) **[Nguồn ngoài — Apple Developer Forums 775526]**.
- msime (macOS 27.0): một ID chưa có trong danh sách nguồn lúc bắt đầu phiên đăng nhập thì không vào được danh sách trong phiên đó. `TISRegisterInputSource` trả noErr nhưng `TISCreateInputSourceList` không thấy. Khởi động lại `imklaunchagent`, `TextInputMenuAgent`, `TextInputSwitcher`, `keyboardservicesd` hay chạy `lsregister` đều không giúp gì. Đăng nhập lại một lần là được, và các bản cập nhật sau giữ ID đó thì không cần nữa **[Nguồn ngoài]**.
- low-talker (macOS 15.0.1): bundle chép vào `~/Library/Input Methods` giữa phiên đăng ký được, nhưng chỉ bật được sau lần đăng nhập sau **[Nguồn ngoài]**. README của XKey, fcitx5-macos, Gureum (cài tay) và macSKK đều bảo đăng xuất/đăng nhập **[Đã kiểm]**. Dấu cũng phải đăng xuất mới bật được nguồn sau khi đổi Bundle ID (`docs/PROGRESS.md`, 30/10/2026).
- vChewing cho rằng dừng `TextInputMenuAgent` rồi chờ 0,5 s là khỏi phải đăng xuất. msime đo thì thấy không đúng. **Không dùng cách này** (thêm nữa, nó là tiến trình hệ thống, xem mục 3).
- Hệ quả cho onboarding: sau khi chép và đăng ký mà TIS chưa thấy `….Dau.vi` thì hướng dẫn "Đăng xuất rồi đăng nhập lại, sau đó mở lại Dấu" (menu Apple › Đăng xuất). App không tự đăng xuất (N4). App phải nhớ đang ở bước 2 để lần mở sau làm tiếp.

### 2.4 Các bộ gõ khác làm gì ở lần chạy đầu
| Dự án | Cách |
|---|---|
| Squirrel | `.pkg` vào `/Library/Input Methods`; postinstall gọi register, enable, select (chọn luôn nguồn); `RequireLogout` |
| McBopomofo | trình cài riêng chép vào `~/Library/Input Methods`, register nếu chưa có, **luôn** enable từ macOS 12; macOS hỏi xác nhận |
| vChewing | như McBopomofo; dừng `TextInputMenuAgent`; enable; nếu không chắc thì báo đăng xuất |
| XKey (tiếng Việt) | chép, register, **không enable**; mở Cài đặt › Bàn phím › Nguồn đầu vào để người dùng tự thêm |
| macSKK, Gureum, fcitx5 | `.pkg`, chỉ hướng dẫn tự thêm trong Cài đặt; cài lần đầu thì đăng xuất |
| msime | từng có nút "Bật", đã bỏ vì trên macOS 27 nút này không có tác dụng; nay chỉ hướng dẫn + mở Cài đặt, kiểm lại mỗi 3 s |

So với các bộ gõ trên, cách của Dấu (chỉ bật khi người dùng bấm "Bật Dấu", có Hoàn tác) **thận trọng hơn** Squirrel, McBopomofo, vChewing (bật, thậm chí chọn luôn, ngay khi cài) và **ngang** XKey, msime (chỉ hướng dẫn). Nhưng chữ của N4 ("Chỉ hướng dẫn hoặc mở đúng màn hình Cài đặt") không cho phép gọi `TISEnableInputSource`, kể cả khi người dùng đã bấm. Xem mục 6, đề xuất 2.

### 2.5 Mở đúng màn hình Cài đặt
Các dự án dùng URL `x-apple.systempreferences:com.apple.Keyboard-Settings.extension` (Bàn phím) và `x-apple.systempreferences:com.apple.LoginItems-Settings.extension` (Mục đăng nhập). `KeyboardSettings.appex` trên macOS 27.2 khai báo `allowsXAppleSystemPreferencesURLScheme = true` **[Đã kiểm]**. Apple không công bố danh sách URL này, nên phải thử lại trên từng bản macOS **[Suy luận]**. Tên trên giao diện tiếng Việt, macOS 27.2: "Bàn phím › Nhập văn bản › Nguồn đầu vào › Sửa…"; "Cài đặt chung › Mục đăng nhập & Phần mở rộng › Mở khi đăng nhập" **[Đã kiểm — `.loctable`]**.

## 3. Nâng cấp (bộ gõ đang chạy)

Trình tự đề xuất, ráp từ McBopomofo, vChewing, XKey và D7:
1. App chủ khởi động lại sau khi Sparkle cập nhật. Nó so `CFBundleVersion` của bộ gõ nằm trong app với bản đã cài.
2. Chờ lúc người dùng không gõ (D7).
3. Kiểm chữ ký bản trong app: Team ID đúng, chữ ký hợp lệ.
4. Chép vào một thư mục tạm **trên cùng ổ đĩa** (trong `~/Library/Input Methods`, tên tạm không đuôi `.app` để TIS không quét), rồi **đổi chỗ cả khối** (`FileManager.replaceItemAt`, hoặc đổi tên cái cũ rồi đặt cái mới). Không ghi đè từng file lên bundle đang chạy: tiến trình cũ còn đang ánh xạ các trang mã của nó **[Suy luận, cần kiểm chứng; vChewing làm đúng kiểu chép tạm rồi move]**.
5. Gỡ quarantine của bản mới sau khi đã kiểm chữ ký (chỉ làm được khi app chủ không sandbox).
6. Dừng tiến trình cũ (`DauInputMethod`). Hệ thống sẽ chạy bản mới ở phím gõ kế tiếp (đã thấy với `scripts/install-debug.sh`). Cách hợp với cả hai phương án sandbox: app chủ phát thông báo Darwin, bộ gõ tự `exit(0)` khi không có từ đang gõ; quá thời hạn thì app chủ (không sandbox) mới `terminate`. macSKK làm tương tự bằng cách gửi "quit" qua `osascript`.
7. Gọi lại `TISRegisterInputSource(url)` (Squirrel làm mỗi lần cài; vô hại). Không đụng tới trạng thái bật/chọn: ID giữ nguyên thì lựa chọn của người dùng còn nguyên.

**Không làm:**
- Không dừng `imklaunchagent`. vChewing ghi: dừng nó làm app đang gõ mất kết nối với mọi bộ gõ cho tới khi mở lại app đó **[Đã kiểm — chú thích trong mã vChewing]**.
- Không dừng `TextInputMenuAgent`, `CursorUIViewService`, `TextInputSwitcher`, không xoá bộ đệm của Cài đặt Bàn phím (`$(getconf DARWIN_USER_CACHE_DIR)/com.apple.Keyboard-Settings.extension/com.apple.IntlDataCache.le.kbdx`; msime xoá file này, macOS 27.0.1). Đó đều là tiến trình và bộ đệm của hệ thống (tinh thần N4). Giữ biểu tượng và tên không đổi thì không cần làm những việc đó. Nếu một bản có đổi biểu tượng/tên thì ghi trong ghi chú phát hành: "đăng xuất để thấy biểu tượng mới". Dấu đã thấy cả hai bộ đệm ảnh (`docs/PROGRESS.md`, 30/10/2026).

**Không được đổi giữa các phiên bản** (đổi là phải đăng xuất, và có thể làm lệch bộ đệm TIS như đã gặp ngày 30/10):
- `CFBundleIdentifier` của bộ gõ `com.codefastlabs.dau.inputmethod.Dau`, `TISInputSourceID`, ID mode `com.codefastlabs.dau.inputmethod.Dau.vi` (khoá trong `tsInputModeListKey`);
- `InputMethodConnectionName` (`…_Connection`, cũng nằm trong entitlement `mach-register`);
- tên file `DauInputMethod.app` và `CFBundleExecutable` `DauInputMethod` (dùng để tìm và dừng tiến trình);
- `TISIntendedLanguage` `vi` (quyết định nhóm ngôn ngữ trong danh sách thêm nguồn);
- nên giữ: tên hiển thị "Dấu – Tiếng Việt", tên file biểu tượng (bộ đệm chỉ làm mới khi đăng xuất).

## 4. Gỡ cài đặt (D16)

Trình tự đề xuất (người dùng bấm "Gỡ cài đặt…" và xác nhận):
1. Nếu Dấu đang được chọn: chọn trước một bàn phím khác. Đích là `TISCopyCurrentASCIICapableKeyboardLayoutInputSource()` (theo header: bàn phím ASCII dùng gần nhất) nếu nó đang bật; không thì lấy nguồn ASCII đang bật đầu tiên. Gureum dặn người dùng tự chuyển sang bàn phím của hệ thống trước khi gỡ. Nếu không chọn trước, hệ thống sẽ tự đổi sang nguồn khác khi Dấu bị tắt, nhưng chưa biết đổi sang nguồn nào **[Suy luận, cần kiểm chứng]**.
2. `TISDisableInputSource` cho mode `….Dau.vi`, rồi cho input method cha `com.codefastlabs.dau.inputmethod.Dau` (fcitx5 tắt cha) **[Suy luận: chưa ai đo Disable với mode trên macOS 27]**.
3. Dừng tiến trình `DauInputMethod` (như mục 3, bước 6).
4. Chuyển `~/Library/Input Methods/DauInputMethod.app` vào Thùng rác (vChewing, McBopomofo dùng Thùng rác, có thể khôi phục).
5. Nếu tick "Xoá cả cài đặt và quy tắc ứng dụng": xoá dữ liệu trong Group Container của App Group. Container riêng của bộ gõ (`~/Library/Containers/com.codefastlabs.dau.inputmethod.Dau`) để bộ gõ tự dọn tuỳ chọn của nó trước khi thoát. App chủ đụng vào container của app khác có thể làm macOS 14+ hỏi quyền truy cập dữ liệu app khác **[Suy luận, cần kiểm chứng]**.
6. Báo người dùng: tên "Dấu" có thể còn trong danh sách Nguồn đầu vào của Cài đặt tới lần đăng xuất sau (cùng cơ chế bộ đệm ở mục 2.3) **[Suy luận]**. Cuối cùng, chuyển `Dấu.app` vào Thùng rác (chỉ làm được khi app chủ không sandbox) hoặc hướng dẫn người dùng tự kéo.

Câu "Bàn phím đang dùng trước đó được giữ nguyên" trong sheet xác nhận (`docs/UI.md`) chỉ đúng khi làm bước 1 trước bước 2. Phải kiểm ở T4 trước khi để câu này trên giao diện (N5).

## 5. Bộ gõ tiếng Việt cũ cần phát hiện (D14 bước 1)

Bundle ID lấy từ `Info.plist` của bản phát hành tải về từ URL trong cask Homebrew. Chỉ giải nén hoặc mount chỉ đọc, không chạy **[Đã kiểm]**:

| Bộ gõ | Bundle ID app chính | Tiến trình | Bản | Thoát | Tự chạy khi đăng nhập |
|---|---|---|---|---|---|
| OpenKey | `com.tuyenmai.openkey` | `OpenKey` | 2.0.5 | biểu tượng trên thanh menu › "Thoát" (⌘Q) | tuỳ chọn "Khởi động cùng macOS" trong "Bảng điều khiển…"; helper `com.tuyenmai.OpenKeyHelper` (`SMLoginItemSetEnabled`), thêm `com.tuyenmai.OpenKeyUpdate` |
| EVKey | `com.lamquangminh.evkey` (file `EVKeyMac.app`) | `EVKey` | 3.3.10 | có chuỗi "Quit EVKey" | helper `com.lamquangminh.evkeyhelper` trong `Contents/Library/LoginItems` |
| GoTiengViet | `com.trankynam.GoTiengViet` | `GoTiengViet` | 2.4 (có sandbox) | có chuỗi "Quit GoTiengViet" | chưa rõ |
| XKey | `com.codetay.XKey`; kèm bộ gõ IMK `com.codetay.inputmethod.XKey` (tiến trình `XKeyIM`, cài vào `~/Library/Input Methods`) | `XKey` | 1.2.25 | "Thoát XKey" | tuỳ chọn "Khởi động cùng hệ thống" |
| PHTV | `com.phamhungtien.phtv` | `PHTV` | 3.7.1 | có chuỗi "Quit PHTV" | tuỳ chọn "Khởi động cùng macOS" (`SMAppService`) |
| Gõ Nhanh | `org.gonhanh.GoNhanh` | `GoNhanh` | 1.0.165 | chưa rõ nhãn | có "Launch at login" |
| GoKey (goxkey) | `com.goxkey.app` (theo `Cargo.toml`, chưa kiểm bản build) | — | 0.3.1 | — | — |
| Bộ gõ tiếng Việt của Apple | `com.apple.inputmethod.VietnameseIM`; mode `….VietnameseTelex`, `….VietnameseSimpleTelex`, `….VietnameseVNI`, `….VietnameseVIQR`; bàn phím `com.apple.keylayout.Vietnamese` | là nguồn nhập liệu, không phải app chạy nền | — | — | — |

- **UniKey:** không có app macOS. Engine của nó được tặng Apple năm 2006 và nằm trong bộ gõ tiếng Việt có sẵn của macOS **[Nguồn ngoài — unikey.org/en/apple.html]**. **VietKey:** không tìm thấy bản macOS. **Laban Key:** chỉ có Android, iOS và tiện ích ChromeOS **[Nguồn ngoài, tìm kiếm 30/10/2026]**. Không đưa ba cái này vào danh sách.
- Cask `openkey` và `evkey` đang ở trạng thái disabled trên Homebrew, nhưng người dùng cũ vẫn còn cài nên vẫn phải phát hiện.
- **Cách phát hiện:**
  - Bộ gõ chặn phím bằng event tap (OpenKey, EVKey, GoTiengViet, XKey, PHTV, Gõ Nhanh, GoKey) biến đổi phím **bất kể nguồn nhập liệu nào đang được chọn**, nên gõ chồng với Dấu. Đây là xung đột thật. Tìm bằng `NSWorkspace.shared.runningApplications`, so `bundleIdentifier`, và chỉ tính tiến trình của người dùng hiện tại (OpenKey tự lọc theo uid vì có chế độ chuyển nhanh người dùng). Đối chiếu bằng bundle ID, không bằng tên tiến trình.
  - Bộ gõ IMK khác (Telex của Apple, `XKeyIM`) chỉ xử lý phím khi chính nó đang được chọn, nên không gõ chồng. Tìm bằng TIS: nguồn đang bật có ngôn ngữ `vi`, khác Dấu. Chỉ nên nhắc nhẹ ("có thể bỏ khỏi danh sách cho gọn"), không chặn bước 1. Máy hiện tại đang bật Telex của Apple.
  - Mục đăng nhập của app khác: không có API công khai để đọc. Chỉ hướng dẫn.
- **Hướng dẫn tắt (N4: chỉ hướng dẫn):** (1) trong app đó, tắt "Khởi động cùng macOS/hệ thống" nếu có. Phải làm trước khi thoát, vì helper sẽ bật lại tuỳ chọn và mở lại app ở lần đăng nhập sau. (2) Bấm biểu tượng trên thanh menu › "Thoát". (3) Nếu vẫn tự chạy lại: Cài đặt chung › Mục đăng nhập & Phần mở rộng, tắt app đó. Kiểm tra lại khi cửa sổ onboarding được kích hoạt (`docs/UI.md`). Không tự thoát app của người khác: trái N4, và cũng không làm được nếu app chủ có sandbox.

## 6. Đề xuất cho DECISIONS (chưa sửa `DECISIONS.md`; cần người dùng chốt)

1. **Quyết định mới, trả lời câu hỏi mở "App chủ có sandbox được không":** app chủ **không** sandbox (Hardened Runtime, Developer ID, notarize). Bộ gõ giữ sandbox, App Group, không mạng (N2). Lý do: file app sandbox tạo ra luôn bị quarantine và không gỡ được; app sandbox không dừng được bộ gõ cũ (D7) và không chuyển chính nó vào Thùng rác (D16); không có bộ gõ tham khảo nào dùng cách sandbox + temporary exception. Phương án dự phòng: app chủ sandbox + XPC service không sandbox. Kéo theo: sửa `ARCHITECTURE.md`, bỏ `Apps/Dau/Dau.entitlements` khỏi sandbox, chạy lại `selftest-app-group`.
2. **Làm rõ N4 cho D14 bước 2** (đang mâu thuẫn về câu chữ: N4 "chỉ hướng dẫn hoặc mở đúng màn hình Cài đặt", trong khi `docs/UI.md` bước 2 ghi "đăng ký và bật nguồn nhập liệu; có Hoàn tác"). Đề xuất câu: "Chép và đăng ký bộ gõ là phần cài đặt của Dấu. Bật nguồn (`TISEnableInputSource`) chỉ chạy khi người dùng bấm 'Bật Dấu' và có Hoàn tác (`TISDisableInputSource`); macOS tự hỏi xác nhận. Kết quả được đọc lại từ TIS; chưa bật được thì mở Cài đặt › Bàn phím và hướng dẫn thêm 'Dấu – Tiếng Việt'; chưa có trong danh sách thì hướng dẫn đăng xuất/đăng nhập. Không tự chọn nguồn (`TISSelectInputSource`); người dùng chuyển bằng phím tắt của hệ thống." Phương án thay thế giống msime: bỏ hẳn nút bật, chỉ hướng dẫn.
3. **D14 bước 1:** chỉ coi bộ gõ chặn phím đang chạy là xung đột (danh sách bundle ID ở mục 5, cập nhật được cùng danh sách tương thích có chữ ký, D7). Nguồn tiếng Việt kiểu IMK khác chỉ nhắc nhẹ, không chặn.
4. **Bổ sung D24:** danh sách định danh không bao giờ đổi giữa các phiên bản (mục 3). Nếu buộc phải đổi thì bản đó phải hướng dẫn đăng xuất.
5. **Bổ sung D7:** thay bộ gõ bằng cách chép tạm rồi đổi chỗ cả khối; dừng tiến trình cũ bằng thông báo Darwin để bộ gõ tự thoát khi không có từ đang gõ. Không dừng `imklaunchagent` hay tiến trình, bộ đệm của hệ thống. Chấp nhận biểu tượng cũ còn tới khi đăng xuất.
6. **Bổ sung D16:** trình tự gỡ ở mục 4 (chọn bàn phím khác trước nếu Dấu đang chọn → tắt mode và cha → dừng tiến trình → Thùng rác → tuỳ chọn xoá dữ liệu App Group). Ghi rõ tên nguồn có thể còn trong Cài đặt tới khi đăng xuất.
7. **Bổ sung D6:** cask chỉ có `app`, không có `input_method`; `uninstall` gọi lệnh gỡ của app; `zap` xoá các container.
8. **Hướng dẫn trên giao diện (N5):** câu về đăng xuất, hộp thoại "Cho phép", và "Bàn phím đang dùng trước đó được giữ nguyên" để dạng ô trống cho tới khi T4 kiểm xong.

## 7. Cần thử trên máy (T3/T4; cần người dùng vì đổi nguồn nhập liệu và có hộp thoại)
1. Gỡ bản Debug rồi chép lại, cùng ID và giữa phiên: TIS có thấy ngay không? (Cùng ID thì kỳ vọng thấy ngay.)
2. App chủ gọi `TISEnableInputSource` cho cha rồi cho `….Dau.vi`: hộp thoại "Cho phép … bật …?" có hiện không, hiện ở đâu (trong Cài đặt hay riêng), bấm "Cho phép" thì TIS đọc lại có báo enabled không, bấm "Không cho phép" thì sao. Làm một lần với app chủ có sandbox và một lần không có.
3. `TISDisableInputSource` lên mode đang được chọn: hệ thống chuyển sang nguồn nào; tên còn trong danh sách Cài đặt không.
4. (M7) bản ký Developer ID đã notarize, chép từ app sandbox (có quarantine): bộ gõ có chạy không, có bị translocate không.
5. Một máy (hoặc một tài khoản người dùng) chưa từng cài Dấu: xác nhận phải đăng xuất ở lần cài đầu.

## Nguồn
- Header SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/TextInputSources.h` (`TISRegisterInputSource`, `TISEnableInputSource`, `TISDisableInputSource`, `TISSelectInputSource`, `TISCopyCurrentASCIICapableKeyboardLayoutInputSource`).
- Chuỗi hệ thống macOS 27.2: `/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex/Contents/Resources/Localizable.loctable`, `…/LoginItems.appex/…`, `…/GeneralSettings.appex/…`.
- Apple, App Sandbox Temporary Exception Entitlements: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html
- Apple, Notarizing macOS software before distribution: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple, `NSRunningApplication.terminate()` / `forceTerminate()`: https://developer.apple.com/documentation/appkit/nsrunningapplication/terminate() ; https://developer.apple.com/documentation/appkit/nsrunningapplication/forceterminate()
- Apple, `NSWorkspace.runningApplications`: https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications
- Apple, `LSFileQuarantineEnabled`: https://developer.apple.com/documentation/bundleresources/information-property-list/lsfilequarantineenabled
- Apple Developer Forums: logout khi thêm bộ gõ (DTS, 6/2026) https://developer.apple.com/forums/thread/775526 ; sandbox và quarantine (Quinn) https://developer.apple.com/forums/thread/811450 , https://developer.apple.com/forums/thread/701687
- Homebrew Cask Cookbook: https://docs.brew.sh/Cask-Cookbook ; cask JSON: https://formulae.brew.sh/api/cask/{openkey,evkey,gotiengviet,xkey,phtv,gonhanh}.json
- Sparkle, Sandboxing: https://sparkle-project.org/documentation/sandboxing/
- Squirrel: `sources/InputSource.swift`, `scripts/postinstall`, `package/Distribution` — https://github.com/rime/squirrel
- McBopomofo: `Source/Installer/AppDelegate.swift`, `Packages/InputSourceHelper` — https://github.com/openvanilla/McBopomofo
- vChewing: `Packages/vChewing_InstallerAssembly4Darwin/…/InstallerVMProtocol.swift`, `ValueAdd/PKGInstallerAssets/pkgPostInstall.sh` — https://github.com/vChewing/vChewing-macOS
- macSKK: `docs/guide/install.md`, `docs/guide/uninstall.md`, `script/scripts/postinstall` — https://github.com/mtgto/macSKK
- fcitx5-macos: `src/config/about.swift`, `assets/uninstall.sh`, `README.md` — https://github.com/fcitx-contrib/fcitx5-macos
- Gureum: `README.md`, `OSX/Gureum.entitlements` — https://github.com/gureum/gureum
- XKey: `XKey/Utilities/IMKitHelper.swift`, `XKey/App/XKeyIMUpdateManager.swift`, `XKeyIM/README.md` — https://github.com/xmannv/xkey
- msime: PR #2492 https://github.com/metasequoiaime/msime/pull/2492 và `platforms/macos/README.md`, `docs/macos-parity.md`
- low-talker PR #96: https://github.com/brandon-fryslie/low-talker/pull/96
- OpenKey: `Sources/OpenKey/macOS/ModernKey/AppDelegate.m`, `OpenKeyHelper/AppDelegate.m` — https://github.com/tuyenvm/OpenKey
- goxkey: `Cargo.toml` — https://github.com/huytd/goxkey
- UniKey trên macOS: https://www.unikey.org/en/apple.html
- Không tìm thấy ghi chú cài đặt của MacishType. Kawa chỉ là công cụ chuyển nguồn nhập liệu, không cài bộ gõ, nên không xem.
