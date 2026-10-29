import AppKit
import SwiftUI
import DauShared

// Page structure shared by the four Settings sections. The system draws every
// background, card, separator and material (`Form` with `.grouped` style, D9); this
// file only arranges content inside the rows the way the mockup does. Text uses
// semantic colors only (.primary / .secondary), accents follow the user's accent color.

/// A Settings page: a fixed header (section title on the left, optional controls on the
/// right, separator below — mockup header, 52 pt, title 15 bold), then a grouped form
/// that fills the rest of the window and starts at the top. The header never moves
/// between sections, whatever the page contains (banner, search field, scroll bar).
struct SettingsPage<Accessory: View, Content: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(verbatim: title)
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .layoutProbe("title")
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessory
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .layoutProbe("header")
            Divider()
            Form {
                NotEnabledBanner()
                content
            }
            .formStyle(.grouped)
            .layoutProbe("form")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Row label with a hint below it (13 pt / 12 pt secondary), for Toggle, Picker and
/// LabeledContent labels.
struct RowLabel: View {
    let title: Text
    var hint: Text?

    init(_ title: Text, hint: Text? = nil) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            if let hint {
                hint
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A row with a label (and hint) on the left and controls on the right.
struct SettingsRow<Trailing: View>: View {
    let label: RowLabel
    @ViewBuilder var trailing: Trailing

    init(_ title: Text, hint: Text? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.label = RowLabel(title, hint: hint)
        self.trailing = trailing()
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) { trailing }
        } label: {
            label
        }
    }
}

/// Capsule label: configuration chips, "Đề xuất", example keys. A label, not a control.
struct Chip: View {
    let text: Text
    var height: CGFloat = 22
    var fontSize: CGFloat = 12
    var monospaced = false
    /// Emphasized: the result of an example.
    var emphasized = false

    init(_ text: Text, height: CGFloat = 22, fontSize: CGFloat = 12,
         monospaced: Bool = false, emphasized: Bool = false) {
        self.text = text
        self.height = height
        self.fontSize = fontSize
        self.monospaced = monospaced
        self.emphasized = emphasized
    }

    var body: some View {
        text
            .font(.system(size: fontSize, weight: emphasized ? .semibold : .regular,
                          design: monospaced ? .monospaced : .default))
            .foregroundStyle(emphasized ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: height)
            .background(.fill.tertiary, in: Capsule())
    }
}

/// "Mới" badge: accent fill with the system's text-on-accent color.
struct NewBadge: View {
    var body: some View {
        Text("Mới")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: .alternateSelectedControlTextColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Color.accentColor, in: Capsule())
    }
}

/// "keys › result" as two chips (mockup "Thông minh"); the result is emphasized.
/// Both come from the engine (`TypingExample`). VoiceOver reads "keys thành result".
struct ExampleChips: View {
    let example: TypingExample

    var body: some View {
        HStack(spacing: 6) {
            Chip(Text(verbatim: keysText), monospaced: true)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Chip(Text(verbatim: example.result), emphasized: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(keysText) thành \(example.result)"))
    }

    private var keysText: String {
        example.displayed.isEmpty ? example.keys : "\(example.displayed) + \(example.keys)"
    }
}

/// Lays chips out left to right and wraps to the next line when the row is full.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 14
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// "Dấu chưa được bật" banner (docs/UI.md, "Các trạng thái bổ sung"): the first group
/// of every page while Dấu is not among the enabled input sources. A system card with
/// the multicolor warning symbol and a prominent button.
struct NotEnabledBanner: View {
    @Environment(InputSourceStatus.self) private var status

    var body: some View {
        if status.isEnabled == false {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 22))
                        .accessibilityHidden(true)
                    RowLabel(Text("Dấu chưa được bật trong Nguồn nhập liệu").fontWeight(.semibold),
                             hint: Text("Bạn vẫn chỉnh được cài đặt, nhưng chưa gõ được tiếng Việt."))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // TODO(M5): register and enable the input source here (D14 step 2,
                    // with undo). Until then the button opens Keyboard settings, where
                    // the user adds Dấu back (N4).
                    Button("Bật lại") { SystemSettings.openKeyboard() }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

/// Version string for display ("1.0.0"), or nil when the bundle has none: never "?".
enum AppVersion {
    static var marketing: String? {
        guard let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !v.isEmpty, !v.contains("$(") else { return nil }
        return v
    }

    /// "Dấu 1.0.0", or "Dấu" without a version.
    static var nameAndVersion: String {
        marketing.map { "Dấu \($0)" } ?? "Dấu"
    }
}

// MARK: - Layout probe (tests only)

/// Reports a view's frame in window coordinates. Nil in the app, so probes cost
/// nothing; `scripts/snapshot-settings` sets it to check that the layout does not move
/// between sections.
struct LayoutProbeKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable (String, CGRect) -> Void)? = nil
}

extension EnvironmentValues {
    var layoutProbe: (@MainActor @Sendable (String, CGRect) -> Void)? {
        get { self[LayoutProbeKey.self] }
        set { self[LayoutProbeKey.self] = newValue }
    }
}

struct LayoutProbeModifier: ViewModifier {
    @Environment(\.layoutProbe) private var probe
    let name: String

    func body(content: Content) -> some View {
        if let probe {
            content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                probe(name, frame)
            }
        } else {
            content
        }
    }
}

extension View {
    func layoutProbe(_ name: String) -> some View {
        modifier(LayoutProbeModifier(name: name))
    }
}
