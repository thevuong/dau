import SwiftUI
import DauShared

/// "Thông minh" (mockups "SettingsSmart", "SettingsSmartAdvanced"): automatic restore
/// of foreign words (D4), adding marks to a typed word (D20), and the collapsed
/// "Nâng cao" group (D21, D22, D23).
struct SmartSettingsView: View {
    @Environment(SettingsModel.self) private var model
    @Environment(\.smartAdvancedExpanded) private var expandedAtStart
    @State private var advancedExpanded = false

    var body: some View {
        @Bindable var model = model
        let method = model.settings.typingMethod
        SettingsPage(SettingsSection.smart.title) {
            SettingsGroup(Text("Gõ lẫn từ nước ngoài")) {
                SettingsCard {
                    SettingsRow(
                        Text("Tự khôi phục từ không phải tiếng Việt"),
                        hint: Text("Khi gõ xong một từ (Space, dấu câu, Enter), từ không phải âm tiết tiếng Việt hợp lệ trở về đúng như bạn gõ")
                    ) {
                        RowSwitch(label: Text("Tự khôi phục từ không phải tiếng Việt"),
                                  isOn: $model.settings.autoRestore)
                    }
                    RowDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        WrappingHStack {
                            ForEach(SettingsSamples.restore(method)) { ExampleChips(example: $0) }
                        }
                        let wins = SettingsSamples.vietnameseWins(method)
                        let keep = SettingsSamples.keepOriginal(method)
                        Hint(Text("Từ trùng với tiếng Việt thì tiếng Việt được ưu tiên: “\(wins.keys)” ra “\(wins.result)”. Muốn giữ chữ gốc, gõ đúp phím dấu: “\(keep.keys)” ra “\(keep.result)”."))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }
                .layoutProbe("firstCard")
            }

            SettingsGroup(Text("Sửa từ đã gõ")) {
                SettingsCard {
                    SettingsRow {
                        HStack(spacing: 6) {
                            Text("Thêm dấu cho từ đã gõ")
                            NewBadge()
                        }
                        // N5: the input method does not seed the engine from the app's
                        // text yet (D20); the switch stays off-limits until it does. The
                        // stored setting (D15 default) is unchanged.
                        Hint(Text("[Thêm dấu cho từ đã gõ — có ở bản sau (M3)]"))
                    } trailing: {
                        RowSwitch(label: Text("Thêm dấu cho từ đã gõ"),
                                  isOn: $model.settings.addMarksToTypedWords)
                            .disabled(true)
                    }
                    RowDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        // The engine computes this example; the feature around it is
                        // not in the input method yet.
                        Hint(Text("Ví dụ của tính năng sắp có:"))
                        WrappingHStack {
                            ExampleChips(example: SettingsSamples.addMarks(method))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                }
            }

            SettingsCard {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { advancedExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(advancedExpanded ? 90 : 0))
                        Text("Nâng cao")
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Hint(Text(advancedSummary(model.settings.advanced)))
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Nâng cao"))
                .accessibilityValue(Text(advancedSummary(model.settings.advanced)))
                .accessibilityHint(advancedExpanded ? Text("Thu gọn") : Text("Mở rộng"))

                if advancedExpanded {
                    RowDivider()
                    AdvancedOptions(settings: $model.settings)
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
        SettingsRow(Text("Gõ tắt phụ âm"), hint: Text(shortcutsHint)) {
            RowSwitch(label: Text("Gõ tắt phụ âm"), isOn: $settings.consonantShortcuts)
        }
        RowDivider()
        SettingsRow(Text("Cho phép phụ âm z, f, w, j"), hint: Text(zfwjHint)) {
            RowSwitch(label: Text("Cho phép phụ âm z, f, w, j"), isOn: $settings.allowZFWJ)
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
