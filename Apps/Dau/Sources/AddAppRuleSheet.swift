import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DauShared

/// "Thêm quy tắc cho ứng dụng" sheet (mockup "SettingsAppsAdd"), 460 wide: search,
/// a card listing the apps in the Applications folders and the running apps, a card
/// with "Khi mở app" and "Khi đang gõ", then Huỷ / Thêm. "Chọn ứng dụng khác…" opens
/// the system open panel for apps stored elsewhere.
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Thêm quy tắc cho ứng dụng")
                .font(.system(size: 15, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            SearchField(text: $query, prompt: String(localized: "Tìm trong Ứng dụng"))

            List(visibleCandidates, selection: $selection) { candidate in
                HStack(spacing: 10) {
                    Image(nsImage: candidate.icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    Text(verbatim: candidate.name)
                        .lineLimit(1)
                }
                .frame(height: 32)
                .tag(candidate.id)
            }
            .listStyle(.bordered)
            .frame(height: 196)
            .accessibilityLabel(Text("Ứng dụng"))

            GroupBox {
                VStack(spacing: 0) {
                    SettingsRow(Text("Khi mở app")) {
                        Picker("Khi mở app", selection: $mode) {
                            ForEach(AppRule.Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    .padding(.vertical, 8)
                    Divider()
                    SettingsRow(Text("Khi đang gõ")) {
                        Picker("Khi đang gõ", selection: $underline) {
                            Text("Không gạch chân").tag(false)
                            Text("Có gạch chân").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 6)
            }

            HStack(spacing: 8) {
                Button("Chọn ứng dụng khác…", action: chooseApp)
                Spacer()
                Button("Huỷ", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Thêm", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil)
            }
        }
        .padding(22)
        .frame(width: 460)
        .task { await loadApps() }
    }

    /// Apps in the Applications folders plus running apps, without the ones that
    /// already have a rule and without Dấu itself.
    private func loadApps() async {
        let ruled = Set(model.settings.appRules.map(\.bundleID))
        let own = Bundle.main.bundleIdentifier
        var running: [AppListing] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier, let url = app.bundleURL {
                running.append(AppListing(bundleID: id, name: AppDirectory.name(at: url), path: url.path))
            }
        }
        let installed = await Task.detached(priority: .userInitiated) { AppListing.installed() }.value
        var seen = Set<String>()
        candidates = (installed + running)
            .filter { $0.bundleID != own && !ruled.contains($0.bundleID) && seen.insert($0.bundleID).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { AppCandidate(bundleID: $0.bundleID, name: $0.name,
                                icon: NSWorkspace.shared.icon(forFile: $0.path)) }
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

/// An app found on disk (Sendable, built off the main thread).
struct AppListing: Sendable {
    let bundleID: String
    let name: String
    let path: String

    static let folders = ["/Applications", "/Applications/Utilities",
                          "/System/Applications", "/System/Applications/Utilities"]

    /// Apps in the standard Applications folders. Folders the sandbox cannot read are
    /// skipped; running apps and the open panel cover the rest.
    static func installed() -> [AppListing] {
        let fm = FileManager.default
        var result: [AppListing] = []
        for folder in folders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for name in names where name.hasSuffix(".app") {
                let url = URL(fileURLWithPath: folder).appendingPathComponent(name)
                guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
                result.append(AppListing(bundleID: id, name: AppDirectory.name(at: url), path: url.path))
            }
        }
        return result
    }
}
