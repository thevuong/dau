import Testing
import DauShared
@testable import SnapshotSettings

/// Pins every "keys → result" the Settings window shows (computed by the engine at run
/// time) and the shortcut parsing, so the window says what its labels claim (N5).
/// Expected values follow Vietnamese spelling and DECISIONS.md.
@Suite("Settings samples")
struct SettingsSamplesTests {
    static let allSettings: [DauSettings] = DauSettings.TypingMethod.allCases.flatMap { method in
        DauSettings.TonePlacement.allCases.flatMap { placement in
            [true, false].map { DauSettings(typingMethod: method, tonePlacement: placement, freeMarking: $0) }
        }
    }

    @Test("preview types the mockup sentence in every configuration", arguments: allSettings)
    func preview(_ settings: DauSettings) {
        let expected = settings.tonePlacement == .modern ? "hoà bình, tiếng Việt" : "hòa bình, tiếng Việt"
        #expect(SettingsSamples.preview(settings).result == expected)
    }

    @Test("preview keys follow the mockup for the default settings")
    func previewKeys() {
        #expect(SettingsSamples.preview(.defaults).keys == "hoaf binhf, tieengs Vieetj")
        #expect(SettingsSamples.preview(DauSettings(typingMethod: .vni)).keys == "hoa2 binh2, tie61ng Vie65t")
    }

    @Test("preview output is precomposed (D3)", arguments: allSettings)
    func previewIsNFC(_ settings: DauSettings) {
        #expect(!SettingsSamples.preview(settings).result.unicodeScalars.contains { (0x300...0x36F).contains($0.value) })
    }

    @Test("restore: foreign words come back, Vietnamese stays (D4)", arguments: DauSettings.TypingMethod.allCases)
    func restore(_ method: DauSettings.TypingMethod) {
        #expect(SettingsSamples.restore(method).map(\.result) == ["windows", "Sunrise", "việt"])
    }

    @Test("Vietnamese wins, doubling keeps the original (D4, D26, D36)", arguments: DauSettings.TypingMethod.allCases)
    func winsAndKeep(_ method: DauSettings.TypingMethod) {
        let wins = SettingsSamples.vietnameseWins(method), keep = SettingsSamples.keepOriginal(method)
        if method == .vni {
            #expect((wins.keys, wins.result) == ("lan2", "làn"))
            #expect((keep.keys, keep.result) == ("lan22", "lan2"))
        } else {
            #expect((wins.keys, wins.result) == ("car", "cả"))
            #expect((keep.keys, keep.result) == ("carr", "car"))
        }
    }

    @Test("hoc + nặng → học (D20)", arguments: DauSettings.TypingMethod.allCases)
    func addMarks(_ method: DauSettings.TypingMethod) {
        let example = SettingsSamples.addMarks(method)
        #expect(example.displayed == "hoc" && example.result == "học")
    }
}

@Suite("Input source shortcut")
struct InputSourceShortcutTests {
    func entry(_ enabled: Bool, _ character: Int, _ keyCode: Int, _ flags: Int) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [character, keyCode, flags], "type": "standard"]]
    }

    @Test("⌃Space and ⌃⌥Space (macOS defaults for entries 60 and 61)")
    func defaults() {
        #expect(InputSourceShortcut.keycaps(from: entry(true, 32, 49, 262_144)) == ["⌃", "Space"])
        #expect(InputSourceShortcut.keycaps(from: entry(true, 32, 49, 786_432)) == ["⌃", "⌥", "Space"])
    }

    @Test("letters, modifiers order, disabled and malformed entries")
    func others() {
        #expect(InputSourceShortcut.keycaps(from: entry(true, 107, 40, 1_179_648)) == ["⇧", "⌘", "K"])
        #expect(InputSourceShortcut.keycaps(from: entry(false, 32, 49, 262_144)) == nil)
        #expect(InputSourceShortcut.keycaps(from: ["enabled": true]) == nil)
        #expect(InputSourceShortcut.keycaps(from: entry(true, 65_535, 999, 262_144)) == nil)
    }
}

@Suite("Document input source option (D5, N5)")
struct DocumentInputSourceTests {
    @Test("on, off, and no value when missing or malformed")
    func values() {
        let key = "TextInputGlobalPropertyPerContextInput"
        #expect(DocumentInputSource.isOn(properties: [key: 1]) == true)
        #expect(DocumentInputSource.isOn(properties: [key: true]) == true)
        #expect(DocumentInputSource.isOn(properties: [key: 0]) == false)
        #expect(DocumentInputSource.isOn(properties: [String: Any]()) == nil)
        #expect(DocumentInputSource.isOn(properties: [key: "1"]) == nil)
        #expect(DocumentInputSource.isOn(properties: nil) == nil)
    }
}

@Suite("Sidebar search")
struct SidebarSearchTests {
    @Test("case- and diacritic-insensitive")
    func search() {
        #expect(SettingsSection.typing.matches("go phim"))
        #expect(SettingsSection.smart.matches("khôi phục"))
        #expect(SettingsSection.apps.matches("GẠCH CHÂN"))
        #expect(SettingsSection.apps.matches("nguon nhap lieu"))
        #expect(!SettingsSection.apps.matches("tiếng anh"))
        #expect(!SettingsSection.updates.matches("telex"))
        #expect(SettingsSection.allCases.allSatisfy { $0.matches("") })
    }
}
