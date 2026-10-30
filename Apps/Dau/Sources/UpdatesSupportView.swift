import AppKit
import SwiftUI

/// "Cập nhật & hỗ trợ" (mockup "SettingsAbout"). Updates (Sparkle, D7) and the report
/// and roll-back actions (D8, D19) arrive in M7, so their controls are disabled and
/// promise nothing yet (N5). No network access until then. "Gỡ cài đặt…" (D16) works:
/// `InputMethodActions.confirmUninstall`.
struct UpdatesSupportView: View {
    @Environment(\.inputMethodActions) private var actions

    var body: some View {
        SettingsPage(SettingsSection.updates.title) {
            SettingsCard(padding: 18) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: AppVersion.nameAndVersion)
                            .font(.system(size: 15, weight: .bold))
                        // TODO(M7): one of the six update states from docs/UI.md.
                        Hint(Text("[Trạng thái kiểm tra cập nhật]"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    // TODO(M7): Sparkle check.
                    Button("Kiểm tra ngay") {}
                        .settingsButton()
                        .disabled(true)
                }
            }
            .layoutProbe("firstCard")

            SettingsGroup(Text("Cập nhật")) {
                // TODO(M7): bind to Sparkle (D7).
                SettingsCard {
                    SettingsRow(Text("Tự động kiểm tra bản mới")) {
                        RowSwitch(label: Text("Tự động kiểm tra bản mới"), isOn: .constant(false))
                    }
                    RowDivider()
                    SettingsRow(Text("Tự động tải và cài"),
                                hint: Text("[Cách cài bản mới — kiểm chứng ở M7]")) {
                        RowSwitch(label: Text("Tự động tải và cài"), isOn: .constant(false))
                    }
                    RowDivider()
                    SettingsRow(Text("Kênh phát hành")) {
                        SegmentedPicker(String(localized: "Kênh phát hành"), selection: .constant(0),
                                        options: [(0, String(localized: "Ổn định")), (1, String(localized: "Beta"))])
                            .frame(width: 200)
                    }
                }
                .disabled(true)
            }

            SettingsGroup(Text("Hỗ trợ")) {
                SettingsCard {
                    SettingsRow(Text("Gặp ứng dụng gõ bị lỗi?"),
                                hint: Text("Báo lại để bản sau xử lý đúng cho ứng dụng đó")) {
                        // TODO(M7): report sheet with a pre-filled GitHub issue (D8).
                        Button("Báo lỗi…") {}
                            .settingsButton()
                    }
                    .disabled(true)
                    RowDivider()
                    SettingsRow(Text("Quay về bản trước"), hint: Text("Dùng khi bản mới gây lỗi")) {
                        // TODO(M7): roll back with confirmation (D16, D19), with Sparkle.
                        Button("Quay về…") {}
                            .settingsButton()
                    }
                    .disabled(true)
                    RowDivider()
                    SettingsRow(Text("Gỡ Dấu khỏi máy")) {
                        // docs/UI.md: red, in the system red (D9).
                        Button(role: .destructive) {
                            actions?.confirmUninstall(in: NSApp.keyWindow)
                        } label: {
                            Text("Gỡ cài đặt…").foregroundStyle(actions == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.red))
                        }
                        .settingsButton()
                        .disabled(actions == nil || actions?.isUninstalling == true)
                    }
                }
            } footer: {
                // Wording fixed by docs/UI.md (D8, N2).
                Hint(Text("Dấu không gửi chữ bạn gõ ra khỏi máy. Bộ gõ không có quyền truy cập mạng; chỉ phần cập nhật kết nối để tải bản mới và danh sách ứng dụng tương thích. Mã nguồn mở theo giấy phép GPLv3."))
                    .padding(.horizontal, 4)
            }
        }
    }
}
