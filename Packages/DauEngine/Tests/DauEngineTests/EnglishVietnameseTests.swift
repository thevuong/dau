import Testing
import DauEngine

/// Group 1 — English/Vietnamese overlaps, doubled keys and word boundaries
/// (D4, D26, D28, D31).
@Suite("1. Từ trùng Anh–Việt, gõ đúp, ranh giới từ")
struct EnglishVietnameseTests {
    /// D4: a valid Vietnamese syllable wins over the English word.
    @Test(arguments: [
        Case("car ", "cả "),
        Case("sex ", "sẽ "),
        Case("has ", "há "),
        Case("as ", "á "),
        Case("test ", "tét "),
        Case("vieetj ", "việt "),
        Case("did ", "đi "),   // D28: d after the vowel still makes đ; "đi" is valid.
        Case("awn ", "ăn "),
    ])
    func vietnameseWins(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D4 + D26: double the tone key to keep the letters; the restore baseline after a
    /// double key is the text shown ("carr␣" → "car␣", "tesst␣" → "test␣").
    @Test(arguments: [
        Case("carr", "car"),
        Case("carr ", "car "),
        Case("carrs", "cars"),
        Case("carrs ", "cars "),
        Case("sexx ", "sex "),
        Case("ass ", "as "),
        Case("hass ", "has "),
        Case("tess", "tes"),
        Case("tesst", "test"),
        Case("tesst ", "test "),
    ])
    func doubleKeepsLetters(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D26 (kept by the user's decision): after a doubled tone key the restore baseline
    /// is the text shown, so an English word whose double letter is a tone key loses
    /// one letter; typing the letter three times keeps both. "passsword" also crosses
    /// D33 at its 8th letter, where the baseline already equals the screen.
    @Test(arguments: [
        Case("password ", "pasword "), Case("passsword ", "password "),
        Case("coffee ", "cofee "), Case("cofffee ", "coffee "),
        Case("error ", "eror "), Case("errror ", "error "),
        Case("tesst ", "test "),
    ])
    func doubledToneLettersInEnglishWords(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D4: words that are not valid syllables are restored at the boundary, exactly as
    /// typed, including case.
    @Test(arguments: [
        Case("windows ", "windows "),
        Case("Swift ", "Swift "),
        Case("aw ", "aw "),       // D31: ă cannot end a syllable.
        Case("pdd ", "pdd "),     // "pđ" is invalid; restore even though only đ changed (B7).
        Case("Swift", "Sừit"),   // no boundary yet: nothing is restored.
    ])
    func restoreAtBoundary(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D4: every printed word-ending character restores the same way, including
    /// ! ? ( ) " (OpenKey did not for "!", B10).
    @Test(arguments: [",", ".", "!", "?", "(", ")", "\"", ";", ":", "'", "-", "[", "]", "\t", "\n"])
    func everyPrintedBoundaryRestores(_ boundary: String) {
        expectTyped("Swift" + boundary, "Swift" + boundary)
        expectTyped("windows" + boundary, "windows" + boundary)
        expectTyped("car" + boundary, "cả" + boundary)
    }

    /// D4: Return handled through `endWord()` restores too.
    @Test func returnThroughEndWord() {
        expectTyped("Swift⏎", "Swift\n")
        expectTyped("car⏎", "cả\n")
    }

    /// D4: arrows, Esc, clicks and shortcuts only reset; nothing is restored.
    @Test func resetDoesNotRestore() {
        expectTyped("Swift←", "Sừit")
        expectTyped("Swift← ", "Sừit ")
        // After the reset a new word starts.
        expectTyped("Swift←as", "Sừitá")
    }

    /// D27: [ and ] are punctuation in Telex.
    @Test func bracketsArePunctuation() {
        expectTyped("u[", "u[")
        expectTyped("u]", "u]")
        expectTyped("[as]", "[á]")
    }

    /// Auto restore off: the boundary keeps what is shown (D4 switch); spelling still
    /// stops transforms (D30).
    @Test func autoRestoreOff() {
        expectTyped("Swift ", "Sừit ", noRestore)
        expectTyped("windows ", "ưindows ", noRestore)
        expectTyped("car ", "cả ", noRestore)
    }

    /// Several words in a row, each handled on its own.
    @Test func sentence() {
        expectTyped("Tieengs Vieetj, windows vaf Swift!", "Tiếng Việt, windows và Swift!")
        // A 12-letter word: invalid from "Cod" (D30), so its later tone keys stay letters,
        // and D33 has nothing to restore at the 8th letter.
        expectTyped("Tieengs Vieetj, vaf Codefastlabs!", "Tiếng Việt, và Codefastlabs!")
    }
}
