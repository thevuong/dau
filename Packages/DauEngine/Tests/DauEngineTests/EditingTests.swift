import Testing
import DauEngine

/// Group 5 — Backspace (D32), word length (D33), letter case (D34), digits.
@Suite("5. Backspace, độ dài từ, chữ hoa, chữ số")
struct EditingTests {
    /// D32: Backspace drops the last letter shown and re-places the tone.
    @Test(arguments: [
        Case("hoaf⌫", "hò"), Case("hoaf⌫ ", "hò "), Case("vieetj⌫", "việ"),
        Case("vieetj⌫⌫", "vị"), Case("as⌫", ""), Case("⌫", ""), Case("dd⌫", ""),
        Case("hoaf⌫a", "hoà"),
    ])
    func backspaceReplacesTone(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D26: the double-key lock survives Backspace until the word ends.
    @Test(arguments: [
        Case("tesst⌫s", "tess"), Case("carr⌫r", "car"), Case("carr⌫⌫as", "cas"),
        Case("tesst⌫s cas", "tess cá"),
        Case("aaa⌫⌫a", "a"),   // erasing the whole word ends it, and its lock with it
    ])
    func doubleLockSurvivesBackspace(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D30: the spelling lock is recomputed from what is left after Backspace.
    @Test(arguments: [
        Case("Hask", "Hák"), Case("Hask⌫n", "Hán"), Case("Hask⌫nf", "Hàn"),
        Case("cek⌫⌫as", "cá"),
    ])
    func spellingLockRecomputed(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D32 + D4: after Backspace the restore baseline is the text shown then, plus
    /// the keys typed after it.
    @Test(arguments: [
        Case("Hasak⌫i ", "Hấi "), Case("toans⌫k ", "toák "), Case("vieet⌫k ", "viêk "),
    ])
    func backspaceMovesRestoreBaseline(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// Backspace that only removes the last character is left to the app.
    @Test func backspacePassesThroughWhenSimple() {
        var engine = VietEngine()
        _ = engine.handle("c")
        _ = engine.handle("a")
        do { let result = engine.backspace(); #expect(result == .passThrough) }
        var empty = VietEngine()
        do { let result = empty.backspace(); #expect(result == .passThrough) }
    }

    /// `lastShown` is the character the app's own Delete would remove (IMK layer, D32).
    @Test func lastShownTracksTheScreen() {
        var engine = VietEngine()
        #expect(engine.lastShown == nil)
        for key in "hoaf".unicodeScalars { _ = engine.handle(key) }
        #expect(engine.lastShown == "à")
        _ = engine.backspace()
        #expect(engine.lastShown == "ò")
        _ = engine.handle(" ")
        #expect(engine.lastShown == nil)
        var seeded = VietEngine()
        let seededOK = seeded.seed(displayed: "hoa\u{0300}".unicodeScalars)
        #expect(seededOK)
        #expect(seeded.lastShown == "\u{0300}")
    }

    /// D33: 7 letters is the longest syllable ("nghiêng").
    @Test(arguments: [
        Case("nghieeng ", "nghiêng "), Case("nghieengf ", "nghiềng "),
        Case("supercalifragilistic ", "supercalifragilistic "),
    ])
    func sevenLetters(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D33: an 8th letter restores the keys typed immediately (no waiting for the
    /// boundary) and the rest of the word passes through; nothing is lost.
    @Test func overflowRestoresImmediately() {
        var t = Typist()
        t.type("Sunrisea")          // "Sủnise" + "a" → 7 letters (8 keys), still transformed
        #expect(t.string == "Sủnisea")
        t.type("a")                 // 8th letter
        #expect(t.string == "Sunriseaa")
        t.type("ss ")
        #expect(t.string == "Sunriseaass ")
    }

    /// D33 with auto restore off: the word only stops transforming.
    @Test func overflowWithoutAutoRestore() {
        var t = Typist(noRestore)
        t.type("Sunrisea")
        #expect(t.string == "Sủnisea")
        t.type("a")
        #expect(t.string == "Sủniseaa")
        t.type("ss ")
        #expect(t.string == "Sủniseaass ")
    }

    @Test func longWordsLoseNothing() {
        let word = String(repeating: "vieetj", count: 7)   // 42 keys
        expectTyped(word + " ", word + " ")
        let keys = "a" + String(repeating: "sf", count: 20) + " "  // tone toggles only
        expectTyped(keys, keys)
    }

    /// D34: transform and tone keys never change a letter's case; the first key sets it.
    @Test(arguments: [
        Case("VIEETJ", "VIỆT"), Case("Vieetj", "Việt"), Case("Dd", "Đ"), Case("DD", "Đ"),
        Case("dD", "đ"), Case("aA", "â"), Case("Aa", "Â"), Case("aW", "ă"), Case("W", "Ư"),
        Case("NGUOIWF", "NGƯỜI"), Case("NguoiWF", "Người"), Case("Hoaf", "Hoà"),
        Case("THUOWR", "THUỞ"), Case("ViEeTj", "ViỆT"), Case("SUNRISE ", "SUNRISE "),
        Case("Sunrise ", "Sunrise "),
    ])
    func letterCase(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// Digits are part of the word; a word with a digit is not Vietnamese (D30, D4).
    @Test(arguments: [
        Case("a1 ", "a1 "), Case("2024 ", "2024 "), Case("h2o ", "h2o "),
        Case("as1", "á1"), Case("as1 ", "as1 "), Case("vie1t", "vie1t"), Case("2as", "2as"),
    ])
    func digits(_ c: Case) { expectTyped(c.keys, c.expected) }
}
