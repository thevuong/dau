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

    /// D4: words that are not valid syllables are restored at the boundary, exactly as
    /// typed, including case.
    @Test(arguments: [
        Case("windows ", "windows "),
        Case("Hasaki ", "Hasaki "),
        Case("aw ", "aw "),       // D31: ă cannot end a syllable.
        Case("pdd ", "pdd "),     // "pđ" is invalid; restore even though only đ changed (B7).
        Case("Hasaki", "Hấki"),   // no boundary yet: nothing is restored.
    ])
    func restoreAtBoundary(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D4: every printed word-ending character restores the same way, including
    /// ! ? ( ) " (OpenKey did not for "!", B10).
    @Test(arguments: [",", ".", "!", "?", "(", ")", "\"", ";", ":", "'", "-", "[", "]", "\t", "\n"])
    func everyPrintedBoundaryRestores(_ boundary: String) {
        expectTyped("Hasaki" + boundary, "Hasaki" + boundary)
        expectTyped("windows" + boundary, "windows" + boundary)
        expectTyped("car" + boundary, "cả" + boundary)
    }

    /// D4: Return handled through `endWord()` restores too.
    @Test func returnThroughEndWord() {
        expectTyped("Hasaki⏎", "Hasaki\n")
        expectTyped("car⏎", "cả\n")
    }

    /// D4: arrows, Esc, clicks and shortcuts only reset; nothing is restored.
    @Test func resetDoesNotRestore() {
        expectTyped("Hasaki←", "Hấki")
        expectTyped("Hasaki← ", "Hấki ")
        // After the reset a new word starts.
        expectTyped("Hasaki←as", "Hấkiá")
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
        expectTyped("Hasaki ", "Hấki ", noRestore)
        expectTyped("windows ", "ưindows ", noRestore)
        expectTyped("car ", "cả ", noRestore)
    }

    /// Several words in a row, each handled on its own.
    @Test func sentence() {
        expectTyped("Tieengs Vieetj, windows vaf Hasaki!", "Tiếng Việt, windows và Hasaki!")
    }
}
