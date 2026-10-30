import Testing
import DauEngine

let vni = EngineOptions(inputMethod: .vni)
let vniClassic = EngineOptions(inputMethod: .vni, tonePlacement: .classic)
let vniNoFreeMarking = EngineOptions(inputMethod: .vni, freeMarking: false)
let vniShortcuts = EngineOptions(inputMethod: .vni, advanced: .consonantShortcuts)
let vniZFWJ = EngineOptions(inputMethod: .vni, advanced: .allowZFWJ)

/// VNI: 1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng, 0 removes the tone, 6 â ê ô, 7 ơ ư,
/// 8 ă, 9 đ. Shares spelling, placement, restore and seeding with Telex.
@Suite("VNI")
struct VNITests {
    @Test(arguments: [
        Case("a1", "á"), Case("a2", "à"), Case("a3", "ả"), Case("a4", "ã"), Case("a5", "ạ"),
        Case("a10", "a"), Case("a0", "a0"), Case("a12", "à"),
    ])
    func tones(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    @Test(arguments: [
        Case("a6", "â"), Case("e6", "ê"), Case("o6", "ô"), Case("a8", "ă"), Case("o7", "ơ"),
        Case("u7", "ư"), Case("d9", "đ"), Case("a68", "ă"), Case("a86", "â"), Case("o76", "ô"),
        Case("toi6", "tôi"), Case("tua6n2", "tuần"), Case("hoa8c5", "hoặc"), Case("mua7", "mưa"),
        Case("viet65", "việt"), Case("vie6t5", "việt"), Case("quye6t1", "quyết"),
        Case("gia1", "giá"), Case("gi2", "gì"), Case("khuyu3", "khuỷu"), Case("nghie6ng2", "nghiềng"),
    ])
    func marks(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// D35: 7 on "uo" gives "uơ" at the end of the word (thuở), "ươ" once a letter follows.
    @Test(arguments: [
        Case("uo7", "uơ"), Case("uo7n", "ươn"), Case("u7o", "ưo"), Case("u7on", "ươn"),
        Case("nguoi72", "người"), Case("thuo73", "thuở"), Case("huo7", "huơ"),
        Case("huo7u", "hươu"), Case("ruou75", "rượu"), Case("truong72", "trường"),
        Case("tuong7", "tương"), Case("u7o7ng", "ương"),
    ])
    func hornedUO(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// D28: keys reach their target anywhere in the word ("duo7c59" → "được").
    @Test(arguments: [
        Case("duo7c59", "được"), Case("d9uo7c5", "được"), Case("duoc579", "được"),
        Case("di9", "đi"), Case("dinh9", "đinh"),
    ])
    func freeMarking(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// D28 off: tone digits only right after a vowel; 9 only right after d; 6/7/8 still
    /// reach their vowel from a distance.
    @Test(arguments: [
        Case("d9uo75c", "được"), Case("duo7c59", "dươc59"), Case("di9", "di9"), Case("d9i", "đi"),
        Case("hoa2", "hoà"), Case("hoc5", "hoc5"), Case("tuong7", "tương"), Case("tien6", "tiên"),
    ])
    func freeMarkingOff(_ c: Case) { expectTyped(c.keys, c.expected, vniNoFreeMarking) }

    @Test(arguments: [
        PlacementCase("hoa2", "hoà", "hòa"), PlacementCase("thuy1", "thuý", "thúy"),
        PlacementCase("khoe3", "khoẻ", "khỏe"), PlacementCase("hoang2", "hoàng", "hoàng"),
    ])
    func placement(_ c: PlacementCase) {
        expectTyped(c.keys, c.modern, vni)
        expectTyped(c.keys, c.classic, vniClassic)
    }

    /// D26: doubling a digit undoes it and locks the rest of the word, also after ⌫.
    @Test(arguments: [
        Case("a11", "a1"), Case("a111", "a11"), Case("a11 ", "a1 "), Case("a113", "a13"),
        Case("a66", "a6"), Case("a88", "a8"), Case("o77", "o7"), Case("d99", "d9"),
        Case("ca33 ", "ca3 "), Case("a11⌫1", "a1"), Case("uo77", "uo7"),
    ])
    func doubleDigit(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// A digit that changes nothing is an ordinary character; the engine and the
    /// screen stay in step (OPENKEY-NOTES B13).
    @Test(arguments: [
        Case("2024 ", "2024 "), Case("a7", "a7"), Case("a71 ", "a71 "), Case("o8", "o8"),
        Case("x2y ", "x2y "), Case("mp3 ", "mp3 "), Case("Win10 ", "Win10 "), Case("h2o ", "h2o "),
        Case("e7", "e7"), Case("b6", "b6"),
    ])
    func digitsAsCharacters(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    @Test func numbersPassThrough() {
        var engine = VietEngine(options: vni)
        for key in "2024".unicodeScalars {
            let action = engine.handle(key)
            #expect(action == .passThrough)
        }
        let space = engine.handle(" ")
        #expect(space == .passThrough)
    }

    /// D4 in VNI: restore what was typed, Vietnamese wins on overlaps.
    @Test(arguments: [
        Case("windows ", "windows "), Case("Codefastlabs ", "Codefastlabs "), Case("test ", "test "),
        Case("Ko1tlin", "Kótlin"), Case("Ko1tlin ", "Ko1tlin "), Case("Ko1tlin!", "Ko1tlin!"),
        Case("ca3 ", "cả "), Case("car3 ", "car3 "), Case("aw ", "aw "), Case("a8 ", "a8 "), Case("ca8n ", "căn "),
        Case("Ko1tlin←", "Kótlin"),
    ])
    func restore(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// D34: case follows the letters; digits have none.
    @Test(arguments: [
        Case("VIE6T5", "VIỆT"), Case("Vie6t5", "Việt"), Case("D9", "Đ"), Case("A6", "Â"),
        Case("NGUOI72", "NGƯỜI"), Case("DUO7C59", "ĐƯỢC"),
        Case("U23", "Ủ"), Case("A4", "Ã"),   // D36: a digit after a valid syllable is a mark
        Case("U223", "U23"),   // D36, D26: double the digit to keep it
    ])
    func letterCase(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    @Test(arguments: [Case("hoa2⌫", "hò"), Case("vie6t5⌫", "việ"), Case("hoa2⌫a", "hoà")])
    func backspace(_ c: Case) { expectTyped(c.keys, c.expected, vni) }

    /// D21 + D23: in VNI, w → qu at the start is one of the consonant shortcuts.
    @Test(arguments: [
        Case("wen ", "quen "), Case("Wen ", "Quen "), Case("WEN ", "QUEN "), Case("wa1 ", "quá "),
        Case("wy1 ", "quý "), Case("wo ", "wo "), Case("fan ", "phan "), Case("fan2 ", "phàn "),
        Case("ja1 ", "giá "), Case("vih ", "vinh "), Case("big ", "big "), Case("bag ", "bang "),
        Case("bak ", "bak "), Case("bak1 ", "bách "), Case("wen,", "quen,"),
    ])
    func consonantShortcuts(_ c: Case) { expectTyped(c.keys, c.expected, vniShortcuts) }

    @Test func shortcutsOffByDefault() {
        expectTyped("wen ", "wen ", vni)
        expectTyped("fan ", "fan ", vni)
    }

    /// D22: "Cho phép z, f, w, j" works for w in VNI.
    @Test(arguments: [
        Case("wa1 ", "wá "), Case("za1 ", "zá "), Case("fan2 ", "fàn "), Case("ja5 ", "jạ "),
        Case("wen ", "wen "),
    ])
    func allowZFWJ(_ c: Case) { expectTyped(c.keys, c.expected, vniZFWJ) }

    /// D20 in VNI.
    @Test(arguments: [
        ("hoc", "5", "học"), ("dep", "5", "dẹp"), ("car", "1", "car1"), ("viet", "5", "viet5"),
        ("viet", "65", "việt"), ("di", "9", "đi"), ("tuong", "7", "tương"), ("nha", "2k ", "nha2k "),
        ("học", "0", "hoc"),
    ])
    func seeded(_ displayed: String, _ keys: String, _ expected: String) {
        var t = Typist(vni)
        let ok = t.seed(displayed)
        #expect(ok)
        t.type(keys)
        #expect(t.text.map(\.value) == scalars(expected), "\(displayed) + \(keys) gave \"\(t.string)\"")
    }

    @Test func everyVowelIsPrecomposedNFC() {
        let vowels: [(keys: String, base: String)] = [
            ("a", "a"), ("a8", "a\u{0306}"), ("a6", "a\u{0302}"), ("e", "e"), ("e6", "e\u{0302}"),
            ("i", "i"), ("o", "o"), ("o6", "o\u{0302}"), ("o7", "o\u{031B}"), ("u", "u"),
            ("u7", "u\u{031B}"), ("y", "y"),
        ]
        let tones: [(key: String, mark: String)] = [
            ("", ""), ("1", "\u{0301}"), ("2", "\u{0300}"), ("3", "\u{0309}"), ("4", "\u{0303}"), ("5", "\u{0323}"),
        ]
        for v in vowels {
            for t in tones {
                let out = typed(v.keys + t.key, vni)
                #expect(out.unicodeScalars.count == 1, "\(v.keys + t.key) → \(out)")
                #expect(out == v.base + t.mark, "\(v.keys + t.key) → \(out)")
            }
        }
    }
}
