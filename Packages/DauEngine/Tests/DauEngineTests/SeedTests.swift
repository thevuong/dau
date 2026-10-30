import Testing
import DauEngine

/// Group 6 — "Thêm dấu cho từ đã gõ" (D20): the engine is seeded from the text shown
/// in the app (read as letters), then the key is handled.
@Suite("6. Thêm dấu cho từ đã gõ (D20)")
struct SeedTests {
    struct SeedCase: Sendable, CustomTestStringConvertible {
        let displayed: String
        let keys: String
        let expected: String
        init(_ displayed: String, _ keys: String, _ expected: String) {
            self.displayed = displayed
            self.keys = keys
            self.expected = expected
        }
        var testDescription: String { "\(displayed) + \(keys) → \(expected)" }
    }

    @Test(arguments: [
        SeedCase("hoc", "j", "học"),
        SeedCase("dep", "j", "dẹp"),        // not "đẹp": no transform is added (D20)
        SeedCase("car", "s", "cars"),       // "cár" is invalid → the key goes straight
        SeedCase("viet", "j", "vietj"),     // "viẹt" is invalid
        SeedCase("viet", "ej", "việt"),     // "viêt" first, then j
        SeedCase("Viet", "ej", "Việt"),
        SeedCase("tuong", "w", "tương"),
        SeedCase("di", "d", "đi"),
        SeedCase("hoa", "f", "hoà"),
        SeedCase("học", "z", "hoc"),
        SeedCase("học", "s", "hóc"),
        SeedCase("hòa", "s", "hoá"),        // re-placed in the current (modern) style
        SeedCase("nha", "fk ", "nhafk "),   // D4: baseline = seeded text + keys typed after
        SeedCase("nha", "f ", "nhà "),
        SeedCase("tra", "w", "tră"),        // valid start of a syllable (D20 uses the D30 prefix level)
        SeedCase("viet", "e", "viêt"),
        SeedCase("cả", "r", "car"),         // D20 + D26: a double key undoes the tone
        SeedCase("cả", "r ", "car "),       // D4: the baseline after the double is the text shown
        SeedCase("cả", "rs", "cars"),       // D26: locked until the word ends
        SeedCase("hoc", "f", "hòc"),        // D30 prefix: the tone can still change…
        SeedCase("hoc", "f ", "hocf "),     // …but "hòc" is not a syllable at the boundary (D31)
        SeedCase("tra", "w ", "traw "),     // …but not a syllable at the boundary
    ])
    func seeded(_ c: SeedCase) {
        var t = Typist()
        do { let result = t.seed(c.displayed); #expect(result) }
        t.type(c.keys)
        #expect(t.text.map(\.value) == scalars(c.expected), "got \"\(t.string)\"")
    }

    /// Text read from an app may be decomposed (NFD); output is always NFC (D3) and
    /// the replacement covers the decomposed scalars.
    @Test func decomposedInput() {
        var t = Typist()
        do { let result = t.seed("vie\u{0302}t"); #expect(result) }
        t.type("j")
        #expect(t.text.map(\.value) == scalars("việt"))

        var u = Typist()
        do { let result = u.seed("ho\u{0323}c"); #expect(result) }
        u.type("s")
        #expect(u.text.map(\.value) == scalars("hóc"))
    }

    @Test func rejectsWhatCannotBeAWord() {
        var engine = VietEngine()
        do { let result = engine.seed(displayed: "Codefast".unicodeScalars); #expect(!result) }   // 8 letters (D33)
        do { let result = engine.seed(displayed: "a-b".unicodeScalars); #expect(!result) }
        do { let result = engine.seed(displayed: "".unicodeScalars); #expect(!result) }
        do { let result = engine.seed(displayed: "\u{0301}a".unicodeScalars); #expect(!result) }
        #expect(!engine.isComposing)
    }
}
