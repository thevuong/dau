import AppKit
import InputMethodKit
import os
import DauShared

// Entry point of the input method process.
// IMKServer registers the Mach connection named in Info.plist (InputMethodConnectionName);
// the system then instantiates DauInputController (InputMethodServerControllerClass) per client.

let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DauInputMethod", category: "server")

guard let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      !connectionName.isEmpty else {
    logger.fault("InputMethodConnectionName missing from Info.plist")
    exit(1)
}

let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

// D2/D5 (30/10/2026): drop the per-app mode memory written by older builds.
LegacyModeMemory.removeIfPresent()

#if DEBUG
// Debug only: log the settings at launch and on every change (SettingsReloadLog).
let settingsReloadLog = SettingsReloadLog.start()
#else
let settingsReloadLog: SettingsChangeObserver? = nil
#endif

// D7, D16, D37: the host app asks this process to quit after replacing the bundle
// (upgrade) or before moving it to the Trash (uninstall). Every live controller first
// ends its word (underline mode commits the marked text as shown, `quitRequested`), then
// the process exits; macOS launches the bundle on disk at the next key.
let quitObserver = InputMethodLifecycle.observeQuitRequests(
    inputMethodBundleID: Bundle.main.bundleIdentifier ?? "DauInputMethod", on: .main) {
    MainActor.assumeIsolated {
        logger.notice("event=quit-requested")
        NotificationCenter.default.post(name: .dauQuitRequested, object: nil)
        // Next turn of the run loop, so the commits above reach the clients first.
        DispatchQueue.main.async { exit(0) }
    }
}
if quitObserver == nil {
    logger.error("event=quit-observe-failed (the host app falls back to terminating the process)")
}

withExtendedLifetime((server, settingsReloadLog, quitObserver)) {
    NSApplication.shared.run()
}
