import Foundation
import DauEngine
import DauShared
import Testing

/// A text field that supports marked text, like an app seen through `IMKTextInput`.
/// Records every call so the tests can check N3 (one call per key, never a position).
private final class FakeApp: MarkedTextClient {
    enum Call: Equatable {
        case setMarked(String)
        case insert(String)
    }

    /// Committed text of the document (the cursor is at its end).
    var document = ""
    /// Marked text shown after `document` (empty: none).
    var marked = ""
    var calls: [Call] = []
    /// Every replacementRange received was NSNotFound (no absolute position used).
    var onlyNotFound = true

    var shown: String { document + marked }

    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange) {
        calls.append(.setMarked(text))
        if replacementRange.location != NSNotFound { onlyNotFound = false }
        if selectionRange != NSRange(location: text.utf16.count, length: 0) { onlyNotFound = false }
        marked = text
    }

    func insertText(_ text: String, replacementRange: NSRange) {
        calls.append(.insert(text))
        if replacementRange.location != NSNotFound { onlyNotFound = false }
        marked = ""
        document += text
    }

    /// What the app does with a key the input method did not consume.
    func defaultAction(_ route: KeyRoute) {
        switch route {
        case .character(let c): document.unicodeScalars.append(c)
        case .backspace: if !document.isEmpty { document.removeLast() }
        case .endWord: document += "⏎"
        case .ignore: break
        }
    }
}

/// Underline mode end to end: keys → composer → fake app.
private struct Session {
    var engine = VietEngine(options: DauSettings.defaults.engineOptions)
    var composer = MarkedComposer()
    let app = FakeApp()
    /// Keys that made more than one client call (must stay empty, N3).
    var overCalls = 0
    /// Keys the app received while marked text was still shown (must stay 0).
    var passedWithMarked = 0

    mutating func key(_ route: KeyRoute) {
        let before = app.calls.count
        let outcome = composer.handle(route, engine: &engine, client: app)
        let made = app.calls.count - before
        if made > 1 { overCalls += 1 }
        #expect(made == (outcome.call == .none ? 0 : 1))
        if !outcome.consumed {
            if !app.marked.isEmpty { passedWithMarked += 1 }
            app.defaultAction(route)
        }
    }

    mutating func type(_ keys: String) {
        for c in keys.unicodeScalars { key(.character(c)) }
    }
}

@Suite("MarkedComposer (underline mode, D13)")
struct MarkedComposerTests {
    @Test("letters are marked, Space commits the word with the key")
    func word() {
        var s = Session()
        s.type("tooi")
        #expect(s.app.document == "")
        #expect(s.app.marked == "tôi")
        #expect(s.app.calls == [.setMarked("t"), .setMarked("to"), .setMarked("tô"), .setMarked("tôi")])
        s.type(" ")
        #expect(s.app.document == "tôi ")
        #expect(s.app.marked == "")
        #expect(s.app.calls.last == .insert("tôi "))
        #expect(s.app.onlyNotFound)
        #expect(s.overCalls == 0)
    }

    @Test("the sample sentence: restore (D4), doubled key (D26), punctuation")
    func sample() {
        var s = Session()
        s.type("windows carr tooi yeeu tieengs Vieetj, Hasaki ")
        #expect(s.app.document == "windows car tôi yêu tiếng Việt, Hasaki ")
        #expect(s.app.marked == "")
        #expect(s.app.onlyNotFound)
        #expect(s.overCalls == 0)
        #expect(s.passedWithMarked == 0)
    }

    @Test("D4: every printable word end restores the same way")
    func punctuation() {
        var s = Session()
        s.type("Hasaki! (windows) as")
        #expect(s.app.document == "Hasaki! (windows) ")
        #expect(s.app.marked == "á")
        s.type("?")
        #expect(s.app.document == "Hasaki! (windows) á?")
    }

    @Test("punctuation or Space with no word goes to the app, no call")
    func noWord() {
        var s = Session()
        s.type(" ,.")
        #expect(s.app.document == " ,.")
        #expect(s.app.calls.isEmpty)
    }

    @Test("D32: Backspace edits the marked word; the last letter clears the marked text")
    func backspace() {
        var s = Session()
        s.type("hoaf")
        #expect(s.app.marked == "hoà")
        s.key(.backspace)
        #expect(s.app.marked == "hò")
        s.key(.backspace)
        s.key(.backspace)
        #expect(s.app.marked == "")
        #expect(s.app.calls.last == .setMarked(""))
        #expect(s.app.document == "")
        // Nothing marked: the app deletes committed text itself, no call.
        s.type("a ")
        let calls = s.app.calls.count
        s.key(.backspace)
        #expect(s.app.document == "a")
        #expect(s.app.calls.count == calls)
    }

    @Test("D26 lock holds after Backspace in the marked word")
    func doubledThenBackspace() {
        var s = Session()
        s.type("tesst")
        #expect(s.app.marked == "test")
        s.key(.backspace)
        s.type("s ")
        #expect(s.app.document == "tess ")
    }

    @Test("reset keys commit what is shown, unrestored (D4), then go to the app")
    func resetKeys() {
        var s = Session()
        s.type("hocf")
        #expect(s.app.marked == "hòc")
        s.key(.ignore) // arrow, Esc, ⌘ combo
        #expect(s.app.document == "hòc")
        #expect(s.app.marked == "")
        #expect(!s.engine.isComposing)
        // The next key starts a new word.
        s.type("a")
        #expect(s.app.marked == "a")
        #expect(s.passedWithMarked == 0)
    }

    @Test("Return, Tab: restore if needed, commit, the app gets the key")
    func endWord() {
        var s = Session()
        s.type("windows")
        s.key(.endWord)
        #expect(s.app.document == "windows⏎")
        s.type("vieetj")
        s.key(.endWord)
        #expect(s.app.document == "windows⏎việt⏎")
        s.key(.endWord)
        #expect(s.app.document == "windows⏎việt⏎⏎")
        #expect(s.passedWithMarked == 0)
    }

    @Test("reset events (click, deactivate, client/source/settings change) commit; empty does nothing")
    func commitEvent() {
        var s = Session()
        #expect(s.composer.commit(engine: &s.engine, client: s.app) == .none)
        #expect(s.app.calls.isEmpty)
        s.type("vieet")
        #expect(s.composer.commit(engine: &s.engine, client: s.app) == .insertText)
        #expect(s.app.document == "viêt")
        #expect(!s.composer.isComposing)
        #expect(!s.engine.isComposing)
        // abandon is for "no client left": no call, state cleared.
        s.type("ab")
        s.composer.abandon(engine: &s.engine)
        #expect(!s.composer.isComposing)
        #expect(!s.engine.isComposing)
    }

    @Test("D33 and very long runs: never lost, marked text stays bounded")
    func longRun() {
        var s = Session()
        let run = String(repeating: "abcdefghijklmnopqrstuvwxyz", count: 3)
        s.type(run)
        #expect(s.app.marked.unicodeScalars.count <= MarkedComposer.maxMarkedLength)
        s.type(" ")
        #expect(s.app.document == run + " ")
        #expect(s.app.marked == "")
        s.type("nghieengx ")
        #expect(s.app.document == run + " nghiễng ")
        #expect(s.overCalls == 0)
        #expect(s.passedWithMarked == 0)
    }

    @Test("same text as in-place replacement for random key sequences (D18: no crash)")
    func matchesInPlace() {
        let alphabet: [KeyRoute] = Array("aeiouydwsfrxjzcnghtqkpblmAEO0123456789".unicodeScalars).map { .character($0) }
            + Array(" ,.!?()\"'-".unicodeScalars).map { .character($0) }
            + [.backspace, .backspace, .backspace, .endWord, .ignore]
        var rng = SplitMix(seed: 0xDA0)
        for options in [DauSettings.defaults.engineOptions,
                        EngineOptions(inputMethod: .vni),
                        EngineOptions(inputMethod: .simpleTelex, freeMarking: false, autoRestore: false),
                        EngineOptions(advanced: .consonantShortcuts)] {
            for _ in 0..<300 {
                var s = Session(engine: VietEngine(options: options))
                var reference = VietEngine(options: options)
                var screen: [Unicode.Scalar] = []
                for _ in 0..<Int(rng.next() % 60) {
                    let route = alphabet[Int(rng.next() % UInt64(alphabet.count))]
                    s.key(route)
                    inPlace(route, engine: &reference, screen: &screen)
                }
                _ = s.composer.commit(engine: &s.engine, client: s.app)
                #expect(s.app.document == MarkedComposer.string(screen))
                #expect(s.overCalls == 0)
                #expect(s.passedWithMarked == 0)
                #expect(s.app.onlyNotFound)
            }
        }
    }

    /// The in-place controller's effect on the document, for comparison.
    private func inPlace(_ route: KeyRoute, engine: inout VietEngine, screen: inout [Unicode.Scalar]) {
        func apply(_ action: Action, passed: () -> Void) {
            switch action {
            case .passThrough: passed()
            case .replace(let d, let insert):
                screen.removeLast(min(d, screen.count))
                screen.append(contentsOf: insert)
            }
        }
        switch route {
        case .character(let c):
            apply(engine.handle(c)) { screen.append(c) }
        case .backspace:
            apply(engine.backspace()) { if !screen.isEmpty { screen.removeLast() } }
        case .endWord:
            apply(engine.endWord()) {}
            engine.reset()
            screen.append("⏎")
        case .ignore:
            engine.reset()
        }
    }

    @Test("underline is on for a rule with underline, or a Debug-forced bundle ID")
    func underlineMode() {
        var settings = DauSettings.defaults
        settings.upsert(AppRule(bundleID: "com.google.Chrome", underline: true))
        settings.upsert(AppRule(bundleID: "com.apple.Safari", underline: false))
        #expect(UnderlineMode.isOn(settings: settings, bundleID: "com.google.Chrome", debugForced: []))
        #expect(!UnderlineMode.isOn(settings: settings, bundleID: "com.apple.Safari", debugForced: []))
        #expect(!UnderlineMode.isOn(settings: settings, bundleID: "com.apple.TextEdit", debugForced: []))
        #expect(UnderlineMode.isOn(settings: settings, bundleID: "com.apple.TextEdit", debugForced: ["com.apple.TextEdit"]))
        #expect(!UnderlineMode.isOn(settings: settings, bundleID: "?", debugForced: ["?"]))
        #expect(!UnderlineMode.isOn(settings: settings, bundleID: "", debugForced: [""]))
    }
}

/// Deterministic generator for the random sequences.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
