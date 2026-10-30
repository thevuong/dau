import SwiftUI
import DauShared

/// "Gõ phím" (mockup "SettingsTyping"): preview, typing method, tone placement, free
/// marking, and the system shortcut that switches input sources, e.g. Dấu ↔ ABC (D2).
struct TypingSettingsView: View {
    @Environment(SettingsModel.self) private var model
    var shortcut: InputSourceShortcut? = InputSourceShortcut.current()

    var body: some View {
        @Bindable var model = model
        SettingsPage(SettingsSection.typing.title) {
            PreviewCard(settings: model.settings)

            SettingsGroup(Text("Kiểu gõ")) {
                SettingsCard {
                    SegmentedPicker(String(localized: "Kiểu gõ"), selection: $model.settings.typingMethod,
                                    options: DauSettings.TypingMethod.allCases.map { ($0, $0.title) })
                        .layoutProbe("segmented")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 48)
                    RowDivider()
                    SettingsRow(Text("Vị trí dấu thanh"),
                                hint: Text("Kiểu mới: hoà, thuý · Kiểu cũ: hòa, thúy")) {
                        SegmentedPicker(String(localized: "Vị trí dấu thanh"),
                                        selection: $model.settings.tonePlacement,
                                        options: DauSettings.TonePlacement.allCases.map { ($0, $0.title) })
                            .frame(width: 220)
                    }
                    RowDivider()
                    SettingsRow(Text("Bỏ dấu tự do"), hint: Text("Gõ phím dấu ở bất kỳ đâu sau nguyên âm")) {
                        RowSwitch(label: Text("Bỏ dấu tự do"), isOn: $model.settings.freeMarking)
                    }
                }
            }

            SettingsGroup(Text("Chuyển Tiếng Việt ↔ Tiếng Anh")) {
                SettingsCard {
                    SettingsRow(Text("Phím tắt nguồn nhập liệu"),
                                hint: Text("Dùng chung phím tắt của macOS, đổi trong Cài đặt Bàn phím")) {
                        ShortcutKeycaps(shortcut: shortcut)
                            .padding(.trailing, 6)
                        Button("Đổi…") { SystemSettings.openKeyboard() }
                            .settingsButton()
                            .layoutProbe("button")
                            .accessibilityHint(Text("Mở Cài đặt Bàn phím của macOS"))
                    }
                }
            }
        }
    }
}

/// The "Xem trước" card: chips for the configuration, then keys › result computed by
/// the engine with the current settings, in two boxes set into the card.
struct PreviewCard: View {
    let settings: DauSettings

    var body: some View {
        let example = SettingsSamples.preview(settings)
        SettingsCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Xem trước")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Chip(Text(settings.typingMethod.title))
                    Chip(Text(settings.tonePlacement.title))
                }
                HStack(spacing: 10) {
                    PreviewBox {
                        Text(verbatim: example.keys)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    PreviewBox {
                        Text(verbatim: example.result)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(example.keys) thành \(example.result)"))
            }
        }
        .layoutProbe("firstCard")
    }
}

/// One of the two equal boxes of the preview: radius 10, height 40, page color so it
/// reads as set into the card.
struct PreviewBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
            .background(SettingsColors.page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// The input-source shortcut as keycaps, or the placeholder when it cannot be read.
struct ShortcutKeycaps: View {
    let shortcut: InputSourceShortcut?

    var body: some View {
        if let shortcut, !shortcut.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(shortcut.keys.enumerated()), id: \.offset) { _, key in
                    Keycap(key)
                }
                if shortcut.globeKey {
                    if !shortcut.keys.isEmpty {
                        Text("hoặc")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)
                    }
                    Keycap("🌐")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Phím tắt hiện tại"))
            .accessibilityValue(Text(verbatim: spokenValue(shortcut)))
        } else {
            // Not readable: keep the placeholder rather than guess (N5).
            Text("[Phím tắt hệ thống]")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func spokenValue(_ shortcut: InputSourceShortcut) -> String {
        var parts = [shortcut.keys.joined(separator: " ")]
        if shortcut.globeKey { parts.append("🌐") }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// A key cap: radius 6, height 24, 12 pt text; system fill and separator.
struct Keycap: View {
    let key: String
    init(_ key: String) { self.key = key }

    var body: some View {
        Text(verbatim: key)
            .font(.system(size: 12))
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 24, maxHeight: 24)
            .background(.fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
    }
}

extension DauSettings.TypingMethod {
    var title: String {
        switch self {
        case .telex: String(localized: "Telex")
        case .vni: String(localized: "VNI")
        case .simpleTelex: String(localized: "Telex đơn giản")
        }
    }
}

extension DauSettings.TonePlacement {
    var title: String {
        switch self {
        case .modern: String(localized: "Kiểu mới")
        case .classic: String(localized: "Kiểu cũ")
        }
    }
}
