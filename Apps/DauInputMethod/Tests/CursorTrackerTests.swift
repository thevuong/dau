import Foundation
import Testing

@Suite("CursorTracker (method A + D11 drift check)")
struct CursorTrackerTests {
    private let notFound = NSRange(location: NSNotFound, length: NSNotFound)

    private func at(_ location: Int, _ length: Int = 0) -> NSRange {
        NSRange(location: location, length: length)
    }

    @Test("first replacement of a word trusts selectedRange")
    func firstReplacement() {
        let t = CursorTracker()
        #expect(t.plan(selection: at(10), deleteCount: 1) == .replace(at(9, 1)))
        #expect(t.plan(selection: at(3), deleteCount: 3) == .replace(at(0, 3)))
    }

    @Test("no document access: NSNotFound is reported as unsupported")
    func unsupported() {
        let t = CursorTracker()
        #expect(t.plan(selection: notFound, deleteCount: 1) == .unsupported)
        #expect(t.plan(selection: NSRange(location: NSNotFound, length: 0), deleteCount: 1) == .unsupported)
    }

    @Test("a selection, too little text, or negative values are a mismatch")
    func invalid() {
        let t = CursorTracker()
        #expect(t.plan(selection: at(10, 2), deleteCount: 1) == .mismatch)
        #expect(t.plan(selection: at(1), deleteCount: 2) == .mismatch)
        #expect(t.plan(selection: at(-1), deleteCount: 1) == .mismatch)
        #expect(t.plan(selection: at(5), deleteCount: -1) == .mismatch)
    }

    @Test("tooi: t o pass, o replaces, i passes; the next replacement must match")
    func followsTheWord() {
        // Document "x " then the word starts at 2.
        var t = CursorTracker()
        t.passedThrough(length: 1) // t — nothing known yet
        t.passedThrough(length: 1) // o
        #expect(t.expected == nil)
        guard case .replace(let r) = t.plan(selection: at(4), deleteCount: 1) else {
            Issue.record("expected a replacement"); return
        }
        t.didReplace(r, insertedLength: 1) // "ô"
        #expect(t.expected == 4)
        t.passedThrough(length: 1) // i
        #expect(t.expected == 5)
        #expect(t.plan(selection: at(5), deleteCount: 2) == .replace(at(3, 2)))
    }

    @Test("D11: the cursor moved without a reported click → mismatch")
    func drift() {
        var t = CursorTracker()
        t.didReplace(at(9, 1), insertedLength: 1)
        #expect(t.plan(selection: at(42), deleteCount: 1) == .mismatch)
        #expect(t.plan(selection: at(10), deleteCount: 1) == .replace(at(9, 1)))
    }

    @Test("pass-through Delete moves the expectation back by one")
    func backspace() {
        var t = CursorTracker()
        t.didReplace(at(9, 1), insertedLength: 2)
        t.backspacePassedThrough()
        #expect(t.expected == 10)
        var z = CursorTracker()
        z.didReplace(at(0, 0), insertedLength: 0)
        z.backspacePassedThrough()
        #expect(z.expected == nil)
    }

    @Test("insertion at the cursor and invalidation")
    func insertAndInvalidate() {
        var t = CursorTracker()
        t.didInsertAtCursor(length: 1)
        #expect(t.expected == nil)
        t.didReplace(at(4, 1), insertedLength: 1)
        t.didInsertAtCursor(length: 2)
        #expect(t.expected == 7)
        t.invalidate()
        #expect(t.expected == nil)
        #expect(t.plan(selection: at(100), deleteCount: 1) == .replace(at(99, 1)))
    }
}
