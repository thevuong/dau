import Testing
import DauEngine

/// A key script with its modern (D15 default) and classic results.
struct PlacementCase: Sendable, CustomTestStringConvertible {
    let keys: String
    let modern: String
    let classic: String
    init(_ keys: String, _ modern: String, _ classic: String) {
        self.keys = keys
        self.modern = modern
        self.classic = classic
    }
    var testDescription: String { "\(keys) → \(modern) / \(classic)" }
}

/// Group 3 — tone placement (modern/classic) and free marking (D15, D28).
@Suite("3. Đặt dấu, bỏ dấu tự do")
struct TonePlacementTests {
    @Test(arguments: [
        PlacementCase("hoaf", "hoà", "hòa"),
        PlacementCase("hoef", "hoè", "hòe"),
        PlacementCase("khoer", "khoẻ", "khỏe"),
        PlacementCase("thuys", "thuý", "thúy"),
        PlacementCase("quys", "quý", "quý"),
        PlacementCase("hoangf", "hoàng", "hoàng"),
        PlacementCase("thuyeenf", "thuyền", "thuyền"),
        PlacementCase("quyeets", "quyết", "quyết"),
        PlacementCase("gias", "giá", "giá"),
        PlacementCase("gif", "gì", "gì"),
        PlacementCase("ginf", "gìn", "gìn"),
        PlacementCase("giuwax", "giữa", "giữa"),
        PlacementCase("muaf", "mùa", "mùa"),
        PlacementCase("cuwar", "cửa", "cửa"),
        PlacementCase("quas", "quá", "quá"),
        PlacementCase("kiaf", "kìa", "kìa"),
        PlacementCase("hoaif", "hoài", "hoài"),
        PlacementCase("khuyur", "khuỷu", "khuỷu"),
        PlacementCase("vieejt", "việt", "việt"),
        PlacementCase("gieets", "giết", "giết"),
        PlacementCase("xooongf", "xoòng", "xoòng"),
        PlacementCase("thuowr", "thuở", "thuở"),
        PlacementCase("huees", "huế", "huế"),
        PlacementCase("tuaanf", "tuần", "tuần"),
        PlacementCase("hais", "hái", "hái"),
        PlacementCase("nuis", "núi", "núi"),
    ])
    func placement(_ c: PlacementCase) {
        expectTyped(c.keys, c.modern)
        expectTyped(c.keys, c.classic, classic)
    }

    /// D28 on: the tone can be typed anywhere after the first vowel and moves when a
    /// vowel is added ("hof" + a → "hoà").
    @Test(arguments: [
        Case("hof", "hò"), Case("hofa", "hoà"), Case("hocj", "học"), Case("vieetj", "việt"),
        Case("thuowngf", "thường"), Case("trawngf", "trằng"), Case("tuyf", "tuỳ"),
        Case("ddi", "đi"), Case("did", "đi"),
    ])
    func freeMarkingOn(_ c: Case) { expectTyped(c.keys, c.expected) }

    /// D28 off: tone keys only work right after a vowel; d → đ only for two adjacent d.
    @Test(arguments: [
        Case("hoaf", "hoà"), Case("hocj", "hocj"), Case("vieejt", "việt"),
        Case("vieetj", "viêtj"), Case("did", "did"), Case("did ", "did "), Case("ddi", "đi"),
        Case("hofa", "hoà"), Case("tuongw", "tương"),
    ])
    func freeMarkingOff(_ c: Case) { expectTyped(c.keys, c.expected, noFreeMarking) }
}
