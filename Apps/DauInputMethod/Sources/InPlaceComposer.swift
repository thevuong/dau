import Foundation
import DauEngine

/// The client calls in-place mode makes. `IMKTextInput` in the input method (through a
/// timing wrapper), a scripted fake document in the unit tests.
protocol InPlaceClient {
    func selectedRange() -> NSRange
    /// Plain text of `range` in the document (`attributedSubstring(from:)`), or nil if
    /// the client gives none. Only called for D20, never while a word is being typed.
    func text(in range: NSRange) -> String?
    func insertText(_ text: String, replacementRange: NSRange)
}

/// In-place mode (method A, D11): the word being typed is replaced in the document with
/// one `insertText(_:replacementRange:)` per key, at the position `selectedRange` gives.
///
/// Calls per key (N3):
/// - key that passes through: none;
/// - key whose result only appends at the cursor: one `insertText` (replacementRange
///   NSNotFound), no `selectedRange`;
/// - key that replaces text before the cursor: one `selectedRange`, one `insertText`;
/// - D20 "Thêm dấu cho từ đã gõ" (see `addMarks`): on a tone or transform key typed with
///   no word in the engine and an unknown text before the cursor, one `selectedRange`
///   and one `text(in:)` (attributedSubstring), then at most one `insertText`.
///
/// Pure value type over `InPlaceClient`, no IMK, unit tested in DauInputMethodTests.
struct InPlaceComposer {
    /// D20 on (`DauSettings.addMarksToTypedWords`, D15 default on). Set from the shared
    /// settings at activation and on change, never read per key from the store.
    var addMarksEnabled = true

    /// What the cursor is known to follow while the engine has no word (D20 needs a word
    /// right before the cursor; reading costs two client calls, so it is skipped when
    /// the answer is already known).
    enum Before: Equatable {
        /// Anything: start of a session, after a reset (click, arrows, shortcuts,
        /// mismatch), after Backspace or Return/Tab left the word.
        case unknown
        /// Not a letter: the last key was a word-ending character typed here, or a D20
        /// read just found no word.
        case noWord
    }

    private(set) var tracker = CursorTracker()
    private(set) var before = Before.unknown
    /// The client gave no text (or no position) for a D20 read: do not ask again until
    /// the next activation (`activate`), N3.
    private(set) var readUnavailable = false
    /// Time of the previous key or click on this client (`NSEvent.timestamp`, seconds).
    private var lastEventTime: TimeInterval?

    /// UTF-16 units read before the cursor for D20: the longest word the engine tracks
    /// is 7 letters (D33), at most 13 scalars when decomposed (NFD: base + 2 marks on up
    /// to 3 vowels); one more shows whether the word goes on past the read.
    static let readLength = 16

    /// D20 reads only when the previous key or click on this client is at least this old.
    /// Apps that apply keys asynchronously (Chromium, Electron, terminals) answer
    /// `selectedRange`/`attributedSubstring` from a snapshot that can still miss the
    /// previous keys; a word read from such a snapshot could be replaced at the wrong
    /// place. M2 measured method A wrong below 10–20 ms between keys in Chrome, VS Code
    /// and Terminal. Trial 30/10/2026 with no wait (ARCHITECTURE.md): no damage in five
    /// apps even at 0 ms, VS Code at 0 ms read a stale snapshot (no word found). 50 ms
    /// keeps a margin over the 20 ms seen in M2; a person going back to a word is slower.
    static let settleInterval: TimeInterval = 0.05

    /// Positions of the last replacement attempt of a key (Debug diagnostics).
    struct Attempt: Equatable {
        var deleteCount: Int
        var selection: NSRange
        var expected: Int?
        var insertedLength: Int
        /// The `replacementRange` sent, or nil when nothing was sent.
        var replacement: NSRange?
    }

    struct Outcome: Equatable {
        /// Whether `handle` returns true (key consumed).
        var consumed = false
        var kind = PerfLog.Kind.pass
        var attempt: Attempt?
    }

    // MARK: - Session events

    /// Forget the word without restoring it (D4) and what precedes the cursor.
    mutating func reset(engine: inout VietEngine) {
        engine.reset()
        tracker.invalidate()
        before = .unknown
    }

    /// A click (or any non-key event that moves the cursor) at `time`.
    mutating func noteEvent(at time: TimeInterval?) {
        if let time { lastEventTime = time }
    }

    /// New activation: the client may give text again.
    mutating func activate() {
        readUnavailable = false
        lastEventTime = nil
    }

    // MARK: - Keys

    /// One key in in-place mode. `time` is the event's timestamp (nil if unknown: then
    /// D20 does not wait for anything).
    mutating func handle(_ route: KeyRoute, time: TimeInterval?, engine: inout VietEngine,
                         client: some InPlaceClient) -> Outcome {
        let settled = isSettled(at: time)
        if let time { lastEventTime = time }

        switch route {
        case .ignore:
            // D4: shortcuts, arrows, Esc only reset; nothing is restored.
            reset(engine: &engine)
            return Outcome(kind: .reset)

        case .backspace:
            let wasComposing = engine.isComposing
            var result = Outcome()
            switch engine.backspace() {
            case .passThrough:
                // The app deletes one character itself.
                if wasComposing && engine.isComposing {
                    tracker.backspacePassedThrough()
                } else {
                    tracker.invalidate()
                }
            case .replace(let deleteCount, let insert):
                result = replace(deleteCount: deleteCount, insert: insert, selection: nil, client: client)
                if result.kind != .replace {
                    // Let the app's own Delete run; the engine no longer knows the word.
                    reset(engine: &engine)
                    result.consumed = false
                }
            }
            if !engine.isComposing {
                tracker.invalidate()
                before = .unknown
            }
            return result

        case .endWord:
            // Return, Tab, keypad Enter: restore the word if needed (D4), then let the app
            // handle the key itself (send a message, move focus…).
            var result = Outcome()
            if case .replace(let deleteCount, let insert) = engine.endWord() {
                result = replace(deleteCount: deleteCount, insert: insert, selection: nil, client: client)
            }
            // What the app does with the key is unknown (Tab may focus another field).
            reset(engine: &engine)
            result.consumed = false
            return result

        case .character(let scalar):
            if !engine.isComposing, addMarksEnabled, before == .unknown, !readUnavailable, settled,
               Self.isMarkKey(scalar, method: engine.options.inputMethod) {
                return addMarks(scalar, engine: &engine, client: client)
            }
            return character(scalar, selection: nil, engine: &engine, client: client)
        }
    }

    private func isSettled(at time: TimeInterval?) -> Bool {
        guard let time, let last = lastEventTime else { return true }
        return time - last >= Self.settleInterval || time < last
    }

    /// Tone and transform keys of the typing method (D20 applies to both): Telex and
    /// Telex đơn giản s f r x j z a e o w d (any case, D34), VNI digits.
    static func isMarkKey(_ scalar: Unicode.Scalar, method: EngineOptions.InputMethod) -> Bool {
        let v = scalar.value
        switch method {
        case .vni:
            return v >= 0x30 && v <= 0x39
        case .telex, .simpleTelex:
            guard v < 0x80 else { return false }
            let lower = (v >= 0x41 && v <= 0x5A) ? v + 0x20 : v
            return "sfrxjzaeowd".unicodeScalars.contains { $0.value == lower }
        }
    }

    /// A character with the engine's word (if any).
    private mutating func character(_ scalar: Unicode.Scalar, selection: NSRange?,
                                    engine: inout VietEngine, client: some InPlaceClient) -> Outcome {
        var result: Outcome
        switch engine.handle(scalar) {
        case .passThrough:
            tracker.passedThrough(length: scalar.utf16.count)
            result = Outcome()
        case .replace(let deleteCount, let insert):
            result = replace(deleteCount: deleteCount, insert: insert, selection: selection, client: client)
            if result.kind == .mismatch || result.kind == .unsupported {
                // D11: the app's text is not what the engine thinks. Start over from
                // this key alone, so it still does the most it can on its own.
                reset(engine: &engine)
                switch engine.handle(scalar) {
                case .passThrough:
                    result.consumed = false
                case .replace(0, let insert):
                    insertAtCursor(insert, client: client)
                    result.consumed = true
                case .replace:
                    reset(engine: &engine)
                    result.consumed = false
                }
            }
        }
        if !engine.isComposing {
            tracker.invalidate()
            // The key ended a word (or was punctuation with no word): it is now right
            // before the cursor. After a failed replacement, nothing is known.
            before = (result.kind == .mismatch || result.kind == .unsupported) ? .unknown : .noWord
        }
        return result
    }

    // MARK: - D20 "Thêm dấu cho từ đã gõ"

    /// Reads the word right before the cursor, seeds the engine with it as displayed
    /// (`VietEngine.seed`), and lets the engine decide (D20): the key either changes the
    /// word in place (one `insertText`) or goes to the app unchanged. Reads nothing more
    /// than `readLength` UTF-16 units; any odd answer from the client means no seed and
    /// the key is handled as the first key of a new word (D18).
    private mutating func addMarks(_ scalar: Unicode.Scalar, engine: inout VietEngine,
                                   client: some InPlaceClient) -> Outcome {
        let selection = client.selectedRange()
        var outcome = seedWord(scalar, selection: selection, engine: &engine, client: client)
        if outcome == nil {
            // Not seeded: the key starts a word as usual (never asks selectedRange again:
            // with an empty engine a key never replaces text before the cursor).
            engine.reset()
            outcome = character(scalar, selection: selection, engine: &engine, client: client)
            // The read happened (perf log): pass or insert at the cursor, nothing seeded.
            if outcome?.kind == .pass || outcome?.kind == .insert { outcome?.kind = .seedNone }
        }
        return outcome ?? Outcome()
    }

    /// The seeded path, or nil when nothing could be seeded.
    private mutating func seedWord(_ scalar: Unicode.Scalar, selection: NSRange, engine: inout VietEngine,
                                   client: some InPlaceClient) -> Outcome? {
        if selection.location == NSNotFound || selection.length == NSNotFound {
            readUnavailable = true  // no document access: replacing could not work either
            return nil
        }
        guard selection.location >= 0, selection.length == 0 else { return nil }
        let location = selection.location
        if location == 0 {
            before = .noWord
            return nil
        }
        let count = min(location, Self.readLength)
        let range = NSRange(location: location - count, length: count)
        guard let text = client.text(in: range) else {
            readUnavailable = true
            return nil
        }
        // A different length means the range split a surrogate pair or the client
        // answered for another range (IMKInputSession.h): do not guess.
        guard text.utf16.count == count else { return nil }
        let word = Self.trailingWord(text)
        if word.isEmpty {
            before = .noWord
            return nil
        }
        // The word may go on before what was read: too long to be one the engine tracks.
        if word.count == text.unicodeScalars.count && location > count { return nil }
        // Every scalar the engine accepts is in the BMP, so its scalar counts are UTF-16
        // counts (deleteCount below); anything else is refused by `seed` anyway.
        guard word.allSatisfy({ $0.utf16.count == 1 }), engine.seed(displayed: word) else { return nil }

        switch engine.handle(scalar) {
        case .passThrough:
            // D20 does not apply ("viet" + j → "vietj"): the app types the key. The
            // engine keeps the word, so the next keys continue it (D4 baseline = seed).
            tracker.didReplace(NSRange(location: location, length: 0), insertedLength: scalar.utf16.count)
            return Outcome(consumed: false, kind: .seedPass)
        case .replace(let deleteCount, let insert):
            guard deleteCount <= word.count else {
                reset(engine: &engine)
                return Outcome(consumed: false, kind: .mismatch)
            }
            var result = replace(deleteCount: deleteCount, insert: insert, selection: selection, client: client)
            if result.kind == .replace {
                result.kind = .seed
            } else {
                reset(engine: &engine)
                result.consumed = false
            }
            if !engine.isComposing { tracker.invalidate() }
            return result
        }
    }

    /// The letters (with combining marks, digits) at the end of `text`.
    static func trailingWord(_ text: String) -> [Unicode.Scalar] {
        var word: [Unicode.Scalar] = []
        for scalar in text.unicodeScalars.reversed() {
            guard CharacterSet.alphanumerics.contains(scalar) else { break }
            word.append(scalar)
        }
        word.reverse()
        return word
    }

    // MARK: - Client calls

    /// Applies `.replace` with exactly one `insertText` call (N3). Method A: ask the
    /// client for `selectedRange` when text before the cursor must be replaced, unless
    /// this key already asked (`selection`).
    private mutating func replace(deleteCount: Int, insert: TextBuffer, selection known: NSRange?,
                                  client: some InPlaceClient) -> Outcome {
        var result = Outcome(consumed: true)
        if deleteCount == 0 {
            result.kind = .insert
            insertAtCursor(insert, client: client)
            return result
        }
        // Engine letters are BMP scalars, so deleteCount scalars == deleteCount UTF-16
        // units, also for a word seeded from decomposed (NFD) text (D20).
        let selection = known ?? client.selectedRange()
        let text = insert.description
        var attempt = Attempt(deleteCount: deleteCount, selection: selection, expected: tracker.expected,
                              insertedLength: text.utf16.count)
        switch tracker.plan(selection: selection, deleteCount: deleteCount) {
        case .replace(let range):
            attempt.replacement = range
            client.insertText(text, replacementRange: range)
            tracker.didReplace(range, insertedLength: text.utf16.count)
            result.kind = .replace
        case .unsupported:
            result.kind = .unsupported
            result.consumed = false
        case .mismatch:
            result.kind = .mismatch
            result.consumed = false
        }
        result.attempt = attempt
        return result
    }

    /// Inserts at the current selection without asking where it is (deleteCount 0).
    private mutating func insertAtCursor(_ insert: TextBuffer, client: some InPlaceClient) {
        let text = insert.description
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        tracker.didInsertAtCursor(length: text.utf16.count)
    }
}
