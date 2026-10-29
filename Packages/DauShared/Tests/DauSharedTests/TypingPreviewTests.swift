import Testing
import DauEngine
@testable import DauShared

/// TypingPreview drives the engine as the input method does. The Settings samples
/// built on it are pinned in scripts/snapshot-settings.
@Suite("TypingPreview")
struct TypingPreviewTests {
    @Test("types a sentence and ends the last word")
    func sentence() {
        #expect(TypingPreview.type("tooi yeeu tieengs Vieetj", options: EngineOptions()) == "tôi yêu tiếng Việt")
        // The final word boundary restores a foreign word (D4).
        #expect(TypingPreview.type("windows", options: EngineOptions()) == "windows")
    }

    @Test("seeds the engine from text already shown (D20)")
    func seeded() {
        #expect(TypingPreview.type("j", options: EngineOptions(), after: "hoc") == "học")
        // UI.md caveat: dep + j gives dẹp, not đẹp.
        #expect(TypingPreview.type("j", options: EngineOptions(), after: "dep") == "dẹp")
    }

    @Test("TypingExample keeps keys, shown text and result")
    func example() {
        let e = TypingExample(keys: "j", after: "hoc", options: EngineOptions())
        #expect(e.displayed == "hoc" && e.keys == "j" && e.result == "học")
    }
}
