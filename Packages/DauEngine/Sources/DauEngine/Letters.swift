// Letters: composition to precomposed NFC scalars (D3) and decomposition back.
// Pure Swift, no Foundation (D10). Tables are written from the Unicode charts,
// not copied from OpenKey.

/// ASCII constants used across the engine.
enum Ch {
    static let a = UInt8(ascii: "a"), b = UInt8(ascii: "b"), c = UInt8(ascii: "c")
    static let d = UInt8(ascii: "d"), e = UInt8(ascii: "e"), f = UInt8(ascii: "f")
    static let g = UInt8(ascii: "g"), h = UInt8(ascii: "h"), i = UInt8(ascii: "i")
    static let j = UInt8(ascii: "j"), k = UInt8(ascii: "k"), n = UInt8(ascii: "n")
    static let o = UInt8(ascii: "o"), p = UInt8(ascii: "p"), q = UInt8(ascii: "q")
    static let r = UInt8(ascii: "r"), s = UInt8(ascii: "s"), t = UInt8(ascii: "t")
    static let u = UInt8(ascii: "u"), w = UInt8(ascii: "w"), x = UInt8(ascii: "x")
    static let y = UInt8(ascii: "y"), z = UInt8(ascii: "z")
}

/// Letter modifiers. A letter carries at most one.
enum Mod {
    static let none: UInt8 = 0
    /// Circumflex: â ê ô.
    static let hat: UInt8 = 1
    /// Breve on a (ă) or horn on o/u (ơ ư). Telex makes both with `w`.
    static let hook: UInt8 = 2
    /// Stroke: đ.
    static let stroke: UInt8 = 3
}

/// Tones, stored once per word.
enum Tone {
    static let none: UInt8 = 0
    static let acute: UInt8 = 1   // sắc
    static let grave: UInt8 = 2   // huyền
    static let hook: UInt8 = 3    // hỏi
    static let tilde: UInt8 = 4   // ngã
    static let dot: UInt8 = 5     // nặng
}

/// Single-byte codes that identify a letter with its modifier, used by the spelling
/// tables. Plain letters use their lowercase ASCII byte; modified letters use an
/// uppercase ASCII byte that cannot otherwise occur (codes are always case-folded).
enum Code {
    static let aHat = UInt8(ascii: "A")    // â
    static let aBreve = UInt8(ascii: "B")  // ă
    static let eHat = UInt8(ascii: "E")    // ê
    static let oHat = UInt8(ascii: "O")    // ô
    static let oHorn = UInt8(ascii: "P")   // ơ
    static let uHorn = UInt8(ascii: "U")   // ư
    static let dStroke = UInt8(ascii: "D") // đ

    @inline(__always)
    static func of(base: UInt8, mod: UInt8) -> UInt8 {
        switch mod {
        case Mod.hat:
            if base == Ch.a { return aHat }
            if base == Ch.e { return eHat }
            if base == Ch.o { return oHat }
            return base
        case Mod.hook:
            if base == Ch.a { return aBreve }
            if base == Ch.o { return oHorn }
            if base == Ch.u { return uHorn }
            return base
        case Mod.stroke:
            return base == Ch.d ? dStroke : base
        default:
            return base
        }
    }

    /// The plain letter a code is built on.
    @inline(__always)
    static func base(_ code: UInt8) -> UInt8 {
        switch code {
        case aHat, aBreve: return Ch.a
        case eHat: return Ch.e
        case oHat, oHorn: return Ch.o
        case uHorn: return Ch.u
        case dStroke: return Ch.d
        default: return code
        }
    }
}

@inline(__always) func isVowelBase(_ b: UInt8) -> Bool {
    b == Ch.a || b == Ch.e || b == Ch.i || b == Ch.o || b == Ch.u || b == Ch.y
}

@inline(__always) func isDigit(_ b: UInt8) -> Bool {
    b >= UInt8(ascii: "0") && b <= UInt8(ascii: "9")
}

/// A decomposed letter: what one precomposed scalar means to the engine.
struct LetterInfo: Sendable, Equatable {
    var base: UInt8   // lowercase ASCII letter or ASCII digit
    var mod: UInt8
    var tone: UInt8
    var upper: Bool
}

enum Letters {
    /// Vowel row index into `composed`, or -1 if `base`+`mod` is not a vowel form.
    @inline(__always)
    static func vowelRow(base: UInt8, mod: UInt8) -> Int {
        switch base {
        case Ch.a: return mod == Mod.hook ? 1 : (mod == Mod.hat ? 2 : 0)
        case Ch.e: return mod == Mod.hat ? 4 : 3
        case Ch.i: return 5
        case Ch.o: return mod == Mod.hat ? 7 : (mod == Mod.hook ? 8 : 6)
        case Ch.u: return mod == Mod.hook ? 10 : 9
        case Ch.y: return 11
        default: return -1
        }
    }

    /// Lowercase precomposed vowels. Rows: a ă â e ê i o ô ơ u ư y.
    /// Columns: no tone, sắc, huyền, hỏi, ngã, nặng (the `Tone` order).
    static let composed: [UInt32] = [
        0x0061, 0x00E1, 0x00E0, 0x1EA3, 0x00E3, 0x1EA1, // a
        0x0103, 0x1EAF, 0x1EB1, 0x1EB3, 0x1EB5, 0x1EB7, // ă
        0x00E2, 0x1EA5, 0x1EA7, 0x1EA9, 0x1EAB, 0x1EAD, // â
        0x0065, 0x00E9, 0x00E8, 0x1EBB, 0x1EBD, 0x1EB9, // e
        0x00EA, 0x1EBF, 0x1EC1, 0x1EC3, 0x1EC5, 0x1EC7, // ê
        0x0069, 0x00ED, 0x00EC, 0x1EC9, 0x0129, 0x1ECB, // i
        0x006F, 0x00F3, 0x00F2, 0x1ECF, 0x00F5, 0x1ECD, // o
        0x00F4, 0x1ED1, 0x1ED3, 0x1ED5, 0x1ED7, 0x1ED9, // ô
        0x01A1, 0x1EDB, 0x1EDD, 0x1EDF, 0x1EE1, 0x1EE3, // ơ
        0x0075, 0x00FA, 0x00F9, 0x1EE7, 0x0169, 0x1EE5, // u
        0x01B0, 0x1EE9, 0x1EEB, 0x1EED, 0x1EEF, 0x1EF1, // ư
        0x0079, 0x00FD, 0x1EF3, 0x1EF7, 0x1EF9, 0x1EF5, // y
    ]

    static let rowBase: [UInt8] = [Ch.a, Ch.a, Ch.a, Ch.e, Ch.e, Ch.i, Ch.o, Ch.o, Ch.o, Ch.u, Ch.u, Ch.y]
    static let rowMod: [UInt8] = [
        Mod.none, Mod.hook, Mod.hat, Mod.none, Mod.hat, Mod.none,
        Mod.none, Mod.hat, Mod.hook, Mod.none, Mod.hook, Mod.none,
    ]

    /// Uppercase of a lowercase scalar from `composed` (or ASCII, or đ).
    /// In Latin-1 the pairs are 0x20 apart; in Latin Extended-A/B and Latin
    /// Extended Additional the uppercase letter directly precedes the lowercase one.
    @inline(__always)
    static func uppercased(_ lower: UInt32) -> UInt32 {
        lower < 0x100 ? lower - 0x20 : lower - 1
    }

    /// The precomposed (NFC) scalar for a letter.
    @inline(__always)
    static func scalar(base: UInt8, mod: UInt8, tone: UInt8, upper: Bool) -> UInt32 {
        if isDigit(base) { return UInt32(base) }
        var lower: UInt32
        if base == Ch.d && mod == Mod.stroke {
            lower = 0x0111
        } else {
            let row = vowelRow(base: base, mod: mod)
            if row >= 0 {
                lower = composed[row * 6 + Int(tone)]
            } else {
                lower = UInt32(base)
            }
        }
        return upper ? uppercased(lower) : lower
    }

    /// Decomposes a scalar that can be part of a word: ASCII letters and digits,
    /// đ/Đ, and precomposed Vietnamese vowels. Anything else returns nil and ends the
    /// word (D4).
    static func decompose(_ v: UInt32) -> LetterInfo? {
        if v >= 0x61 && v <= 0x7A { return LetterInfo(base: UInt8(v), mod: Mod.none, tone: Tone.none, upper: false) }
        if v >= 0x41 && v <= 0x5A { return LetterInfo(base: UInt8(v + 0x20), mod: Mod.none, tone: Tone.none, upper: true) }
        if v >= 0x30 && v <= 0x39 { return LetterInfo(base: UInt8(v), mod: Mod.none, tone: Tone.none, upper: false) }
        if v < 0xC0 { return nil }
        if v == 0x0111 { return LetterInfo(base: Ch.d, mod: Mod.stroke, tone: Tone.none, upper: false) }
        if v == 0x0110 { return LetterInfo(base: Ch.d, mod: Mod.stroke, tone: Tone.none, upper: true) }
        if let found = lookup(v) {
            return LetterInfo(base: rowBase[found / 6], mod: rowMod[found / 6], tone: UInt8(found % 6), upper: false)
        }
        let lowerCandidate = v < 0x100 ? v + 0x20 : v + 1
        if let found = lookup(lowerCandidate) {
            return LetterInfo(base: rowBase[found / 6], mod: rowMod[found / 6], tone: UInt8(found % 6), upper: true)
        }
        return nil
    }

    private static func lookup(_ v: UInt32) -> Int? {
        var i = 0
        while i < composed.count {
            if composed[i] == v { return i }
            i += 1
        }
        return nil
    }

    /// Effect of a combining mark (for decomposed text read from an app, D20).
    /// Returns (tone, mod) where either may be 0, or nil if not a Vietnamese mark.
    static func combiningMark(_ v: UInt32) -> (tone: UInt8, mod: UInt8)? {
        switch v {
        case 0x0301, 0x0341: return (Tone.acute, 0)
        case 0x0300, 0x0340: return (Tone.grave, 0)
        case 0x0309: return (Tone.hook, 0)
        case 0x0303: return (Tone.tilde, 0)
        case 0x0323: return (Tone.dot, 0)
        case 0x0302: return (0, Mod.hat)
        case 0x0306, 0x031B: return (0, Mod.hook)
        default: return nil
        }
    }
}
