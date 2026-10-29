import AppKit
import SwiftUI
import DauShared

/// "Ứng dụng": "Nhớ chế độ theo từng ứng dụng" and the per-app rules (D5, D13).
struct AppRulesView: View {
    @Environment(SettingsModel.self) private var model
    @State private var query = ""
    @State private var isAdding = false

    private var visibleRules: [AppRule] {
        let rules = model.settings.appRules
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return rules }
        return rules.filter {
            AppDirectory.name(for: $0).localizedStandardContains(query)
                || $0.bundleID.localizedStandardContains(query)
        }
    }

    var body: some View {
        @Bindable var model = model
        SettingsPage {
            Section {
                Toggle(isOn: $model.settings.rememberModePerApp) {
                    Text("Nhớ chế độ theo từng ứng dụng")
                    Text("Chỉ áp dụng cho ứng dụng không có quy tắc riêng.")
                }
            }

            Section {
                if model.settings.appRules.isEmpty {
                    Text("Chưa có quy tắc riêng. Bấm + để thêm.")
                        .foregroundStyle(.secondary)
                } else if visibleRules.isEmpty {
                    Text("Không có ứng dụng nào khớp.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleRules) { rule in
                        AppRuleRow(rule: rule)
                    }
                }
            } header: {
                Text("Quy tắc riêng")
            } footer: {
                Text("Quy tắc riêng luôn áp dụng.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: Text("Tìm ứng dụng"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Label("Thêm quy tắc", systemImage: "plus")
                }
                .help(Text("Thêm quy tắc"))
            }
        }
        .sheet(isPresented: $isAdding) {
            AddAppRuleSheet()
        }
    }
}

/// One rule: icon, name, "Đề xuất" badge, mode and underline popups.
struct AppRuleRow: View {
    @Environment(SettingsModel.self) private var model
    let rule: AppRule

    var body: some View {
        let name = AppDirectory.name(for: rule)
        HStack(spacing: 10) {
            Image(nsImage: AppDirectory.icon(for: rule.bundleID))
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                Text(verbatim: name)
                    .lineLimit(1)
                if rule.source == .suggested {
                    Chip(Text("Đề xuất"))
                }
            }
            Spacer(minLength: 8)
            Picker(selection: binding(\.mode)) {
                ForEach(AppRule.Mode.allCases, id: \.self) { Text($0.title).tag($0) }
            } label: {
                Text("Chế độ khi mở \(name)")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 120, alignment: .leading)
            Picker(selection: binding(\.underline)) {
                Text("Không gạch chân").tag(false)
                Text("Có gạch chân").tag(true)
            } label: {
                Text("Gạch chân khi gõ trong \(name)")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .leading)
            Button(role: .destructive) {
                model.settings.removeRule(for: rule.bundleID)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(Text("Xoá quy tắc"))
            .accessibilityLabel(Text("Xoá quy tắc cho \(name)"))
        }
        .contextMenu {
            Button("Xoá quy tắc", role: .destructive) {
                model.settings.removeRule(for: rule.bundleID)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppRule, Value>) -> Binding<Value> {
        Binding {
            (model.settings.rule(for: rule.bundleID) ?? rule)[keyPath: keyPath]
        } set: { newValue in
            var updated = model.settings.rule(for: rule.bundleID) ?? rule
            updated[keyPath: keyPath] = newValue
            model.settings.upsert(updated)
        }
    }
}

extension AppRule.Mode {
    var title: String {
        switch self {
        case .vietnamese: String(localized: "Tiếng Việt")
        case .english: String(localized: "Tiếng Anh")
        }
    }
}

/// Names and icons of installed apps, through Launch Services (works in the sandbox).
@MainActor
enum AppDirectory {
    static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(at url: URL) -> String {
        FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards])
    }

    /// The app's own name if it is installed, else the name stored in the rule, else
    /// the bundle ID.
    static func name(for rule: AppRule) -> String {
        if let url = url(for: rule.bundleID) { return name(at: url) }
        return rule.displayName ?? rule.bundleID
    }

    static func icon(for bundleID: String) -> NSImage {
        if let url = url(for: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
