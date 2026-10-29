import SwiftUI
import DauShared

/// "Gõ phím": preview, typing method, tone placement, free marking, and the system
/// shortcut that switches Tiếng Việt ↔ Tiếng Anh (D2).
struct TypingSettingsView: View {
    @Environment(SettingsModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsPage {
            Section {
                PreviewCard(settings: model.settings)
            } header: {
                Text("Xem trước")
            }

            Section {
                Picker("Kiểu gõ", selection: $model.settings.typingMethod) {
                    ForEach(DauSettings.TypingMethod.allCases, id: \.self) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                Picker(selection: $model.settings.tonePlacement) {
                    ForEach(DauSettings.TonePlacement.allCases, id: \.self) { placement in
                        Text(placement.title).tag(placement)
                    }
                } label: {
                    Text("Vị trí dấu thanh")
                    Text(verbatim: "hoà, thuý · hòa, thúy")
                }
                .pickerStyle(.segmented)

                Toggle(isOn: $model.settings.freeMarking) {
                    Text("Bỏ dấu tự do")
                    Text("Gõ phím dấu ở bất kỳ đâu sau nguyên âm, dấu tự vào đúng chỗ.")
                }
            }

            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        // No public API reads the system input-source shortcut, so the
                        // keycap stays a placeholder rather than a guess (N5, D2).
                        Text("[Phím tắt hệ thống]")
                            .foregroundStyle(.secondary)
                        Button("Đổi…") { SystemSettings.openKeyboard() }
                            .accessibilityHint(Text("Mở Cài đặt Bàn phím của macOS"))
                    }
                } label: {
                    Text("Chuyển Tiếng Việt ↔ Tiếng Anh")
                    Text("Dùng phím tắt chuyển nguồn nhập liệu của macOS.")
                }
            }
        }
    }
}

/// The "Xem trước" card: keys → result computed by the engine with the current
/// settings, and chips summarizing them.
struct PreviewCard: View {
    let settings: DauSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(SettingsExamples.preview(settings)) { example in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: example.keys)
                        .monospaced()
                        .foregroundStyle(.secondary)
                    Text(verbatim: example.result)
                        .font(.title3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(example.keys) thành \(example.result)"))
            }
            HStack(spacing: 6) {
                Chip(Text(settings.typingMethod.title))
                Chip(Text(settings.tonePlacement.title))
                if settings.freeMarking {
                    Chip(Text("Bỏ dấu tự do"))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Cấu hình hiện tại"))
            .accessibilityValue(chipsSummary)
        }
        .padding(.vertical, 4)
    }

    private var chipsSummary: Text {
        var parts = [settings.typingMethod.title, settings.tonePlacement.title]
        if settings.freeMarking { parts.append(String(localized: "Bỏ dấu tự do")) }
        return Text(verbatim: parts.joined(separator: ", "))
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
