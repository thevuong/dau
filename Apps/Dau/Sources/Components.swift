import AppKit
import SwiftUI
import DauShared

// Layout primitives for the Settings pages, sized after the mockup's CSS (docs/UI.md,
// canvas artboards "Settings…"): content inset 20 top / 28 sides, 18 between sections,
// section titles 13 semibold outside the card, cards with radius 14 and a hairline,
// rows at least 48 tall with 16/10 padding, 13 pt labels, 12 pt secondary hints, and
// separators inset 16. Controls inside are standard SwiftUI controls (D9).

/// Colors derived from the system control background (white in light mode, #1e in
/// dark mode, not tinted by the wallpaper), so light and dark follow the system: the
/// page is that color darkened a touch in light mode, the card is that color lifted a
/// touch in dark mode — the mockup's #f5f5f7/#fff and #1e1e20/#2c2c2e.
enum SettingsColors {
    static let page = Color(nsColor: NSColor(name: nil) { appearance in
        let base = NSColor.controlBackgroundColor.resolved(for: appearance)
        return appearance.isDark ? base : base.blended(withFraction: 0.035, of: .black) ?? base
    })

    static let card = Color(nsColor: NSColor(name: nil) { appearance in
        let base = NSColor.controlBackgroundColor.resolved(for: appearance)
        return appearance.isDark ? base.blended(withFraction: 0.07, of: .white) ?? base : base
    })

    static let hairline = Color(nsColor: .separatorColor).opacity(0.6)
}

extension NSColor {
    /// This dynamic color as concrete sRGB values under `appearance`.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var result = self
        appearance.performAsCurrentDrawingAppearance {
            result = self.usingColorSpace(.sRGB) ?? self
        }
        return result
    }
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

/// A Settings page: title in the window toolbar, banner on top, then the sections.
struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NotEnabledBanner()
                content
            }
            .padding(.top, 20)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SettingsColors.page)
    }
}

/// Section title (13 semibold, outside the card) and its content, 8 apart.
struct SettingsGroup<Content: View, Footer: View>: View {
    let title: Text?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    init(_ title: Text? = nil, @ViewBuilder content: () -> Content,
         @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                title
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            content
            footer
        }
    }
}

/// A rounded card holding rows.
struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SettingsColors.hairline, lineWidth: 1)
        }
    }
}

/// Separator between rows, inset 16 from the leading edge.
struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 16)
    }
}

/// A row: label with an optional hint below it, and trailing controls.
struct SettingsRow<Label: View, Trailing: View>: View {
    var minHeight: CGFloat = 48
    @ViewBuilder var label: Label
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) { label }
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: minHeight)
    }
}

extension SettingsRow where Label == RowLabel {
    init(_ title: Text, hint: Text? = nil, minHeight: CGFloat = 48,
         @ViewBuilder trailing: () -> Trailing) {
        self.minHeight = minHeight
        self.label = RowLabel(title: title, hint: hint)
        self.trailing = trailing()
    }
}

/// Row title (13) and hint (12, secondary).
struct RowLabel: View {
    let title: Text
    let hint: Text?

    var body: some View {
        title
        if let hint {
            Hint(hint)
        }
    }
}

/// 12 pt secondary text.
struct Hint: View {
    let text: Text
    init(_ text: Text) { self.text = text }

    var body: some View {
        text
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A switch whose label is only read by VoiceOver (the row shows the visible label).
struct RowSwitch: View {
    let label: Text
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { label }
            .toggleStyle(.switch)
            .labelsHidden()
    }
}

/// Capsule label: configuration chips, "Đề xuất". A label, not a control.
struct Chip: View {
    let text: Text
    var height: CGFloat = 22
    var fontSize: CGFloat = 12
    var monospaced = false
    var tint: Color?

    init(_ text: Text, height: CGFloat = 22, fontSize: CGFloat = 12,
         monospaced: Bool = false, tint: Color? = nil) {
        self.text = text
        self.height = height
        self.fontSize = fontSize
        self.monospaced = monospaced
        self.tint = tint
    }

    var body: some View {
        text
            .font(.system(size: fontSize, weight: tint == nil ? .regular : .semibold,
                          design: monospaced ? .monospaced : .default))
            .foregroundStyle(tint == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: height)
            .background(tint.map { AnyShapeStyle($0.opacity(0.18)) } ?? AnyShapeStyle(.quaternary),
                        in: Capsule())
    }
}

/// "Mới" badge: accent fill, white text.
struct NewBadge: View {
    var body: some View {
        Text("Mới")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Color.accentColor, in: Capsule())
    }
}

/// "keys › result" as two chips, the result tinted green (mockup "Thông minh").
/// Both come from the engine (`TypingExample`). VoiceOver reads "keys thành result".
struct ExampleChips: View {
    let example: TypingExample

    var body: some View {
        HStack(spacing: 6) {
            Chip(Text(verbatim: keysText), monospaced: true)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            Chip(Text(verbatim: example.result), tint: .green)
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

/// "Dấu chưa được bật" banner on top of every section (docs/UI.md, "Các trạng thái
/// bổ sung"), shown while Dấu is not among the enabled input sources.
struct NotEnabledBanner: View {
    @Environment(InputSourceStatus.self) private var status

    var body: some View {
        if status.isEnabled == false {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dấu chưa được bật trong Nguồn nhập liệu")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Bạn vẫn chỉnh được cài đặt, nhưng chưa gõ được tiếng Việt.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // TODO(M5): register and enable the input source here (D14 step 2,
                // with undo). Until then the button opens Keyboard settings, where the
                // user adds Dấu back (N4).
                Button("Bật lại") { SystemSettings.openKeyboard() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
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
