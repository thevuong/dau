import SwiftUI
import DauShared

/// "Thông minh" (mockups "SettingsSmart", "SettingsSmartAdvanced"): automatic restore
/// of foreign words (D4), adding marks to a typed word (D20), and the collapsed
/// "Nâng cao" group (D21, D22, D23).
struct SmartSettingsView: View {
    @Environment(SettingsModel.self) private var model
    @Environment(\.smartAdvancedExpanded) private var expandedAtStart
    @State private var advancedExpanded: Bool

    init(advancedExpanded: Bool = false) {
        _advancedExpanded = State(initialValue: advancedExpanded)
    }

    var body: some View {
        @Bindable var model = model
        let method = model.settings.typingMethod
        SettingsPage(SettingsSection.smart.title) {
            Section {
                Toggle(isOn: $model.settings.autoRestore) {
                    RowLabel(Text("Tự khôi phục từ không phải tiếng Việt"),
                             hint: Text("Khi gõ xong một từ (Space, dấu câu, Enter), từ không phải âm tiết tiếng Việt hợp lệ trở về đúng như bạn gõ"))
                }
                .layoutProbe("firstRow")
                VStack(alignment: .leading, spacing: 10) {
                    WrappingHStack {
                        ForEach(SettingsSamples.restore(method)) { ExampleChips(example: $0) }
                    }
                    let wins = SettingsSamples.vietnameseWins(method)
                    let keep = SettingsSamples.keepOriginal(method)
                    Text("Từ trùng với tiếng Việt thì tiếng Việt được ưu tiên: “\(wins.keys)” ra “\(wins.result)”. Muốn giữ chữ gốc, gõ đúp phím dấu: “\(keep.keys)” ra “\(keep.result)”.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Gõ lẫn từ nước ngoài")
            }

            Section {
                Toggle(isOn: $model.settings.addMarksToTypedWords) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Thêm dấu cho từ đã gõ")
                            NewBadge()
                        }
                        // N5: stability on web editors is an open question in
                        // DECISIONS.md; the placeholder stays until it is measured.
                        Text("Đặt con trỏ ngay sau từ rồi gõ phím dấu. [Kết quả kiểm chứng trên Google Docs, Notion…]")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                WrappingHStack {
                    ExampleChips(example: SettingsSamples.addMarks(method))
                }
                .padding(.vertical, 4)
            } header: {
                Text("Sửa từ đã gõ")
            }

            Section {
                DisclosureGroup(isExpanded: $advancedExpanded) {
                    AdvancedOptions(settings: $model.settings)
                } label: {
                    LabeledContent {
                        Text(advancedSummary(model.settings.advanced))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("Nâng cao")
                    }
                }
            }
        }
        .onAppear { if expandedAtStart { advancedExpanded = true } }
    }

    private func advancedSummary(_ advanced: DauSettings.Advanced) -> String {
        advanced == .off
            ? String(localized: "2 tuỳ chọn, đang tắt")
            : String(localized: "2 tuỳ chọn, 1 đang bật")
    }
}

/// The two mutually exclusive advanced switches (D22).
struct AdvancedOptions: View {
    @Binding var settings: DauSettings

    var body: some View {
        Toggle(isOn: $settings.consonantShortcuts) {
            RowLabel(Text("Gõ tắt phụ âm"), hint: Text(shortcutsHint))
        }
        Toggle(isOn: $settings.allowZFWJ) {
            RowLabel(Text("Cho phép phụ âm z, f, w, j"), hint: Text(zfwjHint))
        }
    }

    private var shortcutsHint: String {
        // D21; w → qu exists only in VNI (D23). D22: say that this turns the other off.
        String(localized: "Đầu từ: f → ph, j → gi (VNI thêm w → qu) · Cuối từ: g → ng, h → nh, k → ch. Áp dụng khi gõ xong từ, chỉ khi ra từ tiếng Việt hợp lệ. Bật mục này sẽ tắt Cho phép phụ âm z, f, w, j.")
    }

    private var zfwjHint: String {
        // D22, D23: in Telex a leading w is always ư, noted only while Telex is used.
        settings.typingMethod == .telex
            ? String(localized: "Dành cho từ mượn và tên riêng. Bật mục này sẽ tắt Gõ tắt phụ âm. Với Telex, w ở đầu từ luôn thành ư nên mục này chỉ có tác dụng với z, f, j.")
            : String(localized: "Dành cho từ mượn và tên riêng. Bật mục này sẽ tắt Gõ tắt phụ âm.")
    }
}

extension EnvironmentValues {
    /// Opens "Nâng cao" when the page appears (snapshots of the expanded state).
    @Entry var smartAdvancedExpanded = false
}
