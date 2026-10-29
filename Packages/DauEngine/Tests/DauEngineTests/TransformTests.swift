import Testing
import DauEngine

/// Group 2 — Telex transform keys (aa ee oo aw ow uw w dd, "uo" + w) and doubles.
@Suite("2. Phím biến đổi Telex")
struct TransformTests {
    @Test(arguments: [
        Case("dd", "đ"), Case("ddd", "dd"), Case("ddi", "đi"), Case("did", "đi"),
        Case("aa", "â"), Case("aaa", "aa"), Case("ee", "ê"), Case("eee", "ee"),
        Case("oo", "ô"),
        Case("aw", "ă"), Case("ow", "ơ"), Case("uw", "ư"),
        Case("aww", "aw"), Case("oww", "ow"), Case("uww", "uw"),
        Case("aaw", "ă"),   // w replaces the circumflex with a breve
        Case("awa", "â"),   // a replaces the breve with a circumflex
        Case("asz", "a"), Case("az", "az"), Case("asf", "à"),
    ])
    func basicKeys(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D23 (Telex): a lone w is ư; D26: ww → w and the word stays locked.
    @Test(arguments: [
        Case("w", "ư"), Case("W", "Ư"), Case("ww", "w"), Case("www", "ww"),
        Case("wa", "ưa"), Case("wa ", "ưa "), Case("tw", "tư"), Case("trw", "trư"),
        Case("ngw", "ngư"), Case("kw", "kw"),
    ])
    func loneW(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D26 exception: ooo → oo without locking, so "xoong", "xoòng" can be typed.
    @Test(arguments: [
        Case("xooong", "xoong"), Case("xooong ", "xoong "), Case("xooongf", "xoòng"),
        Case("booong ", "boong "),
    ])
    func tripleO(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// "uo" + w → ươ when something follows, "uơ" for an open syllable (thuở, huơ;
    /// OPENKEY-NOTES B4, chosen for Dấu). "ưo"/"uơ" + a following letter → "ươ".
    @Test(arguments: [
        Case("nguoiwf", "người"), Case("nguwowif", "người"), Case("dduowcj", "được"),
        Case("truwowngf", "trường"), Case("tuwongf", "tường"), Case("thuowngf", "thường"),
        Case("thuowng", "thương"), Case("uown", "ươn"), Case("uwon", "ươn"),
        Case("thuowr", "thuở"), Case("THUOWR", "THUỞ"), Case("huow", "huơ"),
        Case("huowu", "hươu"), Case("ruouwj", "rượu"), Case("quow", "quơ"),
        Case("uow", "uơ"), Case("nguowiw", "nguoiw"),
    ])
    func hornedUO(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D28: transform keys reach the matching vowel anywhere in the word.
    @Test(arguments: [
        Case("tuongw", "tương"), Case("vieet", "viêt"), Case("viete", "viêt"),
        Case("tieen", "tiên"), Case("tien e", "tien e"), Case("muaw", "mưa"),
        Case("hoawcj", "hoặc"), Case("toio", "tôi"), Case("dinhd", "đinh"),
    ])
    func freePlacementOfTransforms(_ c: Case) { expectTyped(c.keys, c.expected) }

    @Test(arguments: [
        Case("quyeets", "quyết"), Case("gias", "giá"), Case("gif", "gì"), Case("ginf", "gìn"),
        Case("giuwax", "giữa"), Case("gieets", "giết"), Case("gieengs", "giếng"),
        Case("khuyur", "khuỷu"), Case("khuya", "khuya"), Case("nghieengf", "nghiềng"),
        Case("chuyeenj", "chuyện"), Case("xoays", "xoáy"), Case("khuaays", "khuấy"),
    ])
    func hardWords(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D29: Telex đơn giản = Telex except w with no a/o/u in the word stays w.
    @Test(arguments: [
        Case("web ", "web "), Case("wa", "wa"), Case("wa ", "wa "), Case("www", "www"),
        Case("w", "w"), Case("tw", "tw"),
        Case("aw", "ă"), Case("ow", "ơ"), Case("uw", "ư"), Case("aww", "aw"),
        Case("tuongw", "tương"), Case("muaw", "mưa"), Case("nguoiwf", "người"),
        Case("u[", "u["),
    ])
    func simpleTelexW(_ c: Case) { expectTyped(c.keys, c.expected, simpleTelex) }
}
