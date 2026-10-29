import SwiftUI

/// The Settings window (mockup "SettingsTyping" and siblings): a 220 pt sidebar with
/// search, the four sections and "Dấu <version>" at the bottom; each page's title is
/// in the toolbar row, next to the traffic lights.
struct SettingsWindow: View {
    @State private var selection: SettingsSection?
    @State private var query = ""

    init(initialSection: SettingsSection = .typing) {
        _selection = State(initialValue: initialSection)
    }

    private var visibleSections: [SettingsSection] {
        SettingsSection.allCases.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(visibleSections, selection: $selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    SectionIcon(section: section)
                }
                .frame(minHeight: 28)
                .layoutProbe("sidebarRow-\(section.rawValue)")
                .tag(section)
            }
            .searchable(text: $query, placement: .sidebar, prompt: Text("Tìm kiếm"))
            .onChange(of: query) {
                // Jump to the first match so the result is visible right away.
                if let first = visibleSections.first, selection.map(visibleSections.contains) != true {
                    selection = first
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .leading) {
                Text(verbatim: AppVersion.nameAndVersion)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
            .toolbar(removing: .sidebarToggle)
            .layoutProbe("sidebar")
            // Must stay the last modifier of the column to take effect.
            .navigationSplitViewColumnWidth(220)
        } detail: {
            SettingsDetail(section: selection ?? .typing)
        }
        // The window title text is hidden; each page puts its title as a leading
        // toolbar item instead, so it sits in the title-bar row next to the traffic
        // lights and at the same place in every section.
        .background(HiddenWindowTitle())
        .frame(minWidth: 760, minHeight: 520)
        .layoutProbe("window")
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: DebugCapture.selectSection)) { note in
            if let raw = note.object as? String { selection = SettingsSection(rawValue: raw) }
        }
        #endif
    }
}

/// One section page; its title also names the window (Window menu, VoiceOver).
struct SettingsDetail: View {
    let section: SettingsSection

    var body: some View {
        Group {
            switch section {
            case .typing: TypingSettingsView()
            case .smart: SmartSettingsView()
            case .apps: AppRulesView()
            case .updates: UpdatesSupportView()
            }
        }
        .navigationTitle(section.title)
        .modifier(RemoveToolbarTitle())
    }
}

/// The page title is a toolbar item already (`SettingsPage`); remove the system title
/// so it is not drawn twice. The navigation title still names the window.
struct RemoveToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
