import AppKit
import SwiftUI
import DauShared

/// "Ứng dụng" (mockup "SettingsApps"): "Nhớ chế độ theo từng ứng dụng" and the per-app
/// rules (D5, D13). Search field and + sit in the toolbar, as in the mockup header.
struct AppRulesView: View {
    @Environment(SettingsModel.self) private var model
    @State private var query = ""
    @State private var isAdding = false
    @FocusState private var focusedRule: String?


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
        SettingsPage(SettingsSection.apps.title,
                     actions: HeaderActions(query: $query, prompt: String(localized: "Tìm ứng dụng"),
                                            addLabel: String(localized: "Thêm ứng dụng"),
                                            onAdd: { isAdding = true })) {
            SettingsGroup(Text("Mặc định")) {
                SettingsCard {
                    SettingsRow(Text("Nhớ chế độ theo từng ứng dụng"),
                                hint: Text("Mặc định tắt. Áp dụng cho các app không có quy tắc riêng bên dưới")) {
                        RowSwitch(label: Text("Nhớ chế độ theo từng ứng dụng"),
                                  isOn: $model.settings.rememberModePerApp)
                    }
                }
                .layoutProbe("firstCard")
            }

            SettingsGroup(Text("Quy tắc riêng")) {
                SettingsCard {
                    if model.settings.appRules.isEmpty {
                        SettingsRow(Text("Chưa có quy tắc riêng. Bấm + để thêm."), minHeight: 52) {}
                    } else if visibleRules.isEmpty {
                        SettingsRow(Text("Không có ứng dụng nào khớp."), minHeight: 52) {}
                    } else {
                        ForEach(Array(visibleRules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 { RowDivider() }
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
                }
            } footer: {
                // N5: underlining (D13) is not in the input method yet.
                Hint(Text("Quy tắc riêng luôn được áp dụng. “Đề xuất” đến từ danh sách tương thích. [Gạch chân — có ở bản sau (M3)]"))
                    .padding(.horizontal, 4)
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

/// One rule (height 52): icon 28, name, "Đề xuất" chip, mode and underline popups.
/// Removed with the context menu or the Delete key while focused (the system draws
/// the focus ring).
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
                // N5: underlining (D13) is not in the input method yet; a saved value
                // is kept and shown, but cannot be chosen.
                Text("Có gạch chân").tag(true).disabled(true)
            } label: {
                Text("Gạch chân khi gõ trong \(name)")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
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
