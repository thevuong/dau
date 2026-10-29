import AppKit
import InputMethodKit
import os

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

withExtendedLifetime(server) {
    NSApplication.shared.run()
}
