// Dấu's Vietnamese input engine (Telex, Telex đơn giản). Pure Swift, no Foundation.
//
// Hot path rules (CLAUDE.md): no `String`, no `any`, no closures, no heap allocation
// per key. State is a handful of SIMD vectors and integers; output is a `TextBuffer`.
//
// Model: the engine keeps three things for the word being typed:
// - `word`: letters with modifiers and one tone (what the word *is*);
// - `screen`: the scalars currently shown in the app for this word;
// - `raw`: the restore baseline (D4): keys typed since the last baseline. The
//   baseline is the start of the word, or the text shown right after a double key
//   (D26), a Backspace (D32) or a seed (D20).
// Each key updates `word`, renders it, and diffs against `screen` to produce the
// smallest replacement.

public struct VietEngine: Sendable {
    /// Restore-baseline capacity. A 7-letter word (D33) needs at most about 3 keys per
    /// letter (base, modifier, tone) plus a few corrections; 31 leaves room for that and
    /// for the word-ending key inside one 32-scalar `TextBuffer`. Typing more keys than
    /// this inside one word is treated like an over-long word (D33).
    public static let rawCapacity = TextBuffer.capacity - 1

    public var options: EngineOptions

    var word = Word()
    var screen = TextBuffer()
    var raw = TextBuffer()
    /// D26: a doubled key; transforms stay off until the word ends, even after ⌫.
    var lockedByDouble = false
    /// D30: the word is no longer a prefix of a valid syllable.
    var lockedBySpelling = false
    /// D33: the word grew past 7 letters; everything passes through until it ends.
    var overflow = false
    /// D20: the next key is the first one after `seed(displayed:)`.
    var seedPending = false

    public init(options: EngineOptions = EngineOptions()) {
        self.options = options
    }

    /// Whether the engine is tracking a word (useful for the IMK layer).
    public var isComposing: Bool { word.count > 0 || overflow }

    /// Forget the current word without restoring anything (D4): arrows, Esc, mouse
    /// clicks, ⌘/⌃/⌥ shortcuts, focus changes.
    public mutating func reset() {
        word = Word()
        screen.removeAll()
        raw.removeAll()
        lockedByDouble = false
        lockedBySpelling = false
        overflow = false
        seedPending = false
    }

    // MARK: - Keys

    /// Handles one typed character (already translated by the keyboard layout).
    ///
    /// - Letters and digits extend the word.
    /// - Any other printable character (Space, Return, Tab, punctuation, symbols) ends
    ///   the word (D4): the word is restored or expanded if needed and the character is
    ///   included in the replacement text.
    /// - Control characters and function-key characters reset without restoring.
    public mutating func handle(_ key: Unicode.Scalar) -> Action {
        let v = key.value
        if (v < 0x20 && v != 0x09 && v != 0x0A && v != 0x0D) || v == 0x7F || (v >= 0xF700 && v <= 0xF8FF) {
            reset()
            return .passThrough
        }
        guard let info = Letters.decompose(v) else {
            return finishWord(appending: v)
        }
        if overflow { return .passThrough }
        return handleLetter(v, info)
    }

    /// Ends the word without inserting a character, for word-ending keys the IMK layer
    /// prefers to pass to the app itself (Return, Tab). Performs the same restore /
    /// shortcut expansion as `handle` with a boundary character, then resets.
    /// `.passThrough` means there is nothing to replace.
    public mutating func endWord() -> Action {
        finishWord(appending: nil)
    }

    /// Backspace (D32): drops the last letter shown, re-places the tone for the rest,
    /// and makes the text shown the new restore baseline. D26's lock stays; D30's is
    /// recomputed. Returns `.passThrough` when the app's own Backspace gives the right
    /// result (or when the engine is not tracking a word).
    public mutating func backspace() -> Action {
        if overflow { return .passThrough }
        if word.count == 0 {
            reset()
            return .passThrough
        }
        seedPending = false
        let tone = word.tone
        word.removeLast()
        // D32: the tone stays with the word and moves to the remaining rhyme
        // ("hoà" ⌫ → "hò"); it goes only when no vowel is left.
        if word.hasVowel {
            word.tone = tone
            lockedBySpelling = !isValid(word, .prefix)
            if !isLocked || word.tonePos < 0 { word.placeTone(modern: modern) }
        } else {
            word.tone = Tone.none
            word.tonePos = -1
            lockedBySpelling = !isValid(word, .prefix)
        }
        let rendered = render(word)
        raw = rendered
        var action = VietEngine.diff(from: screen, to: rendered, typed: nil)
        if case .replace(let deleteCount, let insert) = action, deleteCount == 1, insert.isEmpty {
            action = .passThrough
        }
        screen = rendered
        if word.count == 0 { reset() }
        return action
    }

    /// "Thêm dấu cho từ đã gõ" (D20): starts a word from text already in the app,
    /// read as letters (not keystrokes). Call with the word right before the cursor
    /// when the buffer is empty, then pass the key to `handle`. The seeded text becomes
    /// the restore baseline (D4). The first key after seeding applies only if the
    /// result is valid with the diacritics shown ("viet" + j → "vietj").
    ///
    /// Accepts precomposed or decomposed (NFD) text. Returns false, and stays empty,
    /// if the text is not a word the engine can track (non-letters, more than 7
    /// letters, too long).
    @discardableResult
    public mutating func seed<S: Sequence>(displayed: S) -> Bool where S.Element == Unicode.Scalar {
        reset()
        var w = Word()
        var shown = TextBuffer()
        for scalar in displayed {
            let v = scalar.value
            if shown.length >= VietEngine.rawCapacity { reset(); return false }
            if let mark = Letters.combiningMark(v) {
                guard w.count > 0 else { reset(); return false }
                let last = w.count - 1
                if mark.tone != Tone.none {
                    if w.tone != Tone.none || !w.isVowel(last) { reset(); return false }
                    w.tone = mark.tone
                    w.tonePos = last
                } else {
                    if w.mod[last] != Mod.none || !w.isVowel(last) { reset(); return false }
                    w.mod[last] = mark.mod
                }
                shown.append(v)
                continue
            }
            guard let info = Letters.decompose(v), w.count < Word.maxLetters else {
                reset()
                return false
            }
            w.append(base: info.base, mod: info.mod, upper: info.upper)
            if info.tone != Tone.none {
                if w.tone != Tone.none { reset(); return false }
                w.tone = info.tone
                w.tonePos = w.count - 1
            }
            shown.append(v)
        }
        if w.count == 0 { return false }
        word = w
        screen = shown
        raw = shown
        lockedBySpelling = !isValid(word, .prefix)
        seedPending = true
        return true
    }

    // MARK: - Letter keys

    var isLocked: Bool { lockedByDouble || lockedBySpelling }
    var modern: Bool { options.tonePlacement == .modern }

    enum Outcome {
        /// The key changed the word in place.
        case applied
        /// The key undid an earlier transform (D26). `appendKey`: add the key as a
        /// letter. `lock`: lock transforms for the rest of the word (not for "ooo").
        case doubled(appendKey: Bool, lock: Bool)
        /// Lone Telex `w`: append "ư" (D23).
        case appendHornedU
        /// Not a transform here: the key is a plain letter.
        case none
    }

    mutating func handleLetter(_ v: UInt32, _ info: LetterInfo) -> Action {
        let seeded = seedPending
        seedPending = false
        let isPlainAscii = v < 0x80 && !isDigit(info.base)

        if !isLocked && isPlainAscii {
            var w = word
            let mode: SpellMode = seeded ? .seeded : .prefix
            switch transform(&w, key: info.base, upper: info.upper, mode: mode) {
            case .applied:
                if isValid(w, mode) {
                    if raw.length >= VietEngine.rawCapacity { return startOverflow(v) }
                    w.placeTone(modern: modern)
                    word = w
                    raw.append(v)
                    return commit(typed: v)
                }
            case .doubled(let appendKey, let lock):
                if appendKey {
                    if w.count >= Word.maxLetters { return startOverflow(v) }
                    w.append(base: info.base, mod: Mod.none, upper: info.upper)
                }
                if !seeded || isValid(w, .seeded) {
                    word = w
                    if lock { lockedByDouble = true }
                    lockedBySpelling = !isValid(word, .prefix)
                    if !isLocked { word.placeTone(modern: modern) }
                    let rendered = render(word)
                    raw = rendered // D4: the baseline after a double key is the text shown.
                    return commit(typed: v)
                }
            case .appendHornedU:
                if w.count >= Word.maxLetters { return startOverflow(v) }
                w.append(base: Ch.u, mod: Mod.hook, upper: info.upper, standalone: true)
                if isValid(w, mode) {
                    if raw.length >= VietEngine.rawCapacity { return startOverflow(v) }
                    word = w
                    raw.append(v)
                    return commit(typed: v)
                }
            case .none:
                break
            }
        }
        return appendLiteral(v, info)
    }

    /// Adds the key as an ordinary letter.
    mutating func appendLiteral(_ v: UInt32, _ info: LetterInfo) -> Action {
        if word.count >= Word.maxLetters || raw.length >= VietEngine.rawCapacity {
            return startOverflow(v)
        }
        word.append(base: info.base, mod: info.mod, upper: info.upper)
        if info.tone != Tone.none {
            // A precomposed toned letter typed directly. Two tones cannot be valid.
            if word.tone == Tone.none {
                word.tone = info.tone
                word.tonePos = word.count - 1
            } else {
                lockedBySpelling = true
            }
        }
        raw.append(v)
        if !isLocked {
            word.normalizeHornedUO()
            if !isValid(word, .prefix) { lockedBySpelling = true }
            if !isLocked { word.placeTone(modern: modern) }
        }
        return commit(typed: v)
    }

    /// Applies a Telex key to `w` if it is a transform there.
    func transform(_ w: inout Word, key: UInt8, upper: Bool, mode: SpellMode) -> Outcome {
        switch key {
        case Ch.s: return toneKey(&w, Tone.acute)
        case Ch.f: return toneKey(&w, Tone.grave)
        case Ch.r: return toneKey(&w, Tone.hook)
        case Ch.x: return toneKey(&w, Tone.tilde)
        case Ch.j: return toneKey(&w, Tone.dot)
        case Ch.z:
            // z removes the tone; without one it is the letter z.
            if w.tone == Tone.none { return .none }
            w.tone = Tone.none
            w.tonePos = -1
            return .applied
        case Ch.a, Ch.e, Ch.o: return hatKey(&w, key)
        case Ch.w: return wKey(&w, mode: mode)
        case Ch.d: return dKey(&w)
        default: return .none
        }
    }

    /// s f r x j. With free marking (D28) anywhere after the first vowel; without it
    /// only right after a vowel. The same tone again undoes it (D26: "carr" → "car").
    func toneKey(_ w: inout Word, _ tone: UInt8) -> Outcome {
        let (s, e) = w.nucleus()
        if s >= e { return .none }
        if !options.freeMarking && !w.isVowel(w.count - 1) { return .none }
        if w.tone == tone {
            w.tone = Tone.none
            w.tonePos = -1
            return .doubled(appendKey: true, lock: true)
        }
        w.tone = tone
        return .applied
    }

    /// aa ee oo: puts a circumflex on the matching vowel of the cluster, even across a
    /// final consonant ("viet" + e → "viêt", D28). Again undoes it ("aaa" → "aa");
    /// "ooo" → "oo" does not lock (D26, for "xoong").
    func hatKey(_ w: inout Word, _ key: UInt8) -> Outcome {
        let (s, e) = w.nucleus()
        var target = -1
        var i = s
        while i < e {
            if w.base[i] == key { target = i }
            i += 1
        }
        if target < 0 { return .none }
        if w.mod[target] == Mod.hat {
            w.mod[target] = Mod.none
            return .doubled(appendKey: true, lock: key != Ch.o)
        }
        w.mod[target] = Mod.hat
        return .applied
    }

    /// w: breve/horn on a, o, u of the cluster (aw ow uw, "uo" + w → "ươ"/"uơ").
    /// With no a, o, u in the word: Telex appends "ư" (D23); Telex đơn giản keeps the
    /// letter w (D29).
    func wKey(_ w: inout Word, mode: SpellMode) -> Outcome {
        let (s, e) = w.nucleus()
        if s < e {
            // "uo" pair: both get the horn, except an open "uơ" (thuở, huơ).
            var i = s
            while i + 1 < e {
                if w.base[i] == Ch.u && w.base[i + 1] == Ch.o {
                    let uHook = w.mod[i] == Mod.hook
                    let oHook = w.mod[i + 1] == Mod.hook
                    let hasFollower = i + 2 < w.count
                    if oHook && (uHook || !hasFollower) {
                        w.mod[i] = Mod.none
                        w.mod[i + 1] = Mod.none
                        return .doubled(appendKey: true, lock: true)
                    }
                    let saved = w
                    w.mod[i + 1] = Mod.hook
                    if hasFollower { w.mod[i] = Mod.hook }
                    if isValid(w, mode) { return .applied }
                    w = saved
                    return .none
                }
                i += 1
            }
            // Single a/o/u: try from the last one backwards ("mua" → "mưa",
            // "hoa" → "hoă"), keeping the first that leaves a valid prefix.
            var targets = 0
            var hooked = -1
            i = e - 1
            while i >= s {
                let b = w.base[i]
                if b == Ch.a || b == Ch.o || b == Ch.u {
                    targets += 1
                    if w.mod[i] == Mod.hook {
                        if hooked < 0 { hooked = i }
                    } else {
                        let saved = w.mod[i]
                        w.mod[i] = Mod.hook
                        if isValid(w, mode) { return .applied }
                        w.mod[i] = saved
                    }
                }
                i -= 1
            }
            if targets > 0 && hooked >= 0 {
                var unhooked = 0
                i = s
                while i < e {
                    let b = w.base[i]
                    if (b == Ch.a || b == Ch.o || b == Ch.u) && w.mod[i] != Mod.hook { unhooked += 1 }
                    i += 1
                }
                if unhooked == 0 {
                    // Every target already has it: undo (D26 "aww" → "aw", "ww" → "w").
                    if w.standalone[hooked] == 1 {
                        w.base[hooked] = Ch.w
                        w.mod[hooked] = Mod.none
                        w.standalone[hooked] = 0
                        return .doubled(appendKey: false, lock: true)
                    }
                    w.mod[hooked] = Mod.none
                    return .doubled(appendKey: true, lock: true)
                }
            }
            return .none
        }
        if options.inputMethod == .telex && !w.hasVowel { return .appendHornedU }
        return .none
    }

    /// d → đ on the initial d: right after it ("dd"), or anywhere after a vowel with
    /// free marking (D28: "did" → "đi"). Again undoes it ("ddd" → "dd").
    func dKey(_ w: inout Word) -> Outcome {
        guard w.count >= 1, w.base[0] == Ch.d else { return .none }
        let eligible = w.count == 1 || (options.freeMarking && w.hasVowel)
        guard eligible else { return .none }
        if w.mod[0] == Mod.stroke {
            w.mod[0] = Mod.none
            return .doubled(appendKey: true, lock: true)
        }
        w.mod[0] = Mod.stroke
        return .applied
    }

    // MARK: - Word end

    mutating func finishWord(appending key: UInt32?) -> Action {
        if overflow || word.count == 0 {
            reset()
            return .passThrough
        }
        var output = screen
        let allowZFWJ = options.advanced == .allowZFWJ
        var expandedWord = false
        if options.advanced == .consonantShortcuts {
            let (expanded, changed) = word.expandedShortcuts()
            if changed {
                expandedWord = true
                var e = expanded
                e.placeTone(modern: modern)
                if Spelling.check(e, .full, allowZFWJ: false) {
                    output = render(e)
                } else if options.autoRestore {
                    output = raw
                }
            }
        }
        if !expandedWord && !Spelling.check(word, .full, allowZFWJ: allowZFWJ) && options.autoRestore {
            output = raw
        }
        var action = Action.passThrough
        if output != screen {
            var insert = TextBuffer()
            let common = VietEngine.commonPrefix(screen, output)
            var i = common
            while i < output.length {
                insert.append(output.value(at: i))
                i += 1
            }
            if let key { insert.append(key) }
            action = .replace(deleteCount: screen.length - common, insert: insert)
        }
        reset()
        return action
    }

    /// D33: the word is longer than any syllable. Restore the keys typed (if anything
    /// was transformed) and let the rest of the word through.
    mutating func startOverflow(_ v: UInt32) -> Action {
        overflow = true
        var action = Action.passThrough
        if raw != screen {
            var output = raw
            output.append(v)
            action = VietEngine.diff(from: screen, to: output, typed: nil)
        }
        word = Word()
        screen.removeAll()
        raw.removeAll()
        return action
    }

    // MARK: - Helpers

    func isValid(_ w: Word, _ mode: SpellMode) -> Bool {
        switch options.advanced {
        case .consonantShortcuts:
            // D21: while typing, f/j at the start and g/h/k at the end count as the
            // consonants they stand for.
            return Spelling.check(w.expandedShortcuts().word, mode, allowZFWJ: false)
        case .allowZFWJ:
            return Spelling.check(w, mode, allowZFWJ: true)
        case .off:
            return Spelling.check(w, mode, allowZFWJ: false)
        }
    }

    func render(_ w: Word) -> TextBuffer {
        var out = TextBuffer()
        var i = 0
        while i < w.count {
            let tone = i == w.tonePos ? w.tone : Tone.none
            out.append(Letters.scalar(base: w.base[i], mod: w.mod[i], tone: tone, upper: w.upper[i] == 1))
            i += 1
        }
        return out
    }

    /// Renders the word, diffs against the screen, and records the new screen.
    mutating func commit(typed v: UInt32) -> Action {
        let rendered = render(word)
        let action = VietEngine.diff(from: screen, to: rendered, typed: v)
        screen = rendered
        return action
    }

    static func commonPrefix(_ a: TextBuffer, _ b: TextBuffer) -> Int {
        let limit = a.length < b.length ? a.length : b.length
        var p = 0
        while p < limit && a.value(at: p) == b.value(at: p) { p += 1 }
        return p
    }

    /// Smallest replacement turning `old` into `new`. If the only change is the typed
    /// character appended at the end, the app can insert it itself.
    static func diff(from old: TextBuffer, to new: TextBuffer, typed: UInt32?) -> Action {
        let p = commonPrefix(old, new)
        if let typed, p == old.length, new.length == old.length + 1, new.value(at: p) == typed {
            return .passThrough
        }
        var insert = TextBuffer()
        var i = p
        while i < new.length {
            insert.append(new.value(at: i))
            i += 1
        }
        return .replace(deleteCount: old.length - p, insert: insert)
    }
}
