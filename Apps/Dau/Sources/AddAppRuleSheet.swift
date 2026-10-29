import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DauShared

/// "Thêm quy tắc ứng dụng" sheet (docs/UI.md): search, a list of apps (running apps,
/// plus any app picked with "Chọn ứng dụng khác…"), "Khi mở app" and "Khi đang gõ",
/// Huỷ / Thêm.
struct AddAppRuleSheet: View {
    @Environment(SettingsModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var candidates: [AppCandidate] = []
    @State private var selection: AppCandidate.ID?
    @State private var mode: AppRule.Mode = .vietnamese
    @State private var underline = false

    private var visibleCandidates: [AppCandidate] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.name.localizedStandardContains(query) || $0.bundleID.localizedStandardContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thêm quy tắc ứng dụng")
                .font(.headline)

            TextField("Tìm ứng dụng", text: $query, prompt: Text("Tìm ứng dụng"))
                .textFieldStyle(.roundedBorder)

            List(visibleCandidates, selection: $selection) { candidate in
                HStack(spacing: 8) {
                    Image(nsImage: candidate.icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(verbatim: candidate.name)
                }
                .tag(candidate.id)
            }
            .listStyle(.bordered)
            .frame(minHeight: 180)
            .accessibilityLabel(Text("Danh sách ứng dụng"))

            Button("Chọn ứng dụng khác…", action: chooseApp)

            Form {
                Picker("Khi mở app", selection: $mode) {
                    ForEach(AppRule.Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Khi đang gõ", selection: $underline) {
                    Text("Không gạch chân").tag(false)
                    Text("Có gạch chân").tag(true)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Button("Huỷ", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Thêm", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear(perform: loadRunningApps)
    }

    private func loadRunningApps() {
        let ruled = Set(model.settings.appRules.map(\.bundleID))
        let own = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppCandidate? in
                guard let id = app.bundleIdentifier, id != own, !ruled.contains(id),
                      seen.insert(id).inserted else { return nil }
                let url = app.bundleURL ?? AppDirectory.url(for: id)
                return AppCandidate(
                    bundleID: id,
                    name: url.map(AppDirectory.name(at:)) ?? app.localizedName ?? id,
                    icon: app.icon ?? AppDirectory.icon(for: id))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Picks any app with the system open panel (works in the sandbox through the
    /// powerbox; no file access is kept).
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = String(localized: "Chọn")
        panel.message = String(localized: "Chọn ứng dụng cần quy tắc riêng")
        guard panel.runModal() == .OK, let url = panel.url,
              let id = Bundle(url: url)?.bundleIdentifier else { return }
        if !candidates.contains(where: { $0.bundleID == id }) {
            candidates.insert(
                AppCandidate(bundleID: id, name: AppDirectory.name(at: url),
                             icon: NSWorkspace.shared.icon(forFile: url.path)),
                at: 0)
        }
        query = ""
        selection = id
    }

    private func add() {
        guard let id = selection, let candidate = candidates.first(where: { $0.id == id }) else { return }
        model.settings.upsert(AppRule(
            bundleID: candidate.bundleID, displayName: candidate.name,
            mode: mode, underline: underline, source: .user))
        dismiss()
    }
}

struct AppCandidate: Identifiable {
    let bundleID: String
    let name: String
    let icon: NSImage
    var id: String { bundleID }
}
