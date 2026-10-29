import AppKit
import SwiftUI

/// "Cập nhật & hỗ trợ" (mockup "SettingsAbout"). Updates (Sparkle, D7) arrive in M7 and
/// support actions (report, roll back, uninstall — D8, D16, D19) in M5/M7, so their
/// controls are disabled and promise nothing yet (N5). No network access until then.
struct UpdatesSupportView: View {
    var body: some View {
        SettingsPage(SettingsSection.updates.title) {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: AppVersion.nameAndVersion)
                            .font(.system(size: 15, weight: .bold))
                        // TODO(M7): one of the six update states from docs/UI.md.
                        Text("[Trạng thái kiểm tra cập nhật]")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    // TODO(M7): Sparkle check.
                    Button("Kiểm tra ngay") {}
                        .disabled(true)
                }
                .padding(.vertical, 6)
                .layoutProbe("firstRow")
            }

            Section {
                // TODO(M7): bind to Sparkle (D7).
                Toggle("Tự động kiểm tra bản mới", isOn: .constant(false))
                Toggle(isOn: .constant(false)) {
                    RowLabel(Text("Tự động tải và cài"), hint: Text("[Cách cài bản mới — kiểm chứng ở M7]"))
                }
                SettingsRow(Text("Kênh phát hành")) {
                    Picker("Kênh phát hành", selection: .constant(0)) {
                        Text("Ổn định").tag(0)
                        Text("Beta").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }
            } header: {
                Text("Cập nhật")
            }
            .disabled(true)

            Section {
                SettingsRow(Text("Gặp ứng dụng gõ bị lỗi?"),
                            hint: Text("Báo lại để bản sau xử lý đúng cho ứng dụng đó")) {
                    // TODO(M7): report sheet with a pre-filled GitHub issue (D8).
                    Button("Báo lỗi…") {}.disabled(true)
                }
                SettingsRow(Text("Quay về bản trước"), hint: Text("Dùng khi bản mới gây lỗi")) {
                    // TODO(M5): roll back with confirmation (D16, D19).
                    Button("Quay về…") {}.disabled(true)
                }
                SettingsRow(Text("Gỡ Dấu khỏi máy")) {
                    // TODO(M5): uninstall with confirmation (D16).
                    Button("Gỡ cài đặt…", role: .destructive) {}.disabled(true)
                }
            } header: {
                Text("Hỗ trợ")
            } footer: {
                // Wording fixed by docs/UI.md (D8, N2).
                Text("Dấu không gửi chữ bạn gõ ra khỏi máy. Bộ gõ không có quyền truy cập mạng; chỉ phần cập nhật kết nối để tải bản mới và danh sách ứng dụng tương thích. Mã nguồn mở theo giấy phép GPLv3.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
