// Vietnamese syllable spelling (D31). Tables are Dấu's own, written from standard
// orthography (not copied from OpenKey, D10).

enum SpellMode {
    /// While typing (D30): can the word still become a valid syllable by adding
    /// letters, diacritics or a tone? "viêt", "hoc", "tră", "viet" all pass.
    case prefix
    /// First key after `seed(displayed:)` (D20): the D30 prefix level, except that
    /// the vowels keep the diacritics they have now. D20 adds no other transform, so
    /// "viet" + j → "viẹt" is not accepted (the plain e cannot be fixed by the same
    /// key) while "viet" + e → "viêt" and "tra" + w → "tră" are.
    case seeded
    /// At a word boundary (D4, D21): a complete valid syllable.
    case full
}

enum Spelling {
    // MARK: Tables

    /// Initial consonants (D31), including "p" (pin, pa-tê). "gi" and "qu" are listed
    /// only so that prefix checks accept "g", "q"; they are parsed specially.
    static let initials: [UInt32] = parse("b c ch d đ g gh gi h k kh l m n ng ngh nh p ph qu r s t th tr v x")
    /// Extra initials accepted with "Cho phép z, f, w, j" (D22).
    static let extraInitials: [UInt32] = parse("f j w z")

    /// Rhymes (vowel cluster + final consonant), one line per main vowel or cluster:
    /// a, ă, â, e, ê, i, iê, y/yê, o, oo, oa, oă, oe, ô, ơ, u, uâ, uê, uô, uơ, uy/uyê,
    /// ư, ươ.
    /// ă and â never end a syllable (D31). Rhymes with final p, t, c, ch take only
    /// sắc or nặng; that rule is checked separately.
    static let rhymes: [UInt32] = parse("""
        a ac ach ai am an ang anh ao ap at au ay
        ăc ăm ăn ăng ăp ăt
        âc âm ân âng âp ât âu ây
        e ec em en eng eo ep et
        ê êch êm ên ênh êp êt êu
        i ia ich im in inh ip it iu
        iêc iêm iên iêng iêp iêt iêu
        y yêm yên yêng yêt yêu
        o oc oi om on ong op ot
        ooc oong
        oa oac oach oai oam oan oang oanh oap oat oay
        oăc oăm oăn oăng oăt
        oe oen oeo oet
        ô ôc ôi ôm ôn ông ôp ôt
        ơ ơi ơm ơn ơp ơt
        u ua uc ui um un ung up ut
        uân uâng uât uây
        uê uêch uênh
        uôc uôi uôm uôn uông uôt
        uơ
        uy uya uych uyên uyêt uynh uyp uyt uyu
        ư ưa ưc ưi ưm ưng ưt ưu
        ươc ươi ươm ươn ương ươp ươt ươu
        """)

    /// Splits a whitespace-separated list of Vietnamese strings into packed codes
    /// (one `Code` byte per letter, first letter in the low byte, at most 4 letters).
    /// Runs once, when the table is first used. Decodes UTF-8 by hand so the module
    /// needs no `String` handling.
    static func parse(_ text: StaticString) -> [UInt32] {
        var out: [UInt32] = []
        let p = text.utf8Start
        let n = text.utf8CodeUnitCount
        var i = 0
        var packed: UInt32 = 0
        var shift: UInt32 = 0
        while i <= n {
            var scalar: UInt32 = 0x20
            if i < n {
                let b0 = UInt32(p[i])
                if b0 >= 0xE0 {
                    scalar = (b0 & 0x0F) << 12 | (UInt32(p[i + 1]) & 0x3F) << 6 | (UInt32(p[i + 2]) & 0x3F)
                    i += 3
                } else if b0 >= 0xC0 {
                    scalar = (b0 & 0x1F) << 6 | (UInt32(p[i + 1]) & 0x3F)
                    i += 2
                } else {
                    scalar = b0
                    i += 1
                }
            } else {
                i += 1
            }
            if scalar <= 0x20 {
                if shift > 0 { out.append(packed) }
                packed = 0
                shift = 0
                continue
            }
            guard let info = Letters.decompose(scalar), shift < 32 else {
                preconditionFailure("bad spelling table entry")
            }
            packed |= UInt32(Code.of(base: info.base, mod: info.mod)) << shift
            shift += 8
        }
        return out
    }

    // MARK: Checks

    /// Whether `w` is acceptable in `mode`. `allowZFWJ` adds z, f, w, j as initials.
    static func check(_ w: Word, _ mode: SpellMode, allowZFWJ: Bool) -> Bool {
        let n = w.count
        if n == 0 { return mode != .full }
        var v = -1
        var i = 0
        while i < n {
            let b = w.base[i]
            if isDigit(b) { return false }
            if v < 0 && isVowelBase(b) { v = i }
            i += 1
        }
        if v < 0 {
            // Consonants only: may still grow into an initial ("n" → "ngh…").
            if mode == .full { return false }
            return isInitialPrefix(w, allowZFWJ: allowZFWJ)
        }

        var rs = v          // first letter of the rhyme
        var glide: UInt8 = 0 // 'u' after q, 'i' after g, prepended when matching rhymes
        let c0 = w.code(0)
        var first: UInt8 = 0 // base of the first rhyme letter, for c/k/g/gh/ng/ngh rules
        if v == 1 && c0 == Ch.q {
            // q is always followed by u (D31).
            if w.base[1] != Ch.u || w.mod[1] != Mod.none { return false }
            if n == 2 { return mode != .full }
            if !w.isVowel(2) { return false }
            rs = 2
            glide = Ch.u
            let fc = w.code(2)
            let fb = Code.base(fc)
            if fb == Ch.u || fb == Ch.i { return false }
            if fc == Ch.o && mode == .full { return false }
        } else if v == 1 && c0 == Ch.g && w.base[1] == Ch.i {
            if n > 2 && w.isVowel(2) {
                // "gi" + vowel: "gia", "giữa", "giết" (gi + iêt written "giêt").
                rs = 2
                glide = Ch.i
                if w.base[2] == Ch.i { return false }
            } else {
                // "gì", "gìn": g + i, the i of "gi" merged with the rhyme.
                rs = 1
            }
        } else if v > 0 {
            if v > 3 { return false }
            var packed: UInt32 = 0
            var k = 0
            while k < v {
                packed |= UInt32(w.code(k)) << (8 * UInt32(k))
                k += 1
            }
            if !contains(initials, packed) && !(allowZFWJ && contains(extraInitials, packed)) {
                return false
            }
            first = w.base[v]
            let frontVowel = first == Ch.e || first == Ch.i || first == Ch.y
            switch packed {
            case pack(Ch.c), pack(Ch.g), pack(Ch.n, Ch.g):
                // c, g, ng never before i, e, ê, y (g + i is the "gi" case above).
                if frontVowel { return false }
            case pack(Ch.k), pack(Ch.g, Ch.h), pack(Ch.n, Ch.g, Ch.h):
                // k, gh, ngh only before i, e, ê, y.
                if !frontVowel { return false }
            default:
                break
            }
        }

        // Rhyme: vowels, then consonants, then nothing.
        var k = rs
        while k < n && w.isVowel(k) { k += 1 }
        let finalStart = k
        while k < n && !w.isVowel(k) { k += 1 }
        if k != n { return false }
        let length = n - rs
        if length > 4 { return false }
        var packed: UInt32 = 0
        k = 0
        while k < length {
            packed |= UInt32(w.code(rs + k)) << (8 * UInt32(k))
            k += 1
        }
        var ok = rhymeMatches(packed, length: length, mode: mode)
        if !ok && glide != 0 && length <= 3 {
            ok = rhymeMatches(UInt32(glide) | packed << 8, length: length + 1, mode: mode)
        }
        if !ok { return false }

        // Stop finals p, t, c, ch take only sắc or nặng (D31).
        if finalStart < n {
            let fc = w.code(finalStart)
            if fc == Ch.p || fc == Ch.t || fc == Ch.c {
                switch mode {
                case .full:
                    if w.tone != Tone.acute && w.tone != Tone.dot { return false }
                case .prefix, .seeded:
                    break // D30, D20: the tone can still change before the word ends.
                }
            }
        }
        return true
    }

    @inline(__always)
    static func pack(_ a: UInt8, _ b: UInt8 = 0, _ c: UInt8 = 0) -> UInt32 {
        UInt32(a) | UInt32(b) << 8 | UInt32(c) << 16
    }

    @inline(__always)
    static func contains(_ table: [UInt32], _ packed: UInt32) -> Bool {
        var i = 0
        while i < table.count {
            if table[i] == packed { return true }
            i += 1
        }
        return false
    }

    @inline(__always)
    static func entryLength(_ e: UInt32) -> Int {
        (32 - e.leadingZeroBitCount + 7) / 8
    }

    /// Consonant-only word: is it a prefix of some initial?
    static func isInitialPrefix(_ w: Word, allowZFWJ: Bool) -> Bool {
        let n = w.count
        if n > 3 { return false }
        var packed: UInt32 = 0
        var k = 0
        while k < n {
            packed |= UInt32(w.code(k)) << (8 * UInt32(k))
            k += 1
        }
        let mask: UInt32 = n >= 4 ? 0xFFFF_FFFF : (UInt32(1) << (8 * UInt32(n))) - 1
        var i = 0
        while i < initials.count {
            let e = initials[i]
            if entryLength(e) >= n && (e & mask) == packed { return true }
            i += 1
        }
        if allowZFWJ {
            i = 0
            while i < extraInitials.count {
                let e = extraInitials[i]
                if entryLength(e) >= n && (e & mask) == packed { return true }
                i += 1
            }
        }
        return false
    }

    static func rhymeMatches(_ packed: UInt32, length: Int, mode: SpellMode) -> Bool {
        let mask: UInt32 = length >= 4 ? 0xFFFF_FFFF : (UInt32(1) << (8 * UInt32(length))) - 1
        var i = 0
        while i < rhymes.count {
            let e = rhymes[i]
            i += 1
            let el = entryLength(e)
            switch mode {
            case .full:
                if el == length && e == packed { return true }
            case .seeded:
                if el >= length && (e & mask) == packed { return true }
            case .prefix:
                if el >= length && compatiblePrefix(packed, e, length: length) { return true }
            }
        }
        return false
    }

    /// Typed letters are compatible with a table rhyme if each one is the same letter,
    /// or a plain vowel that a later key can still turn into the table's letter
    /// ("viet" is compatible with "iêt").
    @inline(__always)
    static func compatiblePrefix(_ typed: UInt32, _ entry: UInt32, length: Int) -> Bool {
        var k = 0
        while k < length {
            let shift = 8 * UInt32(k)
            let t = UInt8(truncatingIfNeeded: typed >> shift)
            let e = UInt8(truncatingIfNeeded: entry >> shift)
            if t != e {
                let plainVowel = t == Ch.a || t == Ch.e || t == Ch.o || t == Ch.u
                if !plainVowel || Code.base(e) != t { return false }
            }
            k += 1
        }
        return true
    }
}
