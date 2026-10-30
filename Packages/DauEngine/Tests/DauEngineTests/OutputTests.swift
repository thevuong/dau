import Testing
import DauEngine

/// The `Action` contract and NFC output (D3).
@Suite("Đầu ra: Action và NFC")
struct OutputTests {
    @Test func plainLettersPassThrough() {
        var engine = VietEngine()
        do { let result = engine.handle("c"); #expect(result == .passThrough) }
        do { let result = engine.handle("a"); #expect(result == .passThrough) }
        #expect(engine.handle(" ") == .passThrough)   // "ca" is valid: nothing to do
    }

    /// Only the changed tail is replaced, and an unchanged prefix is never resent.
    @Test func replacementIsMinimal() {
        var engine = VietEngine()
        do { let result = engine.handle("t"); #expect(result == .passThrough) }
        do { let result = engine.handle("o"); #expect(result == .passThrough) }
        do { let result = engine.handle("a"); #expect(result == .passThrough) }
        guard case .replace(let deleteCount, let insert) = engine.handle("s") else {
            Issue.record("expected replace"); return
        }
        #expect(deleteCount == 1)                   // "toa" → "toá"
        #expect(insert.map(\.value) == scalars("á"))
        #expect(engine.handle("n") == .passThrough) // "toán": the tone does not move
    }

    @Test func toneKeyReplacesOnlyTheVowel() {
        var engine = VietEngine()
        for k in "nguoiw".unicodeScalars { _ = engine.handle(k) }
        guard case .replace(let deleteCount, let insert) = engine.handle("f") else {
            Issue.record("expected replace"); return
        }
        #expect(deleteCount == 2)                   // "ngươi" → "người"
        #expect(insert.map(\.value) == scalars("ời"))
    }

    @Test func boundaryRestoreIncludesTheKey() {
        var engine = VietEngine()
        for k in "aw".unicodeScalars { _ = engine.handle(k) }
        guard case .replace(let deleteCount, let insert) = engine.handle(" ") else {
            Issue.record("expected replace"); return
        }
        #expect(deleteCount == 1)
        #expect(insert.map(\.value) == scalars("aw "))
        #expect(!engine.isComposing)
    }

    @Test func endWordDoesNotIncludeAKey() {
        var engine = VietEngine()
        for k in "Swift".unicodeScalars { _ = engine.handle(k) }
        guard case .replace(_, let insert) = engine.endWord() else {
            Issue.record("expected replace"); return
        }
        #expect(insert.description == "wift")   // "Sừit" → "Swift"
    }

    @Test func controlAndFunctionKeysReset() {
        var engine = VietEngine()
        _ = engine.handle("a")
        #expect(engine.handle("\u{1B}") == .passThrough)   // Esc
        #expect(!engine.isComposing)
        _ = engine.handle("a")
        #expect(engine.handle("\u{F702}") == .passThrough)  // NSLeftArrowFunctionKey
        #expect(!engine.isComposing)
    }

    /// Every vowel × tone, lowercase and uppercase, is one precomposed scalar that is
    /// canonically equal to the decomposed form.
    @Test func everyVowelIsPrecomposedNFC() {
        let vowels: [(keys: String, base: String)] = [
            ("a", "a"), ("aw", "a\u{0306}"), ("aa", "a\u{0302}"), ("e", "e"), ("ee", "e\u{0302}"),
            ("i", "i"), ("o", "o"), ("oo", "o\u{0302}"), ("ow", "o\u{031B}"), ("u", "u"),
            ("uw", "u\u{031B}"), ("y", "y"),
        ]
        let tones: [(key: String, mark: String)] = [
            ("", ""), ("s", "\u{0301}"), ("f", "\u{0300}"), ("r", "\u{0309}"), ("x", "\u{0303}"), ("j", "\u{0323}"),
        ]
        for v in vowels {
            for t in tones {
                for upper in [false, true] {
                    let keys = upper ? v.keys.uppercased() : v.keys
                    let out = typed(keys + t.key)
                    let reference = (upper ? v.base.uppercased() : v.base) + t.mark
                    #expect(out.unicodeScalars.count == 1, "\(keys + t.key) → \(out)")
                    #expect(out == reference, "\(keys + t.key) → \(out)")
                }
            }
        }
        #expect(typedScalars("dd") == [0x0111])
        #expect(typedScalars("DD") == [0x0110])
    }
}
