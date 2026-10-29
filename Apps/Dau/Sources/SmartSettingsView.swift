import SwiftUI
import DauShared

/// "Thông minh": automatic restore of foreign words (D4), adding marks to a typed word
/// (D20), and the collapsed "Nâng cao" group (D21, D22, D23).
struct SmartSettingsView: View {
    @Environment(SettingsModel.self) private var model
    @State private var advancedExpanded: Bool

    init(advancedExpanded: Bool = false) {
        _advancedExpanded = State(initialValue: advancedExpanded)
    }

    var body: some View {
        @Bindable var model = model
        let method = model.settings.typingMethod
        SettingsPage {
            Section {
                Toggle(isOn: $model.settings.autoRestore) {
                    Text("Tự khôi phục từ không phải tiếng Việt")
                    Text("Khi kết thúc từ, từ không phải âm tiết tiếng Việt hợp lệ trở về đúng như đã gõ.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsExamples.restore(method)) { ExampleView(example: $0) }
                }
                .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 4) {
                    let wins = SettingsExamples.vietnameseWins(method)
                    let keep = SettingsExamples.keepOriginal(method)
                    Text("Từ trùng thì tiếng Việt thắng (\(wins.keys) → \(wins.result)).")
                    Text("Gõ đúp phím dấu để giữ chữ gốc (\(keep.keys) → \(keep.result)).")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text("Gõ lẫn từ nước ngoài")
            }

            Section {
                Toggle(isOn: $model.settings.addMarksToTypedWords) {
                    HStack(spacing: 6) {
                        Text("Thêm dấu cho từ đã gõ")
                        Chip(Text("Mới"))
                    }
                }
                ExampleView(example: SettingsExamples.addMarks(method))
                // N5: stability on web editors is an open question in DECISIONS.md;
                // the note stays a placeholder until it is measured.
                Text("[Kết quả kiểm chứng trên Google Docs, Notion…]")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Sửa từ đã gõ")
            }

            Section {
                DisclosureGroup(isExpanded: $advancedExpanded) {
                    AdvancedOptions(settings: $model.settings)
                } label: {
                    HStack {
                        Text("Nâng cao")
                        Spacer()
                        Text(advancedSummary(model.settings.advanced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
            Text("Gõ tắt phụ âm")
            Text(shortcutsDescription)
            Text("Bật mục này sẽ tắt Cho phép phụ âm z, f, w, j.")
        }
        Toggle(isOn: $settings.allowZFWJ) {
            Text("Cho phép phụ âm z, f, w, j")
            if settings.typingMethod == .telex {
                // D22, D23: in Telex a leading w is always ư.
                Text("Với Telex, w ở đầu từ luôn thành ư nên mục này chỉ có tác dụng với z, f, j.")
            }
            Text("Bật mục này sẽ tắt Gõ tắt phụ âm.")
        }
    }

    private var shortcutsDescription: String {
        // D21; w → qu exists only in VNI (D23).
        settings.typingMethod == .vni
            ? String(localized: "Đầu từ f → ph, j → gi, w → qu; cuối từ g → ng, h → nh, k → ch. Áp dụng khi kết thúc từ và chỉ khi ra từ hợp lệ.")
            : String(localized: "Đầu từ f → ph, j → gi; cuối từ g → ng, h → nh, k → ch. Áp dụng khi kết thúc từ và chỉ khi ra từ hợp lệ.")
    }
}
