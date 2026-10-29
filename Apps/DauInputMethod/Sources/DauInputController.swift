import AppKit
import Carbon
import InputMethodKit
import DauEngine
import DauShared

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
    /// Shared settings as last read from `SettingsStore.inputMethod` (M4). Re-read on
    /// every change notification and at activation.
    private var settings = SettingsStore.inputMethod.load()
    private lazy var engine = VietEngine(options: settings.engineOptions)
    private var tracker = CursorTracker()
    private var mode: InputMode = .vietnamese
    /// Keeps the Darwin notification registration alive; dropped when the client closes.
    private var settingsObserver: SettingsChangeObserver?
    /// Identity of the last client proxy seen, to reset when the client changes.
    private var clientID: ObjectIdentifier?
    /// Bundle ID of the client app, for perf logs and per-app rules (D5, D13); read once
    /// at activation, never while typing (N3).
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
        #if DEBUG
        // After the timing is recorded, so the extra selectedRange is not measured.
        if let diag = result.diag { ReplaceDiag.log(diag, kind: result.kind, client: client, app: clientApp) }
        #endif
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
        #if DEBUG
        /// Positions of the last replacement attempt of this key (Debug diagnostics).
        var diag: ReplaceDiag?
        #endif
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
        #if DEBUG
        result.diag = ReplaceDiag(deleteCount: deleteCount, selection: selection,
                                  expected: tracker.expected, insertedLength: insert.description.utf16.count)
        #endif

        switch tracker.plan(selection: selection, deleteCount: deleteCount) {
        case .replace(let range):
            #if DEBUG
            result.diag?.replacement = range
            #endif
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
        startObservingSettings()
        // Catch up on anything missed while no observer was registered (or if the
        // registration failed). One small JSON decode per activation, not per key.
        apply(SettingsStore.inputMethod.load())
        var client: IMKTextInput?
        if let sender {
            clientID = ObjectIdentifier(sender as AnyObject)
            client = sender as? IMKTextInput
            clientApp = client?.bundleIdentifier() ?? "?"
        }
        syncModeFromCurrentInputSource()
        perf.note("activate", app: clientApp)
        if let client { applyStartMode(client: client) }
        noteAppRule()
    }

    override func deactivateServer(_ sender: Any!) {
        resetComposition()
        // D5: remember the mode the app is left in (only kept when the setting is on).
        if clientApp != "?" { ModeMemory.shared.record(mode, for: clientApp, settings: settings) }
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
        settingsObserver = nil
        super.inputControllerWillClose()
    }

    // MARK: - Shared settings (M4)

    /// Registers for the settings change notification once per controller. Each
    /// controller re-reads the store itself, so there is no registry of live controllers
    /// to keep in sync (no global mutable state).
    private func startObservingSettings() {
        guard settingsObserver == nil else { return }
        let target = WeakController(self)
        // Delivered on the main queue, where IMK also calls this controller, so the
        // engine is never touched from two threads.
        settingsObserver = SettingsStore.inputMethod.observeChanges(on: .main) {
            guard Thread.isMainThread else { return }
            target.controller?.settingsDidChange()
        }
        if settingsObserver == nil {
            settingsLogger.error("event=observe-failed (changes apply at next activation)")
        }
    }

    private func settingsDidChange() {
        apply(SettingsStore.inputMethod.load())
    }

    /// Applies new settings to this controller. A change of engine options in the middle
    /// of a word drops the word first (`EngineSettings.apply`).
    private func apply(_ new: DauSettings) {
        settings = new
        if EngineSettings.apply(new, to: &engine) {
            tracker.invalidate()
            perf.note("options-changed", app: clientApp)
        }
        ModeMemory.shared.forgetRememberedIfDisabled(new)
        // TODO(D20): "Thêm dấu cho từ đã gõ" (`settings.addMarksToTypedWords`). Off: never
        // seed (current behavior). On: not implemented yet — seeding needs
        // `attributedSubstring` for the word before the cursor and a UTF-16 count of the
        // seeded (possibly NFD) text for `deleteCount` (PROGRESS.md, notes for M2). Until
        // then the engine is never seeded, whatever the setting says.
    }

    /// D5: when the user switches to another app, select the mode its rule asks for, or
    /// the mode remembered for it. Uses IMK's own `selectInputMode:` (Swift
    /// `selectMode(_:)`: "allows an input method to change its mode directly",
    /// IMKInputSession.h) rather than `TISSelectInputSource` (N1). One client call per
    /// app switch, never while typing (N3).
    ///
    /// No loop: the system answers with `setValue(_:forTag:client:)`, which only updates
    /// `mode` and never selects a mode itself; and a second activation of the same app is
    /// a no-op in `AppModeMemory.activate`.
    private func applyStartMode(client: IMKTextInput) {
        guard clientApp != "?",
              let target = ModeMemory.shared.activate(bundleID: clientApp, current: mode, settings: settings),
              let base = Bundle.main.bundleIdentifier, !base.isEmpty else { return }
        client.selectMode(target.identifier(base: base))
        perf.note(target == .english ? "start-mode-en" : "start-mode-vi", app: clientApp)
        // The system may already report the new source; if not, setValue(forTag:) will.
        // Record it here too, in case the switch made IMK deactivate this controller
        // (which records the old mode) without a setValue afterwards.
        if syncModeFromCurrentInputSource() {
            ModeMemory.shared.record(mode, for: clientApp, settings: settings)
        }
    }

    /// D13: an app rule may ask for marked text (underlined) instead of in-place
    /// replacement. Not implemented yet; log that the flag was seen, never any text.
    private func noteAppRule() {
        guard clientApp != "?", let rule = settings.rule(for: clientApp), rule.underline else { return }
        // TODO(M3, D13): use setMarkedText for this client instead of replacing in place.
        settingsLogger.notice("event=underline-rule-ignored app=\(self.clientApp, privacy: .public)")
    }

    // MARK: - Input modes (D2)

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        super.setValue(value, forTag: tag, client: sender)
        guard tag == kTextServiceInputModePropertyTag, let modeID = value as? String else { return }
        // D5: a mode the user picked while in this app is what it remembers.
        if applyMode(modeID), clientApp != "?" {
            ModeMemory.shared.record(mode, for: clientApp, settings: settings)
        }
    }

    /// Mode IDs are the keys of `tsInputModeListKey` in Info.plist: bundle ID + ".vi"/".en".
    @discardableResult
    private func applyMode(_ modeID: String) -> Bool {
        guard let newMode = InputMode(identifier: modeID, base: Bundle.main.bundleIdentifier ?? ""),
              newMode != mode else { return false }
        mode = newMode
        resetComposition()
        perf.note(newMode == .english ? "mode-en" : "mode-vi", app: clientApp)
        // TODO(D17): VoiceOver announcement on mode change. Not added yet: switching modes
        // is an input source change the system may already announce (N1); check on a real
        // machine first (docs/M2-TESTING.md) to avoid speaking twice.
        return true
    }

    /// At activation, read the selected input source so the mode is right even if IMK
    /// does not send `setValue(_:forTag:client:)` first.
    /// Returns true if the mode changed.
    @discardableResult
    private func syncModeFromCurrentInputSource() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let sourceID = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        return applyMode(sourceID)
    }

    // MARK: - Input menu

    override func menu() -> NSMenu! {
        let current = settings.typingMethod
        return onMain { () -> NSMenu in
            let menu = NSMenu()
            menu.autoenablesItems = false
            let header = NSMenuItem(title: String(localized: "Kiểu gõ", comment: "Input menu: header of the typing method group."),
                                    action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            let methods: [(String, DauSettings.TypingMethod, Selector)] = [
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
            menu.addItem(NSMenuItem(title: String(localized: "Cài đặt Dấu…", comment: "Input menu: opens the Dấu app (Settings window)."),
                                    action: #selector(openHostApp(_:)), keyEquivalent: ""))
            // N4: only open the right System Settings pane; never change settings.
            menu.addItem(NSMenuItem(title: String(localized: "Mở cài đặt Bàn phím…", comment: "Input menu: opens System Settings › Keyboard."),
                                    action: #selector(openKeyboardSettings(_:)), keyEquivalent: ""))
            return menu
        }
    }

    // IMK calls menu actions on the controller with an info dictionary as the argument
    // (kIMKCommandMenuItemName, kIMKCommandClientName); it is not needed here.
    @objc func selectTelex(_ sender: Any?) { setTypingMethod(.telex) }
    @objc func selectVNI(_ sender: Any?) { setTypingMethod(.vni) }
    @objc func selectSimpleTelex(_ sender: Any?) { setTypingMethod(.simpleTelex) }

    /// Writes through the shared store, so the Settings app (and every other controller)
    /// reloads from the change notification.
    private func setTypingMethod(_ method: DauSettings.TypingMethod) {
        let store = SettingsStore.inputMethod
        var new = store.load()
        new.typingMethod = method
        store.save(new)
        resetComposition()
        apply(new)
    }

    /// "Cài đặt Dấu…": opens the host app, whose main window is Settings (UI.md).
    @objc func openHostApp(_ sender: Any?) {
        guard let (url, reason) = HostApp.url() else {
            settingsLogger.error("event=host-app-not-found")
            return
        }
        settingsLogger.notice("event=host-app-open reason=\(reason.rawValue, privacy: .public) path=\(url.path, privacy: .public)")
        _ = onMain {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    settingsLogger.error("event=host-app-open-failed error=\(String(describing: error), privacy: .public)")
                } else {
                    settingsLogger.notice("event=host-app-opened")
                }
            }
        }
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

/// Weak reference that can cross into the `@Sendable` settings handler. Only
/// dereferenced on the main thread (see `startObservingSettings`).
private final class WeakController: @unchecked Sendable {
    weak var controller: DauInputController?
    init(_ controller: DauInputController) { self.controller = controller }
}
