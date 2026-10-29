import SwiftUI
import DauShared

/// "Dấu chưa được bật" banner shown on top of every section (docs/UI.md, "Các trạng
/// thái bổ sung") while Dấu is not among the enabled input sources.
struct NotEnabledBanner: View {
    @Environment(InputSourceStatus.self) private var status

    var body: some View {
        if status.isEnabled == false {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dấu chưa được bật")
                        .font(.headline)
                    Text("Bạn vẫn chỉnh được cài đặt, nhưng chưa gõ được tiếng Việt.")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                // TODO(M5): register and enable the input source here (D14 step 2,
                // with undo). Until then the button opens Keyboard settings, where the
                // user adds Dấu back (N4).
                Button("Bật lại") { SystemSettings.openKeyboard() }
            }
            .padding(12)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.orange.opacity(0.4))
            }
            .accessibilityElement(children: .contain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
}

/// A form page: the banner pinned on top, then a grouped form. The form's own
/// background is hidden so banner and form sit on the same window background.
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            NotEnabledBanner()
            Form { content }
                .scrollContentBackground(.hidden)
        }
    }
}

/// Small capsule label ("chip", "Mới", "Đề xuất"). A label, not a control.
struct Chip: View {
    let text: Text

    init(_ text: Text) { self.text = text }

    var body: some View {
        text
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

/// "keys → result", both produced by the engine (`TypingExample`). Keys are shown in a
/// monospaced font, as typed. VoiceOver reads "keys thành result".
struct ExampleView: View {
    let example: TypingExample
    var font: Font = .body

    var body: some View {
        HStack(spacing: 6) {
            if !example.displayed.isEmpty {
                Text(verbatim: example.displayed)
                Text(verbatim: "+").foregroundStyle(.secondary)
            }
            Text(verbatim: example.keys)
                .monospaced()
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(verbatim: example.result)
        }
        .font(font)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        if example.displayed.isEmpty {
            Text("\(example.keys) thành \(example.result)")
        } else {
            Text("\(example.displayed) gõ thêm \(example.keys) thành \(example.result)")
        }
    }
}
