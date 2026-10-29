import AppKit
import Carbon
import InputMethodKit
import DauEngine

/// One instance per client session (IMKServer creates it). Each controller owns its own
/// `VietEngine`, cursor tracker and mode: no global mutable state (ARCHITECTURE.md).
///
/// The Objective-C name is pinned so Info.plist `InputMethodServerControllerClass`
/// does not depend on the Swift module name.
///
/// Threading: IMK calls every method here on the main thread (the IMKServer connection
/// is serviced by the main run loop). AppKit UI types (NSMenu, NSWorkspace) are
/// main-actor isolated, so those calls go through `onMain`, which refuses to run (instead
/// of trapping) if that ever stops being true (D18).
@objc(DauInputController)
final class DauInputController: IMKInputController {
    /// D2: "Tiếng Việt" and "Tiếng Anh" are two input modes of the same input source.
    enum Mode { case vietnamese, english }

    private var engine = VietEngine(options: InputSettings.engineOptions())
    private var tracker = CursorTracker()
    private var mode: Mode = .vietnamese
    /// Identity of the last client proxy seen, to reset when the client changes.
    private var clientID: ObjectIdentifier?
    /// Bundle ID of the client app, for perf logs only (cached at activation, N3).
    private var clientApp = "?"
    private let perf = PerfLog()

    // MARK: - Keys

    override func recognizedEvents(_ sender: Any!) -> Int {
        // Mouse downs reach `handle` so a click resets the word (D4, D11). The click itself
        // always goes to the app (handle returns false).
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return Int(truncatingIfNeeded: mask.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("handle")
        defer { PerfLog.signposter.endInterval("handle", signpost) }

        // D18: IMK may pass nil or odd events (the Emoji palette once sent an empty one).
        guard let event else { return false }
        switch event.type {
        case .keyDown:
            break
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            resetComposition()
            record(KeyResult(kind: .reset), start: start)
            return false
        default:
            return false
        }
        // D2: in "Tiếng Anh" every key goes straight to the app.
        guard mode == .vietnamese else { return false }
        guard let sender, let client = sender as? IMKTextInput else {
            resetComposition()
            perf.note("client-not-text-input", app: clientApp)
            return false
        }
        noteClient(sender)

        // `characters` throws for non-key events; the type was checked above (D18).
        let route = KeyRouter.route(keyCode: event.keyCode,
                                    modifiers: event.modifierFlags,
                                    characters: event.characters)
        let result = process(route, client: client)
        record(result, start: start)
        return result.consumed
    }

    /// Outcome of one key, for the return value and the perf log.
    private struct KeyResult {
        var consumed = false
        var kind: PerfLog.Kind = .pass
        var selectedRangeNs: Int64 = -1
        var insertTextNs: Int64 = -1
        /// The replacement could not be applied (mismatch, unsupported client).
        var failed = false
    }

    private func process(_ route: KeyRoute, client: IMKTextInput) -> KeyResult {
        switch route {
        case .ignore:
            // D4: shortcuts, arrows, Esc only reset; nothing is restored.
            resetComposition()
            return KeyResult(kind: .reset)

        case .backspace:
            let wasComposing = engine.isComposing
            switch engine.backspace() {
            case .passThrough:
                // The app deletes one character itself.
                if wasComposing && engine.isComposing {
                    tracker.backspacePassedThrough()
                } else {
                    tracker.invalidate()
                }
                return KeyResult()
            case .replace(let deleteCount, let insert):
                var result = replace(deleteCount: deleteCount, insert: insert, client: client)
                if result.failed {
                    // Let the app's own Delete run; the engine no longer knows the word.
                    resetComposition()
                    result.consumed = false
                } else if !engine.isComposing {
                    tracker.invalidate()
                }
                return result
            }

        case .endWord:
            // Return, Tab, keypad Enter: restore the word if needed (D4), then let the app
            // handle the key itself (send a message, move focus…).
            var result = KeyResult()
            if case .replace(let deleteCount, let insert) = engine.endWord() {
                result = replace(deleteCount: deleteCount, insert: insert, client: client)
            }
            resetComposition()
            result.consumed = false
            return result

        case .character(let scalar):
            switch engine.handle(scalar) {
            case .passThrough:
                tracker.passedThrough(length: scalar.utf16.count)
                if !engine.isComposing { tracker.invalidate() }
                return KeyResult()
            case .replace(let deleteCount, let insert):
                var result = replace(deleteCount: deleteCount, insert: insert, client: client)
                if result.failed {
                    // D11: the app's text is not what the engine thinks. Start over from
                    // this key alone, so it still does the most it can on its own.
                    resetComposition()
                    switch engine.handle(scalar) {
                    case .passThrough:
                        result.consumed = false
                    case .replace(0, let insert):
                        let inserted = insertAtCursor(insert, client: client)
                        result.insertTextNs = inserted
                        result.consumed = true
                    case .replace:
                        resetComposition()
                        result.consumed = false
                    }
                    if !engine.isComposing { tracker.invalidate() }
                    return result
                }
                if !engine.isComposing { tracker.invalidate() }
                return result
            }
        }
    }

    /// Applies `.replace` with exactly one `insertText` call (N3). Method A: ask the
    /// client for `selectedRange` when text before the cursor must be replaced.
    private func replace(deleteCount: Int, insert: TextBuffer, client: IMKTextInput) -> KeyResult {
        var result = KeyResult(consumed: true)
        if deleteCount == 0 {
            result.kind = .insert
            result.insertTextNs = insertAtCursor(insert, client: client)
            return result
        }
        // Engine letters are BMP scalars, so deleteCount scalars == deleteCount UTF-16 units
        // (no D20 seed yet, so no decomposed text can be on screen).
        let selStart = PerfLog.now()
        let selSignpost = PerfLog.signposter.beginInterval("selectedRange")
        let selection = client.selectedRange()
        PerfLog.signposter.endInterval("selectedRange", selSignpost)
        result.selectedRangeNs = Int64(PerfLog.now() &- selStart)

        switch tracker.plan(selection: selection, deleteCount: deleteCount) {
        case .replace(let range):
            let text = insert.description
            let insStart = PerfLog.now()
            let insSignpost = PerfLog.signposter.beginInterval("insertText")
            client.insertText(text, replacementRange: range)
            PerfLog.signposter.endInterval("insertText", insSignpost)
            result.insertTextNs = Int64(PerfLog.now() &- insStart)
            tracker.didReplace(range, insertedLength: text.utf16.count)
            result.kind = .replace
        case .unsupported:
            result.kind = .unsupported
            result.failed = true
            result.consumed = false
        case .mismatch:
            result.kind = .mismatch
            result.failed = true
            result.consumed = false
        }
        return result
    }

    /// Inserts at the current selection without asking where it is (deleteCount 0).
    /// Returns the duration of the `insertText` call in nanoseconds.
    private func insertAtCursor(_ insert: TextBuffer, client: IMKTextInput) -> Int64 {
        let text = insert.description
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("insertText")
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        PerfLog.signposter.endInterval("insertText", signpost)
        tracker.didInsertAtCursor(length: text.utf16.count)
        return Int64(PerfLog.now() &- start)
    }

    private func record(_ result: KeyResult, start: UInt64) {
        perf.record(result.kind,
                    handleNs: PerfLog.now() &- start,
                    selectedRangeNs: result.selectedRangeNs,
                    insertTextNs: result.insertTextNs,
                    app: clientApp)
    }

    // MARK: - Session state (D11 resets)

    private func resetComposition() {
        engine.reset()
        tracker.invalidate()
    }

    /// Resets when the client proxy changes under this controller.
    private func noteClient(_ sender: Any) {
        let id = ObjectIdentifier(sender as AnyObject)
        if clientID != id {
            if clientID != nil {
                resetComposition()
                perf.note("client-changed", app: clientApp)
            }
            clientID = id
        }
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        resetComposition()
        // Pick up a typing method chosen from the menu in another controller.
        let options = InputSettings.engineOptions()
        if engine.options != options { engine.options = options }
        if let sender {
            clientID = ObjectIdentifier(sender as AnyObject)
            clientApp = (sender as? IMKTextInput)?.bundleIdentifier() ?? "?"
        }
        syncModeFromCurrentInputSource()
        perf.note("activate", app: clientApp)
    }

    override func deactivateServer(_ sender: Any!) {
        resetComposition()
        super.deactivateServer(sender)
    }

    /// The client wants the composition ended now. Dấu has no marked text in M2, so there
    /// is nothing to insert: forget the word. (super is not called on purpose: its default
    /// would insert `composedString`, which Dấu does not use.)
    override func commitComposition(_ sender: Any!) {
        resetComposition()
    }

    override func inputControllerWillClose() {
        resetComposition()
        super.inputControllerWillClose()
    }

    // MARK: - Input modes (D2)

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        super.setValue(value, forTag: tag, client: sender)
        guard tag == kTextServiceInputModePropertyTag, let modeID = value as? String else { return }
        applyMode(modeID)
    }

    /// Mode IDs are the keys of `tsInputModeListKey` in Info.plist: bundle ID + ".vi"/".en".
    private func applyMode(_ modeID: String) {
        let base = Bundle.main.bundleIdentifier ?? ""
        let newMode: Mode
        if modeID == base + ".en" {
            newMode = .english
        } else if modeID == base + ".vi" {
            newMode = .vietnamese
        } else {
            return
        }
        guard newMode != mode else { return }
        mode = newMode
        resetComposition()
        perf.note(newMode == .english ? "mode-en" : "mode-vi", app: clientApp)
        // TODO(D17): VoiceOver announcement on mode change. Not added yet: switching modes
        // is an input source change the system may already announce (N1); check on a real
        // machine first (docs/M2-TESTING.md) to avoid speaking twice.
    }

    /// At activation, read the selected input source so the mode is right even if IMK
    /// does not send `setValue(_:forTag:client:)` first.
    private func syncModeFromCurrentInputSource() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return }
        let sourceID = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        applyMode(sourceID)
    }

    // MARK: - Input menu

    override func menu() -> NSMenu! {
        let current = InputSettings.typingMethod()
        return onMain { () -> NSMenu in
            let menu = NSMenu()
            menu.autoenablesItems = false
            let header = NSMenuItem(title: String(localized: "Kiểu gõ", comment: "Input menu: header of the typing method group."),
                                    action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            let methods: [(String, EngineOptions.InputMethod, Selector)] = [
                (String(localized: "Telex", comment: "Input menu: typing method name."), .telex, #selector(selectTelex(_:))),
                (String(localized: "VNI", comment: "Input menu: typing method name."), .vni, #selector(selectVNI(_:))),
                (String(localized: "Telex đơn giản", comment: "Input menu: typing method name (D29)."), .simpleTelex, #selector(selectSimpleTelex(_:))),
            ]
            for (title, method, action) in methods {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.state = method == current ? .on : .off
                item.indentationLevel = 1
                menu.addItem(item)
            }
            menu.addItem(.separator())
            // N4: only open the right System Settings pane; never change settings.
            menu.addItem(NSMenuItem(title: String(localized: "Mở cài đặt Bàn phím…", comment: "Input menu: opens System Settings › Keyboard."),
                                    action: #selector(openKeyboardSettings(_:)), keyEquivalent: ""))
            // TODO(M4): "Cài đặt Dấu…" opening the host app's Settings window.
            return menu
        }
    }

    // IMK calls menu actions on the controller with an info dictionary as the argument
    // (kIMKCommandMenuItemName, kIMKCommandClientName); it is not needed here.
    @objc func selectTelex(_ sender: Any?) { setTypingMethod(.telex) }
    @objc func selectVNI(_ sender: Any?) { setTypingMethod(.vni) }
    @objc func selectSimpleTelex(_ sender: Any?) { setTypingMethod(.simpleTelex) }

    private func setTypingMethod(_ method: EngineOptions.InputMethod) {
        InputSettings.setTypingMethod(method)
        engine.options.inputMethod = method
        resetComposition()
    }

    @objc func openKeyboardSettings(_ sender: Any?) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") else { return }
        _ = onMain { NSWorkspace.shared.open(url) }
    }

    /// Runs `body` on the main actor if already on the main thread; returns nil otherwise
    /// instead of trapping (D18).
    private func onMain<T>(_ body: @MainActor () -> T) -> T? {
        guard Thread.isMainThread else { return nil }
        nonisolated(unsafe) var result: T?
        MainActor.assumeIsolated { result = body() }
        return result
    }
}
