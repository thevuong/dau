import Foundation
import DauEngine
import DauShared

/// The two client calls underline mode makes. `IMKTextInput` in the input method, a
/// recording fake in the unit tests.
protocol MarkedTextClient {
    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange)
    func insertText(_ text: String, replacementRange: NSRange)
}

/// Underline mode (D13): the word being typed is shown as marked text (the app draws it
/// underlined) and only committed when it ends, instead of being replaced in place.
///
/// Every call targets the client's own marked range or its selection
/// (`replacementRange` = NSNotFound), so no absolute position is needed and
/// `selectedRange` is never asked (N3). That is the point for apps that apply keys
/// asynchronously (Chrome, VS Code, Terminal): a snapshot of the cursor taken while
/// earlier keys are still in flight cannot send a replacement to the wrong place.
///
/// Calls per key (at most one, N3):
/// - letter or digit inside a word, Backspace inside a word: one `setMarkedText`;
/// - word-ending character after a word: one `insertText` (the word, restored if D4 says
///   so, plus the character), key consumed;
/// - Return, Tab, keypad Enter after a word: one `insertText` (the word), then the key
///   goes to the app (a chat app still sends on Return);
/// - reset keys (arrows, Esc, ⌘/⌃/⌥ combos) and reset events (click, deactivate, source,
///   client or settings change, `commitComposition`) with a word: one `insertText` of
///   what is shown, never dropped; the key then goes to the app;
/// - any key with no word: no call, the key goes to the app.
///
/// `text` mirrors what the engine believes is on screen for the word (its `screen`), so
/// every engine `Action` applies to it exactly as it would to the document in place
/// mode. Pure value type, no IMK, unit tested in DauInputMethodTests.
struct MarkedComposer {
    /// The marked text shown in the app (empty: none).
    private(set) var text: [Unicode.Scalar] = []
    /// The word grew past `maxMarkedLength` (only possible after D33 made the rest of the
    /// word pass through): its start was committed and the rest of the word goes to the
    /// app as plain keys until the engine ends the word.
    private(set) var detached = false

    /// Longer than any Vietnamese word the engine tracks (7 letters, D33) plus the keys
    /// of an overflowing word: keeps a pasted-like run of letters (a URL, a hash) from
    /// growing the marked text without bound.
    static let maxMarkedLength = TextBuffer.capacity

    static let notFound = NSRange(location: NSNotFound, length: NSNotFound)

    enum Call: Equatable {
        case none
        case setMarkedText
        case insertText
    }

    struct Outcome: Equatable {
        /// Whether `handle` returns true (key consumed).
        var consumed: Bool
        /// The client call made for this key, at most one (N3).
        var call: Call
    }

    var isComposing: Bool { !text.isEmpty }

    /// One key in underline mode.
    mutating func handle(_ route: KeyRoute, engine: inout VietEngine, client: some MarkedTextClient) -> Outcome {
        switch route {
        case .ignore:
            // D4: arrows, Esc, shortcuts end the word without restoring it; what is shown
            // is committed as is, then the app gets the key.
            let call = commit(engine: &engine, client: client)
            return Outcome(consumed: false, call: call)

        case .endWord:
            // Return, Tab, keypad Enter: restore if needed (D4), commit, let the app have
            // the key.
            let action = engine.endWord()
            if !detached, !text.isEmpty, case .replace(let deleteCount, let insert) = action {
                // If this failed (the engine only edits its own word, so it should not),
                // what is shown is committed unchanged rather than guessed at.
                _ = apply(deleteCount: deleteCount, insert: insert)
            }
            let call = commit(engine: &engine, client: client)
            return Outcome(consumed: false, call: call)

        case .backspace:
            return backspace(engine: &engine, client: client)

        case .character(let scalar):
            return character(scalar, engine: &engine, client: client)
        }
    }

    /// Commits what is shown (if anything) and resets the engine: every reset event in
    /// underline mode. Returns the call made (`insertText` or none).
    @discardableResult
    mutating func commit(engine: inout VietEngine, client: some MarkedTextClient) -> Call {
        engine.reset()
        detached = false
        guard !text.isEmpty else { return .none }
        let string = Self.string(text)
        text.removeAll()
        client.insertText(string, replacementRange: Self.notFound)
        return .insertText
    }

    /// Forgets the marked text without any client call: only when there is no client
    /// left to commit to (D18). The app keeps or drops its marked text itself.
    mutating func abandon(engine: inout VietEngine) {
        engine.reset()
        text.removeAll()
        detached = false
    }

    // MARK: - Keys

    private mutating func character(_ scalar: Unicode.Scalar, engine: inout VietEngine,
                                    client: some MarkedTextClient) -> Outcome {
        if detached {
            // D33: the rest of an over-long word passes through until the word ends.
            let action = engine.handle(scalar)
            if !engine.isComposing { detached = false }
            if case .replace = action {
                // The engine never replaces in overflow; if it ever did, the text it
                // would edit was committed already: start over and let the key through.
                engine.reset()
                detached = false
            }
            return Outcome(consumed: false, call: .none)
        }

        let action = engine.handle(scalar)
        switch action {
        case .passThrough:
            if engine.isComposing {
                text.append(scalar)
            } else if text.isEmpty {
                // Not in a word (punctuation, space between words): the app types it.
                return Outcome(consumed: false, call: .none)
            } else {
                // The word ended with nothing to restore: commit it with the key, one call.
                text.append(scalar)
            }
        case .replace(let deleteCount, let insert):
            if !apply(deleteCount: deleteCount, insert: insert) {
                // The engine wants to edit text that is not marked (cannot happen while
                // `text` mirrors the engine's screen). Keep what is shown, let the key
                // go to the app as typed.
                let call = commit(engine: &engine, client: client)
                return Outcome(consumed: false, call: call)
            }
        }

        if !engine.isComposing {
            // Word ended (D4 boundary, restored if needed): the key is part of `text`.
            detached = false
            let string = Self.string(text)
            text.removeAll()
            client.insertText(string, replacementRange: Self.notFound)
            return Outcome(consumed: true, call: .insertText)
        }
        if text.count > Self.maxMarkedLength {
            // Commit the long run now; the rest of the word passes through (D33).
            let string = Self.string(text)
            text.removeAll()
            detached = true
            client.insertText(string, replacementRange: Self.notFound)
            return Outcome(consumed: true, call: .insertText)
        }
        showMarked(client)
        return Outcome(consumed: true, call: .setMarkedText)
    }

    private mutating func backspace(engine: inout VietEngine, client: some MarkedTextClient) -> Outcome {
        if detached || text.isEmpty {
            // Nothing marked: the app deletes a character of committed text itself.
            // The engine never replaces here (overflow or no word); if it did, its word
            // is no longer on screen as it thinks: forget it.
            if case .replace = engine.backspace() { engine.reset() }
            if !engine.isComposing { detached = false }
            return Outcome(consumed: false, call: .none)
        }
        switch engine.backspace() {
        case .passThrough:
            // The app's own Delete would remove the last letter shown; here it is marked,
            // so remove it from the marked text (D32).
            text.removeLast()
        case .replace(let deleteCount, let insert):
            if !apply(deleteCount: deleteCount, insert: insert) {
                text.removeLast()
                engine.reset()
            }
        }
        if !engine.isComposing && !text.isEmpty {
            // The engine dropped the word but letters are still shown: keep them.
            let string = Self.string(text)
            text.removeAll()
            client.insertText(string, replacementRange: Self.notFound)
            return Outcome(consumed: true, call: .insertText)
        }
        // Empty text clears the marked text: the word is gone.
        showMarked(client)
        return Outcome(consumed: true, call: .setMarkedText)
    }

    // MARK: - Helpers

    /// Applies an engine replacement to the marked text. False if it would delete more
    /// than is marked (text left unchanged).
    private mutating func apply(deleteCount: Int, insert: TextBuffer) -> Bool {
        guard deleteCount >= 0, deleteCount <= text.count else { return false }
        text.removeLast(deleteCount)
        text.append(contentsOf: insert)
        return true
    }

    private func showMarked(_ client: some MarkedTextClient) {
        let string = Self.string(text)
        client.setMarkedText(string,
                             selectionRange: NSRange(location: string.utf16.count, length: 0),
                             replacementRange: Self.notFound)
    }

    static func string(_ scalars: [Unicode.Scalar]) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }
}

/// Whether underline mode is on for a client app (D5, D13): the app's rule asks for it,
/// or (Debug builds only) the app is in the trial override list.
enum UnderlineMode {
    /// Debug builds only: defaults key holding an array of bundle IDs forced into
    /// underline mode for trials, without touching the user's settings. It lives in the
    /// global domain (`defaults write -g`): the input method's own sandbox container and
    /// the App Group container cannot be written from a shell (macOS app data
    /// protection), but a sandboxed process can read the global domain. Never written by
    /// Dấu, never read by Release builds. See scripts/selftest-typing/run.sh `--underline`.
    static let debugForceKey = "DauDebugForceUnderline"

    static func isOn(settings: DauSettings, bundleID: String, debugForced: [String]) -> Bool {
        guard !bundleID.isEmpty, bundleID != "?" else { return false }
        if debugForced.contains(bundleID) { return true }
        return settings.rule(for: bundleID)?.underline ?? false
    }
}
