import AppKit
import SwiftUI
import DauShared

// Layout primitives for the Settings pages, sized after the mockup's CSS (docs/UI.md,
// canvas artboards "Settings…"): content inset 20 top / 28 sides, 18 between sections,
// section titles 13 semibold outside the card and 8 above it, cards with radius 14 and
// a 1 pt separator border, rows at least 48 tall with 16/10 padding, 13 pt labels,
// 12 pt secondary hints, separators inset 16. Controls are standard SwiftUI controls
// (D9); backgrounds use system colors only.

/// Page and card backgrounds, chosen among system colors (no blending, no opacity) so
/// the card is lighter than the page in both appearances, as in the mockup. Resolved
/// in the real Settings window on macOS 27 (`--capture-window`):
/// - light: page `underPageBackgroundColor` (light gray), card `controlBackgroundColor`
///   (white), as the mockup's light gray page and white cards;
/// - dark: page `controlBackgroundColor` (near black), card `underPageBackgroundColor`
///   (dark gray), as the mockup's dark page and lighter cards.
/// Both are dynamic system colors, so they follow Increase Contrast too.
enum SettingsColors {
    static let page = Color(nsColor: NSColor(name: "DauSettingsPage") { appearance in
        appearance.isDark ? .controlBackgroundColor : .underPageBackgroundColor
    })

    static let card = Color(nsColor: NSColor(name: "DauSettingsCard") { appearance in
        appearance.isDark ? .underPageBackgroundColor : .controlBackgroundColor
    })

    static let separator = Color(nsColor: .separatorColor)
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

/// Search field and + button on the trailing side of a page header (mockup
/// "SettingsApps": a 180 pt search pill, 10 pt gap, a separate 30 pt round + button).
struct HeaderActions {
    var query: Binding<String>
    var prompt: String
    var addLabel: String
    var onAdd: () -> Void
}

/// A Settings page. Its title is a toolbar item on the leading edge of the window's
/// toolbar, in the title-bar row next to the traffic lights (mockup header, 15 bold);
/// `actions` go on the trailing edge. Every page has the title item, so the toolbar
/// keeps the same height and the title the same place in every section.
/// Scrolling: the content scrolls under the toolbar, which covers it with the
/// system's hard scroll-edge effect on macOS 26+ (a solid material edge, so the title
/// stays readable) and with the toolbar's own material and separator on macOS 14–15.
/// The scroll view fills the detail column up to the window's right edge; its content
/// fills the scroll view's width. Scroll indicators follow the system setting: overlay
/// scroll bars take no room; a legacy scroll bar appears, and takes its width, only on
/// a page that scrolls (`.scrollIndicators(.visible)` does not keep it on pages that
/// fit — measured, see docs/UI-CHECKS.md).
///
/// On macOS 26 and later the toolbar groups adjacent items on one glass background; a
/// fixed spacer splits the search field and the + button into two controls, as in
/// the mockup. Their shapes are the system's (D9). macOS 14–15 have no glass: the
/// two controls sit 10 pt apart in the toolbar.
struct SettingsPage<Content: View>: View {
    let title: String
    var actions: HeaderActions?
    @ViewBuilder var content: Content

    init(_ title: String, actions: HeaderActions? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.actions = actions
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                NotEnabledBanner()
                content
            }
            .padding(.top, 20)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            // Fill the scroll view's width; the system leaves out a legacy scroll bar
            // when it shows one. No width is computed here.
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutProbe("content")
        }
        .scrollIndicators(.visible)
        .modifier(HardTopScrollEdge())
        .background(SettingsColors.page)
        .toolbar {
            if #available(macOS 26, *) {
                ToolbarItem(placement: .navigation) { PageTitle(title: title) }
                    .sharedBackgroundVisibility(.hidden)
                if let actions {
                    // Two items with a fixed spacer: the toolbar draws them as two
                    // separate controls instead of one shared glass group.
                    ToolbarItem(placement: .primaryAction) { HeaderSearchField(actions: actions) }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItem(placement: .primaryAction) { HeaderAddButton(actions: actions) }
                }
            } else {
                ToolbarItem(placement: .navigation) { PageTitle(title: title) }
                if let actions {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 10) {
                            HeaderSearchField(actions: actions)
                            HeaderAddButton(actions: actions)
                        }
                    }
                }
            }
        }
    }
}

/// macOS 26+: the hard scroll-edge effect under the toolbar (system material and
/// edge), so content scrolled under the header never shows through the title.
struct HardTopScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
    }
}

/// The header search field: the system search field, 200 pt wide (the mockup's 180 pt
/// field plus its 10 pt padding on each side).
struct HeaderSearchField: View {
    let actions: HeaderActions

    var body: some View {
        SearchField(text: actions.query, prompt: actions.prompt)
            .frame(width: 200)
            .layoutProbe("headerSearch")
    }
}

/// The header + button: a system button with a 15 pt +.
struct HeaderAddButton: View {
    let actions: HeaderActions

    var body: some View {
        Button(action: actions.onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                // The toolbar fixes the bezel height; widen the label so the bezel
                // comes out as wide as it is tall (a circle, not an oval).
                .frame(width: 26, height: 18)
        }
        .controlSize(.large)
        .buttonBorderShape(.circle)
        .help(Text(verbatim: actions.addLabel))
        .accessibilityLabel(Text(verbatim: actions.addLabel))
        .layoutProbe("headerAdd")
    }
}

/// The page title in the toolbar: 15 pt bold, primary.
struct PageTitle: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.primary)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
            .layoutProbe("title")
            // Fixed item width: the item, and so the title, never moves with the text.
            // The leading inset puts the title 24 pt from the sidebar, as in the mockup.
            .padding(.leading, 17)
            .frame(width: 320, alignment: .leading)
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
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            content
            footer
        }
    }
}

/// A rounded card holding rows: radius 14, 1 pt separator border.
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
                .strokeBorder(SettingsColors.separator, lineWidth: 1)
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

/// Row title (13, primary) and hint (12, secondary).
struct RowLabel: View {
    let title: Text
    let hint: Text?

    var body: some View {
        title.foregroundStyle(.primary)
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
            .multilineTextAlignment(.leading)
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
            .layoutProbe("switch")
    }
}

extension View {
    /// Buttons as in the mockup: capsule, about 30 pt tall.
    func settingsButton() -> some View {
        self.controlSize(.large).buttonBorderShape(.capsule)
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

/// "Dấu chưa được bật" banner (docs/UI.md, "Các trạng thái bổ sung", mockup
/// "SettingsNotEnabled"), first on every page while Dấu is not among the enabled
/// input sources: orange tile with a white warning symbol, title, subtitle,
/// prominent button, on a system-orange tint.
struct NotEnabledBanner: View {
    @Environment(InputSourceStatus.self) private var status

    var body: some View {
        if status.isEnabled == false {
            HStack(alignment: .center, spacing: 12) {
                // Mockup "SettingsNotEnabled": a 28 pt orange tile, radius 8, white
                // warning symbol; an orange-tinted banner. System orange only (D9).
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dấu chưa được bật trong Nguồn nhập liệu")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Hint(Text("Bạn vẫn chỉnh được cài đặt, nhưng chưa gõ được tiếng Việt."))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // TODO(M5): register and enable the input source here (D14 step 2,
                // with undo). Until then the button opens Keyboard settings, where the
                // user adds Dấu back (N4).
                Button("Bật lại") { SystemSettings.openKeyboard() }
                    .buttonStyle(.borderedProminent)
                    .settingsButton()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.orange.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.tertiary, lineWidth: 1)
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
