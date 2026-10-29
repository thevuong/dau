import AppKit
import SwiftUI
import DauShared

/// "Ứng dụng" (mockup "SettingsApps"): "Nhớ chế độ theo từng ứng dụng" and the per-app
/// rules (D5, D13). Search field and + sit in the toolbar, as in the mockup header.
struct AppRulesView: View {
    @Environment(SettingsModel.self) private var model
    @State private var query = ""
    @State private var isAdding: Bool
    @FocusState private var focusedRule: String?

    init(isAdding: Bool = false) {
        _isAdding = State(initialValue: isAdding)
    }

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
        SettingsPage(SettingsSection.apps.title) {
            SearchField(text: $query, prompt: String(localized: "Tìm ứng dụng"))
                .frame(width: 180)
            Button {
                isAdding = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 16, height: 16)
            }
            .help(Text("Thêm ứng dụng"))
            .accessibilityLabel(Text("Thêm ứng dụng"))
        } content: {
            Section {
                Toggle(isOn: $model.settings.rememberModePerApp) {
                    RowLabel(Text("Nhớ chế độ theo từng ứng dụng"),
                             hint: Text("Mặc định tắt. Áp dụng cho các app không có quy tắc riêng bên dưới"))
                }
                .layoutProbe("firstRow")
            } header: {
                Text("Mặc định")
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
                            .focusable()
                            .focused($focusedRule, equals: rule.bundleID)
                            .onTapGesture { focusedRule = rule.bundleID }
                            .onDeleteCommand { remove(rule) }
                            .contextMenu {
                                Button("Xoá quy tắc", role: .destructive) { remove(rule) }
                            }
                            .accessibilityAction(named: Text("Xoá quy tắc")) { remove(rule) }
                    }
                }
            } header: {
                Text("Quy tắc riêng")
            } footer: {
                Text("Quy tắc riêng luôn được áp dụng. “Đề xuất” đến từ danh sách tương thích. Chỉ chọn “Có gạch chân” khi một app bị lỗi chữ lúc gõ.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $isAdding) {
            AddAppRuleSheet()
        }
    }

    private func remove(_ rule: AppRule) {
        model.settings.removeRule(for: rule.bundleID)
        if focusedRule == rule.bundleID { focusedRule = nil }
    }
}

/// One rule: icon 28, name, "Đề xuất" chip, mode and underline popups. Removed with the
/// context menu or the Delete key while focused (the system draws the focus ring).
struct AppRuleRow: View {
    @Environment(SettingsModel.self) private var model
    let rule: AppRule

    var body: some View {
        let name = AppDirectory.name(for: rule)
        HStack(spacing: 12) {
            Image(nsImage: AppDirectory.icon(for: rule.bundleID))
                .resizable()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(verbatim: name)
                    .lineLimit(1)
                if rule.source == .suggested {
                    Chip(Text("Đề xuất"), height: 20, fontSize: 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Picker(selection: binding(\.mode)) {
                ForEach(AppRule.Mode.allCases, id: \.self) { Text($0.title).tag($0) }
            } label: {
                Text("Chế độ khi mở \(name)")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            Picker(selection: binding(\.underline)) {
                Text("Không gạch chân").tag(false)
                Text("Có gạch chân").tag(true)
            } label: {
                Text("Gạch chân khi gõ trong \(name)")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: name))
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

    nonisolated static func name(at url: URL) -> String {
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
