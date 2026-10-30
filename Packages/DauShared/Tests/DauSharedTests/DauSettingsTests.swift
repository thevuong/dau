import Foundation
import Testing
import DauEngine
@testable import DauShared

@Suite("DauSettings")
struct DauSettingsTests {
    @Test("defaults follow D15")
    func defaultsFollowD15() {
        let s = DauSettings.defaults
        #expect(s.typingMethod == .telex)
        #expect(s.tonePlacement == .modern)
        #expect(s.freeMarking)
        #expect(s.autoRestore)
        #expect(s.addMarksToTypedWords)
        #expect(s.advanced == .off)
        #expect(!s.consonantShortcuts)
        #expect(!s.allowZFWJ)
        #expect(s.appRules.isEmpty)
    }

    @Test("defaults map to the engine's D15 defaults")
    func defaultsMatchEngine() {
        #expect(DauSettings.defaults.engineOptions == EngineOptions())
    }

    @Test("every setting reaches EngineOptions")
    func engineMapping() {
        let s = DauSettings(
            typingMethod: .vni, tonePlacement: .classic, freeMarking: false,
            autoRestore: false, advanced: .allowZFWJ)
        #expect(s.engineOptions == EngineOptions(
            inputMethod: .vni, tonePlacement: .classic, freeMarking: false,
            autoRestore: false, advanced: .allowZFWJ))
        #expect(DauSettings(typingMethod: .simpleTelex).engineOptions.inputMethod == .simpleTelex)
        #expect(DauSettings(advanced: .consonantShortcuts).engineOptions.advanced == .consonantShortcuts)
    }

    @Test("D22: turning one advanced option on turns the other off")
    func advancedOptionsExclude() {
        var s = DauSettings.defaults
        s.consonantShortcuts = true
        #expect(s.consonantShortcuts && !s.allowZFWJ)
        s.allowZFWJ = true
        #expect(s.allowZFWJ && !s.consonantShortcuts)
        #expect(s.advanced == .allowZFWJ)
        s.consonantShortcuts = true
        #expect(s.consonantShortcuts && !s.allowZFWJ)
    }

    @Test("D22: turning off the option that is not on changes nothing")
    func turningOffTheOtherOptionKeepsState() {
        var s = DauSettings(advanced: .consonantShortcuts)
        s.allowZFWJ = false
        #expect(s.advanced == .consonantShortcuts)
        s.consonantShortcuts = false
        #expect(s.advanced == .off)
    }

    @Test("rules are unique per bundle ID and keep their order")
    func upsertReplacesInPlace() {
        var s = DauSettings.defaults
        s.upsert(AppRule(bundleID: "a"))
        s.upsert(AppRule(bundleID: "b"))
        s.upsert(AppRule(bundleID: "a", underline: true))
        #expect(s.appRules.map(\.bundleID) == ["a", "b"])
        #expect(s.rule(for: "a")?.underline == true)
        s.removeRule(for: "a")
        #expect(s.appRules.map(\.bundleID) == ["b"])
        let duplicated = DauSettings(appRules: [AppRule(bundleID: "x"), AppRule(bundleID: "x", underline: true)])
        #expect(duplicated.appRules == [AppRule(bundleID: "x", underline: true)])
    }
}

@Suite("DauSettings coding")
struct DauSettingsCodingTests {
    func decode(_ json: String) throws -> DauSettings {
        try JSONDecoder().decode(DauSettings.self, from: Data(json.utf8))
    }

    @Test("round trip keeps every field")
    func roundTrip() throws {
        var s = DauSettings(
            typingMethod: .simpleTelex, tonePlacement: .classic, freeMarking: false,
            autoRestore: false, addMarksToTypedWords: false, advanced: .consonantShortcuts)
        s.upsert(AppRule(bundleID: "com.google.Chrome", displayName: "Google Chrome",
                         underline: true, source: .suggested))
        s.upsert(AppRule(bundleID: "com.apple.Terminal"))
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(DauSettings.self, from: data) == s)
    }

    @Test("empty object decodes to D15 defaults")
    func emptyObject() throws {
        #expect(try decode("{}") == .defaults)
    }

    @Test("unknown values and wrong types fall back to defaults, known ones are kept")
    func lenientValues() throws {
        let s = try decode("""
            {"typingMethod":"dvorak","tonePlacement":"classic","freeMarking":"yes",
             "advanced":"both","futureKey":42}
            """)
        #expect(s.typingMethod == .telex)
        #expect(s.tonePlacement == .classic)
        #expect(s.freeMarking)
        #expect(s.advanced == .off)
    }

    @Test("a malformed rule is dropped without losing the others")
    func lenientRules() throws {
        let s = try decode("""
            {"appRules":[{"bundleID":"a","underline":"yes"},{"underline":true},
                         {"bundleID":""},{"bundleID":"b","underline":true,"source":"klingon"}]}
            """)
        #expect(s.appRules == [
            AppRule(bundleID: "a"),
            AppRule(bundleID: "b", underline: true),
        ])
    }

    @Test("D5/D18: settings saved before the single-mode change still load")
    func legacyModeKeys() throws {
        // Written by builds that had "Dấu – Tiếng Anh", a start mode per rule and
        // "Nhớ chế độ theo từng ứng dụng" (before 30/10/2026).
        let s = try decode("""
            {"typingMethod":"vni","rememberModePerApp":true,
             "appRules":[{"bundleID":"com.apple.Terminal","mode":"english","underline":true,
                          "source":"suggested","displayName":"Terminal"},
                         {"bundleID":"com.apple.Safari","mode":"english"},
                         {"bundleID":"com.apple.Notes","mode":"vietnamese","underline":true}]}
            """)
        #expect(s.typingMethod == .vni)
        // Every rule survives with its underline choice; the mode is dropped.
        #expect(s.appRules == [
            AppRule(bundleID: "com.apple.Terminal", displayName: "Terminal", underline: true,
                    source: .suggested),
            AppRule(bundleID: "com.apple.Safari"),
            AppRule(bundleID: "com.apple.Notes", underline: true),
        ])
        // Re-saving drops the old keys.
        let json = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(!json.contains("rememberModePerApp"))
        #expect(!json.contains("\"mode\""))
    }

    @Test("encoded keys are stable (read by the input method)")
    func stableKeys() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(DauSettings.defaults), as: UTF8.self)
        #expect(json == """
            {"addMarksToTypedWords":true,"advanced":"off","appRules":[],"autoRestore":true,\
            "freeMarking":true,"tonePlacement":"modern","typingMethod":"telex"}
            """)
    }
}
