import Testing
import DauEngine

/// Consonant shortcuts (D21) and "Cho phép z, f, w, j" (D22), mutually exclusive by
/// construction (`EngineOptions.Advanced`).
@Suite("Gõ tắt phụ âm (D21), cho phép z f w j (D22)")
struct ShortcutTests {
    @Test(arguments: [
        Case("fan ", "phan "), Case("Fan ", "Phan "), Case("FAN ", "PHAN "),
        Case("fanf", "fàn"), Case("fanf ", "phàn "),
        Case("big ", "big "),     // "bing" is not a syllable → restore (unlike OpenKey)
        Case("bag ", "bang "),    // overlap accepted: the user turned shortcuts on (D21)
        Case("fix ", "phĩ "),     // overlap accepted (D21)
        Case("vih ", "vinh "), Case("jas ", "giá "), Case("jinf ", "gìn "),
        Case("baks ", "bách "),
        Case("bak ", "bak "),     // "bach" has a stop final and no tone (D31)
        Case("wa ", "ưa "),       // Telex: w is ư, never qu (D23)
        Case("fan,", "phan,"), Case("fan!", "phan!"),   // every printed boundary (D4)
        Case("fan←", "fan"),      // reset: no expansion
        Case("phan ", "phan "), Case("bang ", "bang "),
    ])
    func consonantShortcuts(_ c: Case) { expectTyped(c.keys, c.expected, shortcuts) }

    @Test func shortcutsOffByDefault() {
        expectTyped("fan ", "fan ")
        expectTyped("bag ", "bag ")
        expectTyped("vih ", "vih ")
    }

    @Test(arguments: [
        Case("fanf ", "fàn "), Case("zas ", "zá "), Case("jas ", "já "),
        Case("wa ", "ưa "),       // Telex: w at the start is still ư (D22, D23)
        Case("fan ", "fan "),     // no expansion with this option
    ])
    func allowZFWJ(_ c: Case) { expectTyped(c.keys, c.expected, zfwj) }

    @Test func allowZFWJWithSimpleTelex() {
        let options = EngineOptions(inputMethod: .simpleTelex, advanced: .allowZFWJ)
        expectTyped("was ", "wá ", options)
    }
}
