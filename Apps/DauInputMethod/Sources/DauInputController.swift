import AppKit
import Carbon
import InputMethodKit
import DauEngine
import DauShared

/// One instance per client session (IMKServer creates it). Each controller owns its own
/// `VietEngine` and cursor tracker: no global mutable state (ARCHITECTURE.md).
///
/// Dấu has a single input mode, "Tiếng Việt" (D2, 30/10/2026). English is typed with a
/// system input source (ABC, U.S.…), so there is no mode state here: whatever mode ID IMK
/// reports (an old install may still have "….Dau.en" enabled), keys are handled as
/// Vietnamese (D18).
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
    /// In-place mode (method A): cursor tracking and D20 "Thêm dấu cho từ đã gõ".
    private var inPlace = InPlaceComposer()
    /// Keeps the Darwin notification registration alive; dropped when the client closes.
    private var settingsObserver: SettingsChangeObserver?
    /// Selected-input-source change observer (see `startObservingInputSource`).
    private var sourceObserver: InputSourceObserver?
    /// Quit request from the host app (main.swift), see `startObservingQuit`.
    private var quitObserver: NSObjectProtocol?
    /// When IMK last activated this controller (`ProcessInfo.systemUptime`).
    private var activatedAt: TimeInterval = 0
    /// Identity of the last client proxy seen, to reset when the client changes.
    private var clientID: ObjectIdentifier?
    /// Bundle ID of the client app, for perf logs and per-app rules (D13); read once
    /// at activation, never while typing (N3).
    private var clientApp = "?"
    private let perf = PerfLog()
    /// Underline mode (D13) for the current client: the word is marked text, committed
    /// at its end. Decided at activation and on settings changes, never per key.
    private var underline = false
    private var composer = MarkedComposer()
    /// The client the marked text was sent to, so a reset that arrives with another
    /// client (or none) still commits it where it is shown.
    private weak var markedClient: AnyObject?

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
            // Underline mode: commit the word where it is shown before the click moves
            // the cursor (D4: reset, no restore).
            let committed = resetComposition(client: sender)
            inPlace.noteEvent(at: event.timestamp)
            record(KeyResult(kind: committed ? .commit : .reset), start: start)
            return false
        default:
            return false
        }
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
        let timed = TimedClient(client)
        var result: KeyResult
        if underline {
            result = processMarked(route, client: timed)
        } else {
            let outcome = inPlace.handle(route, time: event.timestamp, engine: &engine, client: timed)
            result = KeyResult(consumed: outcome.consumed, kind: outcome.kind)
            #if DEBUG
            result.diag = outcome.attempt.map(ReplaceDiag.init)
            #endif
        }
        result.selectedRangeNs = timed.selectedRangeNs
        result.insertTextNs = timed.callNs
        result.readNs = timed.readNs
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
        var readNs: Int64 = -1
        #if DEBUG
        /// Positions of the last replacement attempt of this key (Debug diagnostics).
        var diag: ReplaceDiag?
        #endif
    }

    /// Underline mode (D13): at most one `setMarkedText` or `insertText` per key, both
    /// with replacementRange NSNotFound; never `selectedRange` (N3), and no D20 read
    /// (see ARCHITECTURE.md). See `MarkedComposer`.
    private func processMarked(_ route: KeyRoute, client: TimedClient) -> KeyResult {
        let outcome = composer.handle(route, engine: &engine, client: client)
        markedClient = composer.isComposing ? (client.client as AnyObject) : nil
        var result = KeyResult(consumed: outcome.consumed)
        switch outcome.call {
        case .none:
            if case .ignore = route { result.kind = .reset }
        case .setMarkedText:
            result.kind = .mark
        case .insertText:
            result.kind = .commit
        }
        return result
    }

    private func record(_ result: KeyResult, start: UInt64) {
        perf.record(result.kind,
                    handleNs: PerfLog.now() &- start,
                    selectedRangeNs: result.selectedRangeNs,
                    insertTextNs: result.insertTextNs,
                    readNs: result.readNs,
                    app: clientApp)
    }

    // MARK: - Session state (D11 resets)

    /// Ends the word without restoring it (D4). In underline mode the marked word is
    /// committed as shown, never dropped: to the client it was shown in if still alive,
    /// else to `client`. Returns true if text was committed.
    @discardableResult
    private func resetComposition(client: Any? = nil) -> Bool {
        inPlace.reset(engine: &engine)
        guard composer.isComposing else {
            composer.abandon(engine: &engine) // resets the engine; no text to keep
            return false
        }
        let target = (markedClient as? IMKTextInput) ?? (client as? IMKTextInput)
        markedClient = nil
        guard let target else {
            // D18: no client to commit to; the app keeps or drops its marked text.
            composer.abandon(engine: &engine)
            perf.note("marked-abandoned", app: clientApp)
            return false
        }
        return composer.commit(engine: &engine, client: TimedClient(target)) == .insertText
    }

    /// Resets when the client proxy changes under this controller.
    private func noteClient(_ sender: Any) {
        let id = ObjectIdentifier(sender as AnyObject)
        if clientID != id {
            if clientID != nil {
                // The marked word (if any) is committed to the old client.
                resetComposition()
                perf.note("client-changed", app: clientApp)
            }
            clientID = id
            inPlace.activate() // a new client may give text (D20) even if the last did not
        }
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        resetComposition(client: sender)
        activatedAt = ProcessInfo.processInfo.systemUptime
        inPlace.activate()
        startObservingSettings()
        startObservingInputSource()
        startObservingQuit()
        // D18: a nil sender must not keep the previous app's ID (and its underline rule).
        clientID = sender.map { ObjectIdentifier($0 as AnyObject) }
        clientApp = clientBundleID(sender)
        // Catch up on anything missed while no observer was registered (or if the
        // registration failed). One small JSON decode per activation, not per key.
        // After `clientApp` is known, so the app's underline rule applies (D13).
        apply(SettingsStore.inputMethod.load())
        perf.note("activate", app: clientApp)
        if underline {
            settingsLogger.notice("event=underline-on app=\(self.clientApp, privacy: .public)")
        }
    }

    /// The client app's bundle ID, read once at activation. Chrome sometimes activates
    /// the input method through a client whose `bundleIdentifier()` is nil (seen
    /// 30/10/2026 in the D13 trial: the Chrome rule then did not apply); the frontmost
    /// app is the one receiving keys, so it stands in. "?" if neither is known (D18).
    private func clientBundleID(_ sender: Any?) -> String {
        if let id = (sender as? IMKTextInput)?.bundleIdentifier(), !id.isEmpty { return id }
        let frontmost = onMain { NSWorkspace.shared.frontmostApplication?.bundleIdentifier } ?? nil
        guard let frontmost, !frontmost.isEmpty else { return "?" }
        perf.note("client-bundle-id-frontmost", app: frontmost)
        return frontmost
    }

    override func deactivateServer(_ sender: Any!) {
        resetComposition(client: sender)
        super.deactivateServer(sender)
    }

    /// The client wants the composition ended now (click elsewhere, focus change…).
    /// Underline mode commits the marked word as shown; in-place mode has nothing to
    /// insert and forgets the word. (super is not called on purpose: its default would
    /// insert `composedString`, which Dấu does not use.)
    override func commitComposition(_ sender: Any!) {
        resetComposition(client: sender)
    }

    override func inputControllerWillClose() {
        resetComposition()
        settingsObserver = nil
        sourceObserver = nil
        if let quitObserver { NotificationCenter.default.removeObserver(quitObserver) }
        quitObserver = nil
        super.inputControllerWillClose()
    }

    // MARK: - Quit requested by the host app (upgrade, uninstall)

    /// The process is about to exit (main.swift): end the word like any reset (D4), so
    /// underline mode commits the marked text where it is shown instead of leaving it
    /// to a process that is gone.
    private func startObservingQuit() {
        guard quitObserver == nil else { return }
        let target = WeakController(self)
        quitObserver = NotificationCenter.default.addObserver(
            forName: .dauQuitRequested, object: nil, queue: nil) { _ in
            guard Thread.isMainThread else { return }
            target.controller?.quitRequested()
        }
    }

    private func quitRequested() {
        let committed = resetComposition(client: client() as Any?)
        if committed { perf.note("quit-commit", app: clientApp) }
    }

    // MARK: - Input source changes IMK does not report (M3)

    /// A switch to another input source and back that IMK does not report with
    /// `deactivateServer`/`activateServer` (measured 30/10/2026: `TISSelectInputSource`
    /// from another process, "to" → U.S. → Dấu → "o" gave "tô") must still end the word
    /// (D4: reset, no restore). The system posts the distributed notification
    /// `kTISNotifySelectedKeyboardInputSourceChanged` for every switch, and a sandboxed
    /// process may observe it. A switch made with the keyboard shortcut or the menu also
    /// activates this controller; its notification arrives just after and is ignored, so
    /// keys typed right after the switch keep their word.
    private func startObservingInputSource() {
        guard sourceObserver == nil else { return }
        let target = WeakController(self)
        sourceObserver = InputSourceObserver {
            guard Thread.isMainThread else { return }
            target.controller?.inputSourceDidChange()
        }
    }

    /// Notifications this soon after `activateServer` are taken as the echo of that
    /// activation.
    static let activationEcho: TimeInterval = 0.5

    private func inputSourceDidChange() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - activatedAt >= Self.activationEcho else { return }
        let hadWord = engine.isComposing || composer.isComposing
        resetComposition(client: client() as Any?)
        if hadWord { perf.note("source-changed-reset", app: clientApp) }
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
        let newUnderline = UnderlineMode.isOn(settings: new, bundleID: clientApp,
                                              debugForced: Self.debugForcedUnderline())
        if newUnderline != underline || new.engineOptions != engine.options {
            // D4: a settings change ends the word without restoring it; a marked word is
            // committed as shown before the engine is reset or the mode switches.
            resetComposition(client: client() as Any?)
        }
        settings = new
        underline = newUnderline
        if EngineSettings.apply(new, to: &engine) {
            inPlace.reset(engine: &engine)
            perf.note("options-changed", app: clientApp)
        }
        // D20 "Thêm dấu cho từ đã gõ" (D15: on by default). Read here, never per key.
        inPlace.addMarksEnabled = new.addMarksToTypedWords
    }

    /// Debug builds only: bundle IDs forced into underline mode for trials
    /// (`UnderlineMode.debugForceKey` in the global defaults domain; see
    /// scripts/selftest-typing/run.sh `--underline`). Read at activation and on settings
    /// changes, never per key. Release builds never read it.
    private static func debugForcedUnderline() -> [String] {
        #if DEBUG
        let any = kCFPreferencesAnyApplication
        // Pick up a `defaults write -g` made since the last read.
        CFPreferencesAppSynchronize(any)
        let value = CFPreferencesCopyAppValue(UnderlineMode.debugForceKey as CFString, any)
        return (value as? [Any])?.compactMap { $0 as? String } ?? []
        #else
        return []
        #endif
    }

    // MARK: - Input mode (D2)

    /// IMK reports the selected input mode here. Dấu has one mode (D2), so the value is
    /// not used beyond a reset (D4: a source/mode change ends the word without restoring
    /// it). Any value, including an old "….Dau.en" ID or garbage, is accepted (D18).
    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        // D18: a nil value carries nothing to store; super is not given it.
        if let value { super.setValue(value, forTag: tag, client: sender) }
        guard tag == kTextServiceInputModePropertyTag else { return }
        resetComposition(client: sender)
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
        resetComposition(client: client() as Any?)
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

/// `IMKTextInput` as the client of either mode, timing each call of the key for the
/// perf log (D8: durations only, never the text).
private final class TimedClient: MarkedTextClient, InPlaceClient {
    let client: IMKTextInput
    /// Duration of the `insertText` or `setMarkedText` call of the key, -1 if none.
    private(set) var callNs: Int64 = -1
    private(set) var selectedRangeNs: Int64 = -1
    /// Duration of the `attributedSubstring` call (D20), -1 if none.
    private(set) var readNs: Int64 = -1

    init(_ client: IMKTextInput) { self.client = client }

    func selectedRange() -> NSRange {
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("selectedRange")
        let range = client.selectedRange()
        PerfLog.signposter.endInterval("selectedRange", signpost)
        selectedRangeNs = Int64(PerfLog.now() &- start)
        return range
    }

    func text(in range: NSRange) -> String? {
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("attributedSubstring")
        // D18: the header allows nil (no document access); never force-unwrap.
        let attributed: NSAttributedString? = client.attributedSubstring(from: range)
        PerfLog.signposter.endInterval("attributedSubstring", signpost)
        readNs = Int64(PerfLog.now() &- start)
        return attributed?.string
    }

    func setMarkedText(_ text: String, selectionRange: NSRange, replacementRange: NSRange) {
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("setMarkedText")
        client.setMarkedText(text, selectionRange: selectionRange, replacementRange: replacementRange)
        PerfLog.signposter.endInterval("setMarkedText", signpost)
        callNs = Int64(PerfLog.now() &- start)
    }

    func insertText(_ text: String, replacementRange: NSRange) {
        let start = PerfLog.now()
        let signpost = PerfLog.signposter.beginInterval("insertText")
        client.insertText(text, replacementRange: replacementRange)
        PerfLog.signposter.endInterval("insertText", signpost)
        callNs = Int64(PerfLog.now() &- start)
    }
}

/// Observes the distributed notification for a change of the selected keyboard input
/// source (`kTISNotifySelectedKeyboardInputSourceChanged`) on the main queue; removes
/// itself when released. The notification carries no text (D8) and nothing is read from
/// it: it only says that a switch happened.
private final class InputSourceObserver {
    private let token: NSObjectProtocol

    init(_ handler: @escaping @Sendable () -> Void) {
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        token = DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { _ in
            handler()
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(token)
    }
}

/// Weak reference that can cross into the `@Sendable` settings handler. Only
/// dereferenced on the main thread (see `startObservingSettings`).
private final class WeakController: @unchecked Sendable {
    weak var controller: DauInputController?
    init(_ controller: DauInputController) { self.controller = controller }
}

extension Notification.Name {
    /// Posted on the main thread just before the process exits at the host app's
    /// request (main.swift).
    static let dauQuitRequested = Notification.Name("DauQuitRequested")
}
