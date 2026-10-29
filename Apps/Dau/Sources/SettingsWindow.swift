import SwiftUI

/// The Settings window: sidebar with search and four sections (docs/UI.md). The title
/// bar shows the selected section's name.
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
            // Wide enough for the longest section name, "Cập nhật & hỗ trợ".
            .navigationSplitViewColumnWidth(min: 220, ideal: 230, max: 300)
        } detail: {
            SettingsDetail(section: selection ?? .typing)
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}

/// One section, with the "Dấu chưa được bật" banner on top when needed.
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
        .formStyle(.grouped)
        .navigationTitle(section.title)
    }
}
