import Foundation
import Testing
@testable import DauShared

@Suite("CompatibilityList")
struct CompatibilityListTests {
    /// The copy shipped in the host app.
    static let shippedURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Apps/Dau/Resources/CompatibilityList.json")

    static func list(_ json: String) -> CompatibilityList {
        CompatibilityList.decode(Data(json.utf8))
    }

    @Test("decodes entries and keeps list order")
    func decodes() {
        let list = Self.list("""
        {"version": 3, "apps": [
          {"name": "A", "bundleIDs": ["a.one", "a.two"], "suggestUnderline": true, "note": "n"},
          {"bundleIDs": ["b"], "suggestUnderline": false},
          {"bundleIDs": ["c"], "suggestUnderline": true}
        ]}
        """)
        #expect(list.version == 3)
        #expect(list.apps.count == 3)
        #expect(list.apps[0] == .init(bundleIDs: ["a.one", "a.two"], name: "A", suggestUnderline: true, note: "n"))
        #expect(list.suggestedBundleIDs == ["a.one", "a.two", "c"])
        #expect(list.suggestion(for: "a.two")?.name == "A")
        #expect(list.suggestion(for: "b") == nil)
    }

    @Test("D18: malformed entries are dropped, unknown keys ignored")
    func lenient() {
        let list = Self.list("""
        {"version": "x", "future": {"k": 1}, "apps": [
          {"bundleIDs": []},
          {"name": "no ids", "suggestUnderline": true},
          {"bundleIDs": "not an array"},
          42,
          {"bundleIDs": ["", "  ", 7, "ok", "ok"], "suggestUnderline": "yes", "extra": true},
          {"bundleIDs": ["good"], "suggestUnderline": true}
        ]}
        """)
        #expect(list.version == 0)
        #expect(list.apps.map(\.bundleIDs) == [["ok"], ["good"]])
        // A flag of the wrong type falls back to "no suggestion".
        #expect(list.suggestedBundleIDs == ["good"])
    }

    @Test("D18: an unreadable or missing file gives the empty list")
    func unreadable() {
        #expect(Self.list("not json") == .empty)
        #expect(Self.list("[]") == .empty)
        #expect(Self.list("{}") == .empty)
        #expect(CompatibilityList.load(from: nil) == .empty)
        #expect(CompatibilityList.load(from: URL(fileURLWithPath: "/nonexistent/list.json")) == .empty)
    }

    @Test("round-trips through JSON")
    func roundTrip() throws {
        let list = CompatibilityList(version: 2, apps: [.init(bundleIDs: ["x"], name: "X", note: "n")])
        let data = try JSONEncoder().encode(list)
        #expect(CompatibilityList.decode(data) == list)
    }

    @Test("D13: shipped list suggests VS Code and Electron/Chromium apps, not Terminal")
    func shippedList() throws {
        let data = try Data(contentsOf: Self.shippedURL)
        // Strict decode too, so a typo cannot silently drop an entry.
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rawApps = try #require(raw["apps"] as? [[String: Any]])
        let list = CompatibilityList.decode(data)
        #expect(list.version >= 1)
        #expect(list.apps.count == rawApps.count)
        let ids = list.suggestedBundleIDs
        #expect(ids.first == "com.microsoft.VSCode")
        for id in ["com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
                   "company.thebrowser.Browser", "com.todesktop.230313mzl4w4u92", "com.vng.zalo",
                   "com.hnc.Discord", "com.tinyspeck.slackmacgap", "notion.id", "md.obsidian",
                   "com.figma.Desktop"] {
            #expect(ids.contains(id), "\(id)")
        }
        #expect(!ids.contains("com.apple.Terminal"))
        #expect(Set(ids).count == ids.count)
        #expect(list.apps.allSatisfy { $0.name?.isEmpty == false })
    }
}

@Suite("Rule rows with suggestions")
struct RuleRowsTests {
    let list = CompatibilityList(version: 1, apps: [
        .init(bundleIDs: ["vscode"], name: "VS Code"),
        .init(bundleIDs: ["teams2", "teams1"], name: "Teams"),
        .init(bundleIDs: ["chrome"], name: "Chrome"),
        .init(bundleIDs: ["firefox"], name: "Firefox", suggestUnderline: false),
    ])

    @Test("installed suggestions without a rule appear unsaved, without underline")
    func pendingSuggestions() {
        let s = DauSettings(appRules: [AppRule(bundleID: "word", displayName: "Word")])
        let rows = s.ruleRows(suggesting: list) { $0 != "teams1" }
        #expect(rows.map(\.bundleID) == ["vscode", "teams2", "chrome", "word"])
        #expect(rows[0] == AppRule(bundleID: "vscode", displayName: "VS Code", underline: false, source: .suggested))
        #expect(rows[1].displayName == "Teams")
        // Nothing stored.
        #expect(s.appRules.map(\.bundleID) == ["word"])
    }

    @Test("uninstalled and not-suggested apps are not shown; empty stays empty")
    func nothingApplies() {
        #expect(DauSettings().ruleRows(suggesting: list) { _ in false }.isEmpty)
        #expect(DauSettings().ruleRows(suggesting: .empty) { _ in true }.isEmpty)
        #expect(!DauSettings().ruleRows(suggesting: list) { _ in true }.map(\.bundleID).contains("firefox"))
    }

    @Test("changing a suggestion stores a suggested rule in place; back to default removes it")
    func changingASuggestion() {
        var s = DauSettings(appRules: [AppRule(bundleID: "word")])
        let installed: (String) -> Bool = { _ in true }
        let chrome = s.ruleRows(suggesting: list, isInstalled: installed)[3]
        #expect(chrome.bundleID == "chrome")
        s.setUnderline(true, for: chrome)
        #expect(s.rule(for: "chrome") == AppRule(bundleID: "chrome", displayName: "Chrome",
                                                  underline: true, source: .suggested))
        // Same place in the list after it is stored.
        #expect(s.ruleRows(suggesting: list, isInstalled: installed).map(\.bundleID)
                == ["vscode", "teams2", "teams1", "chrome", "word"])
        s.setUnderline(false, for: chrome)
        #expect(s.rule(for: "chrome") == nil)
        #expect(s.ruleRows(suggesting: list, isInstalled: installed)[3].underline == false)
    }

    @Test("user rules keep an explicit Không gạch chân")
    func userRuleKeepsChoice() {
        var s = DauSettings(appRules: [AppRule(bundleID: "word", underline: true)])
        s.setUnderline(false, for: s.appRules[0])
        #expect(s.rule(for: "word") == AppRule(bundleID: "word", underline: false))
    }

    @Test("a user rule for a suggested app stays a user rule, shown once")
    func userRuleWins() {
        let s = DauSettings(appRules: [AppRule(bundleID: "chrome", underline: true)])
        let rows = s.ruleRows(suggesting: list) { _ in true }
        #expect(rows.filter { $0.bundleID == "chrome" } == [AppRule(bundleID: "chrome", underline: true)])
        #expect(rows.last?.bundleID == "chrome")
    }

    @Test("stored suggested rules stay when the app is gone or left the list")
    func storedSuggestionsStay() {
        let s = DauSettings(appRules: [
            AppRule(bundleID: "old", displayName: "Old", underline: true, source: .suggested),
            AppRule(bundleID: "vscode", underline: true, source: .suggested),
        ])
        let rows = s.ruleRows(suggesting: list) { _ in false }
        #expect(rows.map(\.bundleID) == ["vscode", "old"])
    }
}
