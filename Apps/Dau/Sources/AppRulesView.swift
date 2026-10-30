import AppKit
import SwiftUI
import DauShared

/// "Ứng dụng" (mockup "SettingsApps"): the macOS option that remembers the input source
/// per window, shown read-only with "Đổi…" (D5, N4), and the per-app rules (D5, D13),
/// with the installed apps of the compatibility list labelled "Đề xuất".
/// Search field and + sit in the toolbar, as in the mockup header.
struct AppRulesView: View {
    @Environment(SettingsModel.self) private var model
    @State private var query = ""
    @State private var isAdding = false
    @State private var perWindow = DocumentInputSource.isOn()
    @State private var installedSuggestions = AppDirectory.installedSuggestions(in: .empty)
    @FocusState private var focusedRule: String?

    /// Stored rules plus the installed suggestions without a rule (not stored, D13).
    private var rules: [AppRule] {
        model.settings.ruleRows(suggesting: model.compatibility,
                                isInstalled: installedSuggestions.contains)
    }

    private var visibleRules: [AppRule] {
        let rules = rules
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return rules }
        return rules.filter {
            AppDirectory.name(for: $0).localizedStandardContains(query)
                || $0.bundleID.localizedStandardContains(query)
        }
    }

    var body: some View {
        SettingsPage(SettingsSection.apps.title,
                     actions: HeaderActions(query: $query, prompt: String(localized: "Tìm ứng dụng"),
                                            addLabel: String(localized: "Thêm ứng dụng"),
                                            onAdd: { isAdding = true })) {
            SettingsGroup(Text("Việt/Anh theo cửa sổ")) {
                SettingsCard {
                    SettingsRow(Text("Nhớ nguồn nhập liệu theo từng cửa sổ"),
                                hint: Text("Tuỳ chọn “Tự động chuyển sang nguồn đầu vào của tài liệu” của macOS")) {
                        // Not readable: no value rather than a guess (N5).
                        if let perWindow {
                            (perWindow ? Text("Đang bật") : Text("Đang tắt"))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        Button("Đổi…") { SystemSettings.openKeyboard() }
                            .settingsButton()
                            .accessibilityLabel(Text("Đổi tuỳ chọn nhớ nguồn nhập liệu theo từng cửa sổ"))
                            .accessibilityHint(Text("Mở Cài đặt Bàn phím của macOS"))
                    }
                }
                .layoutProbe("firstCard")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                perWindow = DocumentInputSource.isOn()
                installedSuggestions = AppDirectory.installedSuggestions(in: model.compatibility)
            }

            SettingsGroup(Text("Quy tắc riêng")) {
                SettingsCard {
                    if rules.isEmpty {
                        SettingsRow(Text("Chưa có quy tắc riêng. Bấm + để thêm."), minHeight: 52) {}
                    } else if visibleRules.isEmpty {
                        SettingsRow(Text("Không có ứng dụng nào khớp."), minHeight: 52) {}
                    } else {
                        ForEach(Array(visibleRules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 { RowDivider() }
                            // An unsaved suggestion has nothing to remove.
                            let stored = model.settings.rule(for: rule.bundleID) != nil
                            AppRuleRow(rule: rule)
                                .focusable()
                                .focused($focusedRule, equals: rule.bundleID)
                                .onTapGesture { focusedRule = rule.bundleID }
                                .onDeleteCommand { if stored { remove(rule) } }
                                .contextMenu {
                                    if stored {
                                        Button("Xoá quy tắc", role: .destructive) { remove(rule) }
                                    }
                                }
                                .accessibilityActions {
                                    if stored {
                                        Button("Xoá quy tắc") { remove(rule) }
                                    }
                                }
                        }
                    }
                }
            } footer: {
                // N5: only what M3 measured (D13): in-place typing went wrong only when keys
                // came less than 10 ms apart; underlining fixed Chrome and VS Code but not
                // Terminal, so the hint says when to choose it, not that it always helps.
                Hint(Text("“Đề xuất” đến từ danh sách tương thích: app có thể sai chữ khi gõ rất nhanh. Chỉ chọn “Có gạch chân” khi một app bị lỗi chữ lúc gõ."))
                    .padding(.horizontal, 4)
            }
        }
        .onAppear {
            installedSuggestions = AppDirectory.installedSuggestions(in: model.compatibility)
        }
        .sheet(isPresented: $isAdding) {
            AddAppRuleSheet(listed: Set(rules.map(\.bundleID)))
        }
    }

    private func remove(_ rule: AppRule) {
        model.settings.removeRule(for: rule.bundleID)
        if focusedRule == rule.bundleID { focusedRule = nil }
    }
}

/// One rule (height 52): icon 28, name, "Đề xuất" chip, underline popup (D5).
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
            Picker(selection: underlineBinding) {
                Text("Không gạch chân").tag(false)
                Text("Có gạch chân").tag(true)
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

    /// Changing an unsaved suggestion stores it as a suggested rule; setting a suggested
    /// rule back to "Không gạch chân" removes it again (D13 default).
    private var underlineBinding: Binding<Bool> {
        Binding {
            (model.settings.rule(for: rule.bundleID) ?? rule).underline
        } set: { newValue in
            model.settings.setUnderline(newValue, for: rule)
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

    /// The suggested bundle IDs of `list` that are installed on this Mac.
    static func installedSuggestions(in list: CompatibilityList) -> Set<String> {
        Set(list.suggestedBundleIDs.filter { url(for: $0) != nil })
    }

    static func icon(for bundleID: String) -> NSImage {
        if let url = url(for: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
