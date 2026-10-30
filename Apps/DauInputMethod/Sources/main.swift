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

withExtendedLifetime((server, settingsReloadLog)) {
    NSApplication.shared.run()
}
