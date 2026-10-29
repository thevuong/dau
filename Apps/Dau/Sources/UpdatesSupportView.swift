import AppKit
import SwiftUI

/// "Cập nhật & hỗ trợ". Updates (Sparkle, D7) arrive in M7 and support actions
/// (report, roll back, uninstall — D8, D16, D19) in M5/M7, so their controls are shown
/// disabled and promise nothing yet (N5). The app has no network access until then.
struct UpdatesSupportView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    var body: some View {
        SettingsPage {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dấu")
                            .font(.headline)
                        Text("Phiên bản \(version) (\(build))")
                        // TODO(M7): one of the six update states from docs/UI.md.
                        Text("[Trạng thái kiểm tra cập nhật]")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    // TODO(M7): Sparkle check.
                    Button("Kiểm tra ngay") {}
                        .disabled(true)
                }
                .padding(.vertical, 4)
            }

            Section {
                // TODO(M7): bind to Sparkle (automatic checks, automatic download and
                // install while the user is not typing, Stable/Beta channel — D7).
                Toggle("Tự kiểm tra", isOn: .constant(false))
                Toggle("Tự tải và cài", isOn: .constant(false))
                Picker("Kênh", selection: .constant(0)) {
                    Text("Ổn định").tag(0)
                    Text("Beta").tag(1)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Cập nhật")
            }
            .disabled(true)

            Section {
                // TODO(M7): report sheet with a pre-filled GitHub issue (D8).
                Button("Báo lỗi…") {}
                // TODO(M5): roll back with confirmation (D16, D19).
                Button("Quay về…") {}
                // TODO(M5): uninstall with confirmation (D16).
                Button("Gỡ cài đặt…", role: .destructive) {}
                    .foregroundStyle(.red)
            } header: {
                Text("Hỗ trợ")
            }
            .disabled(true)

            Section {
                // Wording fixed by docs/UI.md (D8, N2).
                Text("Dấu không gửi chữ bạn gõ ra khỏi máy. Bộ gõ không có quyền truy cập mạng; chỉ phần cập nhật kết nối để tải bản mới và danh sách ứng dụng tương thích. Mã nguồn mở theo giấy phép GPLv3.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Quyền riêng tư")
            }
        }
    }
}
