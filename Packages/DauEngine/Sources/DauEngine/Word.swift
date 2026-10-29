// The word being typed, as letters (not keystrokes). Fixed capacity, no heap.

struct Word: Sendable, Equatable {
    /// Letters tracked per word. D33 caps a word at 7 letters; consonant shortcuts
    /// (D21) can add two more when the word is rendered at a boundary.
    static let capacity = 16
    /// D33: the longest Vietnamese syllable ("nghiêng") has 7 letters.
    static let maxLetters = 7

    var base = SIMD16<UInt8>()
    var mod = SIMD16<UInt8>()
    var upper = SIMD16<UInt8>()
    /// 1 when the letter is an "ư" produced by a lone Telex `w` (D23), so a second
    /// `w` turns it back into the letter w (D26 "ww" → "w").
    var standalone = SIMD16<UInt8>()
    var count = 0
    /// One tone per word; `tonePos` is the letter that shows it, or -1.
    var tone: UInt8 = Tone.none
    var tonePos = -1

    @inline(__always) func code(_ i: Int) -> UInt8 { Code.of(base: base[i], mod: mod[i]) }
    @inline(__always) func isVowel(_ i: Int) -> Bool { isVowelBase(base[i]) }

    @inline(__always)
    mutating func append(base b: UInt8, mod m: UInt8, upper u: Bool, standalone s: Bool = false) {
        precondition(count < Word.capacity, "Word overflow")
        base[count] = b
        mod[count] = m
        upper[count] = u ? 1 : 0
        standalone[count] = s ? 1 : 0
        count += 1
    }

    mutating func removeLast() {
        guard count > 0 else { return }
        count -= 1
        base[count] = 0
        mod[count] = 0
        upper[count] = 0
        standalone[count] = 0
        if tonePos == count { tone = Tone.none; tonePos = -1 }
    }

    var hasVowel: Bool {
        var i = 0
        while i < count {
            if isVowel(i) { return true }
            i += 1
        }
        return false
    }

    /// The vowel cluster that can carry the tone, as a half-open range of indices.
    /// The `u` of "qu" and the `i` of "gi" (when another vowel follows) belong to the
    /// initial consonant, so "quá", "giá" put the tone on `a`, while "gì" keeps `i`.
    /// Returns an empty range when there is no such cluster.
    func nucleus() -> (start: Int, end: Int) {
        var v = 0
        while v < count && !isVowel(v) { v += 1 }
        if v == count { return (count, count) }
        var s = v
        if v == 1 && code(0) == Ch.q && base[1] == Ch.u {
            s = 2
        } else if v == 1 && code(0) == Ch.g && base[1] == Ch.i && count > 2 && isVowel(2) {
            s = 2
        }
        var e = s
        while e < count && isVowel(e) { e += 1 }
        return (s, e)
    }

    /// Puts `tone` on the right vowel (D15 modern/classic placement).
    ///
    /// Rules (Vietnamese orthography):
    /// 1. If the cluster has a vowel with a diacritic (ă â ê ô ơ ư), the tone goes on
    ///    the last such vowel: "mưa", "việt", "người", "khuyến", "thuở".
    /// 2. One vowel: on it. Three vowels: the middle one ("hoài", "khuỷu", "khuya").
    /// 3. Two vowels followed by a final consonant: the second ("hoàng", "xoòng").
    /// 4. Two vowels, open syllable: "oa", "oe", "uy" take the second in modern
    ///    style ("hoà", "khoẻ", "thuý") and the first in classic style ("hòa");
    ///    "oo" takes the second; everything else the first ("mùa", "kìa", "hai").
    mutating func placeTone(modern: Bool) {
        if tone == Tone.none { tonePos = -1; return }
        let (s, e) = nucleus()
        if s >= e { tone = Tone.none; tonePos = -1; return }
        var lastModified = -1
        var i = s
        while i < e {
            if mod[i] != Mod.none { lastModified = i }
            i += 1
        }
        if lastModified >= 0 { tonePos = lastModified; return }
        let length = e - s
        if length == 1 { tonePos = s; return }
        if length >= 3 { tonePos = s + 1; return }
        if e < count { tonePos = s + 1; return }
        let b0 = base[s], b1 = base[s + 1]
        if (b0 == Ch.o && (b1 == Ch.a || b1 == Ch.e)) || (b0 == Ch.u && b1 == Ch.y) {
            tonePos = modern ? s + 1 : s
        } else if b0 == Ch.o && b1 == Ch.o {
            tonePos = s + 1
        } else {
            tonePos = s
        }
    }

    /// "uơ"/"ưo" followed by another letter becomes "ươ" ("tưon" → "tươn",
    /// "đuơc" → "đươc", "huơu" → "hươu"). Without a following letter "uơ" stays, for
    /// "thuở" and "huơ" (OPENKEY-NOTES B4).
    mutating func normalizeHornedUO() {
        let (s, e) = nucleus()
        var i = s
        while i + 1 < e {
            if base[i] == Ch.u && base[i + 1] == Ch.o && i + 2 < count {
                let uHook = mod[i] == Mod.hook
                let oHook = mod[i + 1] == Mod.hook
                if (uHook && mod[i + 1] == Mod.none) || (mod[i] == Mod.none && oHook) {
                    mod[i] = Mod.hook
                    mod[i + 1] = Mod.hook
                }
            }
            i += 1
        }
    }

    /// The word with consonant shortcuts applied (D21): f → ph, j → gi (j → g before
    /// i) and, in VNI only, w → qu (D23) at the start; g → ng, h → nh, k → ch at the
    /// end after a vowel.
    /// Case: the added letter is uppercase only if the shortcut letter and the next
    /// letter are both uppercase ("Fan" → "Phan", "FAN" → "PHAN"); a final shortcut
    /// copies its own case. Returns `changed == false` when nothing applies.
    func expandedShortcuts(vni: Bool) -> (word: Word, changed: Bool) {
        var out = Word()
        out.tone = tone
        var changed = false
        var shift = 0
        var i = 0
        if count > 0 && mod[0] == Mod.none && (base[0] == Ch.f || base[0] == Ch.j || (vni && base[0] == Ch.w)) {
            let up = upper[0] == 1
            let secondUp = up && (count > 1 ? upper[1] == 1 : true)
            if base[0] == Ch.f {
                out.append(base: Ch.p, mod: Mod.none, upper: up)
                out.append(base: Ch.h, mod: Mod.none, upper: secondUp)
                shift = 1
            } else if base[0] == Ch.w {
                out.append(base: Ch.q, mod: Mod.none, upper: up)
                out.append(base: Ch.u, mod: Mod.none, upper: secondUp)
                shift = 1
            } else if count > 1 && base[1] == Ch.i {
                out.append(base: Ch.g, mod: Mod.none, upper: up)
            } else {
                out.append(base: Ch.g, mod: Mod.none, upper: up)
                out.append(base: Ch.i, mod: Mod.none, upper: secondUp)
                shift = 1
            }
            changed = true
            i = 1
        }
        let last = count - 1
        while i < count {
            if i == last && i >= 1 && isVowel(i - 1) && mod[i] == Mod.none
                && (base[i] == Ch.g || base[i] == Ch.h || base[i] == Ch.k) {
                let up = upper[i] == 1
                if base[i] == Ch.k {
                    out.append(base: Ch.c, mod: Mod.none, upper: up)
                    out.append(base: Ch.h, mod: Mod.none, upper: up)
                } else {
                    out.append(base: Ch.n, mod: Mod.none, upper: up)
                    out.append(base: base[i], mod: Mod.none, upper: up)
                }
                changed = true
            } else {
                out.append(base: base[i], mod: mod[i], upper: upper[i] == 1, standalone: standalone[i] == 1)
            }
            i += 1
        }
        out.tonePos = tonePos >= 0 ? tonePos + shift : -1
        return (out, changed)
    }
}
