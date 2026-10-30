import Foundation
import DauEngine
import DauShared
import Testing

/// A text document seen through `IMKTextInput` with document access (TSMDocumentAccess),
/// cursor at the end unless moved. Records every call so the tests can check N3.
///
/// `lag` models an app that applies keys asynchronously (WebKit, Chromium, terminals):
/// for `lag` seconds after any edit, `selectedRange` and `text(in:)` still answer from
/// the document as it was before that edit. `staleText` makes only the text lag (the
/// selection is fresh), the case M2 saw in Safari.
private final class FakeDocument: InPlaceClient {
    enum Call: Equatable {
        case selectedRange
        case read(NSRange)
        case insert(String, NSRange?)
    }

    var text = ""
    var cursor: Int
    var calls: [Call] = []
    /// Answer `text(in:)` with nil (no document access for text).
    var noText = false
    /// Answer `selectedRange` with NSNotFound (no document access at all).
    var noAccess = false
    /// Answer `text(in:)` with this instead (odd client, D18).
    var oddText: String?
    /// Length of the selection ending at the cursor that `selectedRange` reports.
    var selectionLength = 0

    var lag: TimeInterval = 0
    var staleText = false
    private var lastEdit: TimeInterval = -.infinity
    private var previous: (text: String, cursor: Int) = ("", 0)
    /// Current time of the scripted session.
    var now: TimeInterval = 0

    init(_ text: String = "") {
        self.text = text
        cursor = text.utf16.count
    }

    private var stale: Bool { now - lastEdit < lag }

    private func edit(_ body: () -> Void) {
        if !stale { previous = (text, cursor) }
        body()
        lastEdit = now
    }

    func selectedRange() -> NSRange {
        calls.append(.selectedRange)
        if noAccess { return NSRange(location: NSNotFound, length: NSNotFound) }
        let end = stale && !staleText ? previous.cursor : cursor
        return NSRange(location: end - selectionLength, length: selectionLength)
    }

    func text(in range: NSRange) -> String? {
        calls.append(.read(range))
        if noText { return nil }
        if let oddText { return oddText }
        let source = stale ? previous.text : text
        let utf16 = Array(source.utf16)
        guard range.location >= 0, range.location + range.length <= utf16.count else { return nil }
        return String(decoding: utf16[range.location..<(range.location + range.length)], as: UTF16.self)
    }

    func insertText(_ string: String, replacementRange: NSRange) {
        let range: NSRange
        if replacementRange.location == NSNotFound {
            range = NSRange(location: cursor, length: 0)
            calls.append(.insert(string, nil))
        } else {
            range = replacementRange
            calls.append(.insert(string, replacementRange))
        }
        edit {
            let ns = NSMutableString(string: text)
            ns.replaceCharacters(in: range, with: string)
            text = ns as String
            cursor = range.location + string.utf16.count
        }
    }

    /// What the app does with a key the input method did not consume.
    func defaultAction(_ route: KeyRoute) {
        switch route {
        case .character(let c):
            insertText(String(Character(c)), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            calls.removeLast()
        case .backspace:
            guard cursor > 0 else { return }
            edit {
                let ns = NSMutableString(string: text)
                ns.deleteCharacters(in: NSRange(location: cursor - 1, length: 1))
                text = ns as String
                cursor -= 1
            }
        case .endWord:
            insertText("\n", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            calls.removeLast()
        case .ignore:
            break
        }
    }
}

/// In-place mode end to end: keys → composer → fake document.
private struct Session {
    var engine: VietEngine
    var composer = InPlaceComposer()
    let doc: FakeDocument
    var kinds: [PerfLog.Kind] = []
    /// Keys that made more than one `insertText` or `selectedRange`, or more than one read
    /// (must stay 0, N3).
    var overCalls = 0
    /// Seconds between keys.
    var interval: TimeInterval = 0.2

    init(_ text: String = "", settings: DauSettings = .defaults) {
        engine = VietEngine(options: settings.engineOptions)
        composer.addMarksEnabled = settings.addMarksToTypedWords
        doc = FakeDocument(text)
    }

    mutating func key(_ route: KeyRoute) {
        doc.now += interval
        let before = doc.calls.count
        let outcome = composer.handle(route, time: doc.now, engine: &engine, client: doc)
        let made = doc.calls[before...]
        let inserts = made.filter { if case .insert = $0 { true } else { false } }.count
        let selections = made.filter { $0 == .selectedRange }.count
        let reads = made.filter { if case .read = $0 { true } else { false } }.count
        if inserts > 1 || selections > 1 || reads > 1 { overCalls += 1 }
        kinds.append(outcome.kind)
        if !outcome.consumed { doc.defaultAction(route) }
    }

    /// `⌫` Backspace, `←` an arrow (reset), `⏎` Return; anything else is a character.
    mutating func type(_ keys: String) {
        for c in keys.unicodeScalars {
            switch c {
            case "⌫": key(.backspace)
            case "←": key(.ignore)
            case "⏎": key(.endWord)
            default: key(.character(c))
            }
        }
    }

    /// Text already in the app before the session (the engine knows nothing about it).
    var reads: Int { doc.calls.filter { if case .read = $0 { true } else { false } }.count }
}

@Suite("InPlaceComposer (method A, D20)")
struct InPlaceComposerTests {
    // MARK: Method A, unchanged behaviour

    @Test("the sample sentence, one insertText and at most one selectedRange per key")
    func sample() {
        var s = Session()
        s.type("windows carr tooi yeeu tieengs Vieetj, Hasaki ")
        #expect(s.doc.text == "windows car tôi yêu tiếng Việt, Hasaki ")
        #expect(s.overCalls == 0)
        // Words start after a Space typed here: no D20 read at all.
        #expect(s.reads == 0)
    }

    @Test("an app that moves the text under the word is caught (D11 mismatch)")
    func mismatch() {
        var s = Session()
        s.type("tooi")
        #expect(s.doc.text == "tôi")
        // The app inserts text before the word behind the input method's back.
        s.doc.text = "xx" + s.doc.text
        s.doc.cursor += 2
        s.type("s")
        #expect(s.kinds.last == .mismatch)
        // Nothing replaced at the old position; the key goes in as typed.
        #expect(s.doc.text == "xxtôis")
        #expect(s.overCalls == 0)
    }

    // MARK: D20 examples (DECISIONS.md)

    @Test("D20: viet + j → vietj (not a valid syllable: the key goes straight)")
    func vietJ() {
        var s = Session("viet")
        s.type("j")
        #expect(s.doc.text == "vietj")
        #expect(s.kinds == [.seedPass])
        #expect(s.doc.calls == [.selectedRange, .read(NSRange(location: 0, length: 4))])
    }

    @Test("D20: viet + e + j → việt")
    func vietEJ() {
        var s = Session("viet")
        s.type("ej")
        #expect(s.doc.text == "việt")
        #expect(s.kinds == [.seed, .replace])
        #expect(s.overCalls == 0)
        // Only the first key reads; the second is a normal in-word replacement.
        #expect(s.reads == 1)
    }

    @Test("D20 + D26: cả + r → car; the word then restores and locks as typed")
    func doubleUndo() {
        var s = Session("cả")
        s.type("r")
        #expect(s.doc.text == "car")
        s.type("s ")
        #expect(s.doc.text == "cars ")
    }

    @Test("D20 + D30/D31: hoc + f → hòc, the word end restores hocf")
    func hocF() {
        var s = Session("hoc")
        s.type("f")
        #expect(s.doc.text == "hòc")
        s.type(" ")
        #expect(s.doc.text == "hocf ")
    }

    @Test("D20: K7 in the compatibility matrix — hoc, Space, ⌫, j → học")
    func k7() {
        var s = Session()
        s.type("hoc ⌫j")
        #expect(s.doc.text == "học")
        #expect(s.kinds.last == .seed)
        s.type(" ")
        #expect(s.doc.text == "học ")
        #expect(s.overCalls == 0)
    }

    @Test("D20: the word is read only up to the cursor, with text before it")
    func wordAfterText() {
        var s = Session("xin chao")
        s.type("f")
        #expect(s.doc.text == "xin chào")
        #expect(s.doc.calls.contains(.read(NSRange(location: 0, length: 8))))
    }

    @Test("D20: VNI digits are mark keys (D36)")
    func vni() {
        var settings = DauSettings.defaults
        settings.typingMethod = .vni
        var s = Session("Viet", settings: settings)
        s.type("65")
        #expect(s.doc.text == "Việt")
    }

    @Test("D20: decomposed (NFD) text is replaced over its decomposed length")
    func decomposed() {
        var s = Session("vie\u{0302}t")
        s.type("j")
        #expect(s.doc.text.unicodeScalars.map(\.value) == "việt".unicodeScalars.map(\.value))
    }

    // MARK: D20, when not to read (N3)

    @Test("D20 off: no read, the key starts a new word")
    func off() {
        var settings = DauSettings.defaults
        settings.addMarksToTypedWords = false
        var s = Session("hoc", settings: settings)
        s.type("j")
        #expect(s.doc.text == "hocj")
        #expect(s.doc.calls.isEmpty)
    }

    @Test("D15: on by default")
    func defaultOn() {
        #expect(DauSettings.defaults.addMarksToTypedWords)
        #expect(InPlaceComposer().addMarksEnabled)
    }

    @Test("no read for letters that are not mark keys, nor inside a word")
    func onlyMarkKeys() {
        var s = Session("ho")
        s.type("c")      // not a Telex mark key: plain start of a word
        #expect(s.doc.calls.isEmpty)
        s.type("j")      // inside the word "c" (engine tracks it): normal key
        #expect(s.reads == 0)
    }

    @Test("no read after a word-ending key typed here; read again after a reset")
    func knownBoundary() {
        var s = Session()
        s.type("hoc ")
        s.type("a")      // after Space typed here: known, no read
        #expect(s.reads == 0)
        s.type("←")
        s.type("f")      // after an arrow: unknown, read "hoca" → seeded
        #expect(s.reads == 1)
        #expect(s.doc.text == "hoc à")
    }

    @Test("a read that finds no word is not repeated for the next key")
    func noWordFound() {
        var s = Session("xin, ")
        s.type("a")
        #expect(s.kinds == [.seedNone])
        #expect(s.reads == 1)
        s.type("s")
        #expect(s.doc.text == "xin, á")
        #expect(s.reads == 1)
    }

    @Test("start of the document: one selectedRange, no read")
    func startOfDocument() {
        var s = Session()
        s.type("a")
        #expect(s.doc.calls == [.selectedRange])
        #expect(s.kinds == [.seedNone])
    }

    @Test("a word longer than the read (8+ letters) is not seeded")
    func longWord() {
        var s = Session("abcdefghijklmnopqrstu")
        s.type("s")
        #expect(s.doc.text == "abcdefghijklmnopqrstus")
        #expect(s.kinds == [.seedNone])
    }

    @Test("a selection: no read, the key replaces it as the app does")
    func selection() {
        var s = Session("hoc")
        s.doc.selectionLength = 3
        s.type("j")
        #expect(s.doc.calls == [.selectedRange])
        #expect(s.kinds == [.seedNone])
    }

    // MARK: D18, odd clients

    @Test("D18: no document access → no read, and no read again until activation")
    func noAccess() {
        var s = Session("hoc")
        s.doc.noAccess = true
        s.type("j")
        #expect(s.doc.text == "hocj")
        #expect(s.doc.calls == [.selectedRange])
        s.type("←s")
        #expect(s.doc.calls == [.selectedRange])
        s.composer.activate()
        s.type("←s")
        #expect(s.doc.calls.count == 2)
    }

    @Test("D18: nil text → no seed, key passes; no read again until activation")
    func nilText() {
        var s = Session("hoc")
        s.doc.noText = true
        s.type("j")
        #expect(s.doc.text == "hocj")
        s.type("←s")
        #expect(s.reads == 1)
    }

    @Test("D18: text of the wrong length, or not letters, is not seeded")
    func oddText() {
        var s = Session("hoc")
        s.doc.oddText = "ho"
        s.type("j")
        #expect(s.doc.text == "hocj")
        var t = Session("hoc")
        t.doc.oddText = "h\u{1F600}"   // a surrogate pair: 3 UTF-16 units, not letters
        t.type("j")
        #expect(t.doc.text == "hocj")
    }

    // MARK: Asynchronous apps: stale snapshot

    @Test("stale snapshot (keys faster than the app): no read, no damage")
    func staleFast() {
        var s = Session()
        s.doc.lag = 0.05
        s.interval = 0.01
        s.type("hoc ⌫j")
        // Keys 10 ms apart: D20 waits for the app to settle, so the key goes straight.
        #expect(s.doc.text == "hocj")
        #expect(s.reads == 0)
    }

    @Test("stale text with a fresh selection (Safari in M2): no damage when keys are fast")
    func staleTextFast() {
        // "tôi" was produced by a replacement just before: the text read would still be
        // "to" while the cursor is already after "tôi".
        var s = Session()
        s.doc.lag = 0.05
        s.doc.staleText = true
        s.interval = 0.02
        s.type("tooi ⌫s")
        #expect(s.doc.text == "tôis")
        #expect(s.reads == 0)
    }

    @Test("same keys once the app has settled: D20 applies")
    func settled() {
        var s = Session()
        s.doc.lag = 0.05
        s.doc.staleText = true
        s.interval = 0.1
        s.type("tooi ⌫s")
        #expect(s.doc.text == "tối")
        #expect(s.reads == 1)
    }

    @Test("settle interval: above the 10–20 ms lag of asynchronous apps (M2), below a person going back to a word")
    func settleInterval() {
        #expect(InPlaceComposer.settleInterval >= 0.05)
        #expect(InPlaceComposer.settleInterval <= 0.15)
    }

    // MARK: Mark keys

    @Test("mark keys per typing method")
    func markKeys() {
        for c in "sfrxjzaeowdSFRXJZAEOWD".unicodeScalars {
            #expect(InPlaceComposer.isMarkKey(c, method: .telex))
            #expect(InPlaceComposer.isMarkKey(c, method: .simpleTelex))
            #expect(!InPlaceComposer.isMarkKey(c, method: .vni))
        }
        for c in "bcghklmnpqtuvy1".unicodeScalars {
            #expect(!InPlaceComposer.isMarkKey(c, method: .telex))
        }
        for c in "0123456789".unicodeScalars {
            #expect(InPlaceComposer.isMarkKey(c, method: .vni))
        }
        #expect(!InPlaceComposer.isMarkKey("ă", method: .telex))
    }

    @Test("trailing word: letters, combining marks and digits before the cursor")
    func trailingWord() {
        #expect(InPlaceComposer.trailingWord("xin chào") == Array("chào".unicodeScalars))
        #expect(InPlaceComposer.trailingWord("a, ") == [])
        #expect(InPlaceComposer.trailingWord("vie\u{0302}t") == Array("vie\u{0302}t".unicodeScalars))
        #expect(InPlaceComposer.trailingWord("") == [])
    }
}
