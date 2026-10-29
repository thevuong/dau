import SwiftUI

/// The Settings window (mockup "SettingsTyping" and siblings): a 220 pt sidebar with
/// search, the four sections and "Dấu <version>" at the bottom; each page has its own
/// fixed header with the section name.
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 260)
        } detail: {
            SettingsDetail(section: selection ?? .typing)
        }
        // No toolbar: the page header plays its role, so nothing in the title bar
        // changes from one section to another.
        .toolbar(.hidden, for: .windowToolbar)
        .background(HiddenWindowTitle())
        .frame(minWidth: 820, minHeight: 560)
        .layoutProbe("window")
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
    }
}
