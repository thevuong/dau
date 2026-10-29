import Foundation

/// Method A of the open question A/B (DECISIONS.md): ask the client for `selectedRange`
/// on every key whose result replaces text, and compute the absolute replacement range
/// from it. On top of that, remember where the cursor should be after each key of the
/// current word, so a cursor that moved without the input method noticing (a click IMK
/// did not report, an app that edited the text) is caught before anything is replaced
/// (D11: "selectedRange khác vị trí dự đoán").
///
/// Ranges are UTF-16 offsets from the start of the client's document (NSRange).
/// Pure value type, no IMK calls, unit tested in DauInputMethodTests.
struct CursorTracker: Equatable {
    /// Where the cursor should be now, if known. Only kept inside one word: across a word
    /// boundary apps may legitimately edit text (autocorrect, smart quotes), so a mismatch
    /// there would throw away good state.
    private(set) var expected: Int?

    enum Plan: Equatable {
        /// Replace this range (deleteCount UTF-16 units before the cursor).
        case replace(NSRange)
        /// The client does not support document access (selectedRange is NSNotFound):
        /// `replacementRange` would be ignored, so in-place replacement cannot work.
        case unsupported
        /// The cursor is not where this word left it, there is a selection, or there is
        /// not enough text before the cursor. The engine state no longer matches the app.
        case mismatch
    }

    /// Decides the replacement range for `deleteCount` UTF-16 units before the cursor,
    /// given the selection the client reported.
    func plan(selection: NSRange, deleteCount: Int) -> Plan {
        if selection.location == NSNotFound || selection.length == NSNotFound { return .unsupported }
        if selection.location < 0 || selection.length < 0 || deleteCount < 0 { return .mismatch }
        if selection.length != 0 { return .mismatch }
        if let expected, expected != selection.location { return .mismatch }
        if selection.location < deleteCount { return .mismatch }
        return .replace(NSRange(location: selection.location - deleteCount, length: deleteCount))
    }

    /// The input method replaced `range` with `insertedLength` UTF-16 units.
    mutating func didReplace(_ range: NSRange, insertedLength: Int) {
        expected = range.location + insertedLength
    }

    /// The input method inserted text at the cursor without asking for its position
    /// (deleteCount 0, replacementRange NSNotFound).
    mutating func didInsertAtCursor(length: Int) {
        if let e = expected { expected = e + length }
    }

    /// The key went to the app unchanged and the app inserts `length` UTF-16 units.
    mutating func passedThrough(length: Int) {
        if let e = expected { expected = e + length }
    }

    /// The Delete key went to the app unchanged: it removes one character. Every letter
    /// the engine tracks is one UTF-16 unit (Vietnamese precomposed letters are in the BMP).
    mutating func backspacePassedThrough() {
        if let e = expected { expected = e > 0 ? e - 1 : nil }
    }

    /// Forget the expected position: word ended, engine reset, focus or client changed.
    mutating func invalidate() {
        expected = nil
    }
}
