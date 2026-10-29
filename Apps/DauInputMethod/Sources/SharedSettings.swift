import Foundation
import DauShared
import os

/// Logger for settings and per-app rule events. D8: never the text typed; only fixed
/// event names, settings values and the client's bundle ID.
let settingsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DauInputMethod",
                            category: "settings")

extension SettingsStore {
    /// The store the input method reads and the "Kiểu gõ" menu writes, opened once per
    /// process (a `static let` is initialized exactly once, thread-safely, so the choice
    /// below is logged once).
    ///
    /// Normally the App Group suite shared with the Settings app. Without one (no
    /// `DauAppGroupIdentifier` in Info.plist, or the suite cannot be opened) the input
    /// method falls back to its own defaults, like the Settings app does: typing keeps
    /// working with D15 defaults plus the menu's choice, but the two apps do not see each
    /// other's changes.
    ///
    /// Note: an ad-hoc signed build (no Team ID) may get a suite that is *not* shared
    /// with the Settings app even though it opens fine; that cannot be detected here
    /// without touching the group container, so it is checked by hand (PROGRESS.md).
    static var inputMethod: SettingsStore { inputMethodChoice.store }

    /// Which suite `inputMethod` uses, for diagnostics.
    enum InputMethodStoreKind: String {
        case appGroup
        case standard
    }

    /// Opened once per process: see `inputMethod`.
    static let inputMethodChoice: (store: SettingsStore, kind: InputMethodStoreKind) = {
        if let store = SettingsStore.appGroup() {
            settingsLogger.notice("store=appGroup")
            return (store, .appGroup)
        }
        settingsLogger.error("store=standard reason=no-app-group (Settings app changes will not reach the input method)")
        let store = SettingsStore(defaults: .standard,
                                  suiteName: Bundle.main.bundleIdentifier ?? "DauInputMethod")
        return (store, .standard)
    }()
}

#if DEBUG
/// Debug only: one log line per settings load done for the process, so
/// `scripts/selftest-app-group.sh` can check without typing that a change saved by the
/// Settings app reaches this process through the App Group and the Darwin notification.
///
/// Process-wide on purpose: controllers only observe changes while a client is active,
/// and the self test must also work when no client has been activated yet. It reads the
/// same store the controllers read, on the same queue.
///
/// D8: settings values only (fixed enum names), never anything typed.
enum SettingsReloadLog {
    /// Logs the settings at launch and returns the observer that logs every reload.
    /// Keep the result alive for the life of the process.
    static func start() -> SettingsChangeObserver? {
        log(event: "settings-loaded")
        let observer = SettingsStore.inputMethod.observeChanges(on: .main) {
            SettingsReloadLog.log(event: "settings-reloaded")
        }
        if observer == nil {
            settingsLogger.error("event=reload-log-observe-failed")
        }
        return observer
    }

    private static func log(event: String) {
        let choice = SettingsStore.inputMethodChoice
        let settings = choice.store.load()
        settingsLogger.notice("""
            event=\(event, privacy: .public) store=\(choice.kind.rawValue, privacy: .public) \
            typingMethod=\(settings.typingMethod.rawValue, privacy: .public) \
            tonePlacement=\(settings.tonePlacement.rawValue, privacy: .public)
            """)
    }
}
#endif

/// The process's `AppModeMemory` (D5), shared by every controller because the start
/// mode is about apps, not client sessions. Remembered modes are persisted in the input
/// method's own defaults so they survive a restart of the process (update, logout).
///
/// Why the input method's own defaults and not the shared settings store: only the input
/// method reads them, and writing them to the App Group would post a settings change to
/// the Settings app on every mode switch for nothing.
final class ModeMemory: @unchecked Sendable {
    // @unchecked: `memory` is guarded by the lock; `UserDefaults` is documented as
    // thread-safe. In practice IMK calls everything on the main thread.

    static let shared = ModeMemory(defaults: .standard)
    static let defaultsKey = "rememberedInputModes"

    private let lock: OSAllocatedUnfairLock<AppModeMemory>
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        lock = OSAllocatedUnfairLock(
            initialState: AppModeMemory(propertyList: defaults.array(forKey: ModeMemory.defaultsKey)))
    }

    /// See `AppModeMemory.activate`.
    func activate(bundleID: String, current: InputMode, settings: DauSettings) -> InputMode? {
        lock.withLock { $0.activate(bundleID: bundleID, current: current, settings: settings) }
    }

    /// See `AppModeMemory.record`. Persists when something changed.
    func record(_ mode: InputMode, for bundleID: String, settings: DauSettings) {
        let changed: [[String]]? = lock.withLock { memory in
            memory.record(mode, for: bundleID, settings: settings) ? memory.propertyList : nil
        }
        if let changed { defaults.set(changed, forKey: ModeMemory.defaultsKey) }
    }

    /// Forgets every remembered mode once "Nhớ chế độ theo từng ứng dụng" is off, so the
    /// list of apps is not kept for a feature the user turned off.
    func forgetRememberedIfDisabled(_ settings: DauSettings) {
        guard !settings.rememberModePerApp else { return }
        if lock.withLock({ $0.forgetRemembered() }) {
            defaults.removeObject(forKey: ModeMemory.defaultsKey)
        }
    }
}
