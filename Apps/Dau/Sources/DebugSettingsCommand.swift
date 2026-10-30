#if DEBUG
import Foundation
import DauShared

/// Debug only: `Dau --set-typing-method <telex|vni|simpleTelex>` saves the typing method
/// through the same store the Settings window uses, posts the change notification, prints
/// one line and exits without opening a window. Used by `scripts/selftest-app-group.sh`
/// to check, without typing, that the input method hears the change.
///
/// Run the built binary directly (not through `open`) so the line reaches the terminal;
/// the process has the app's real signature and App Group entitlement.
enum DebugSettingsCommand {
    static let flag = "--set-typing-method"

    /// Runs the command if `arguments` contain the flag; never returns in that case.
    static func runIfRequested(_ arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: flag) else { return }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex,
              let method = DauSettings.TypingMethod(rawValue: arguments[valueIndex]) else {
            let allowed = DauSettings.TypingMethod.allCases.map(\.rawValue).joined(separator: "|")
            FileHandle.standardError.write(Data("usage: Dau \(flag) <\(allowed)>\n".utf8))
            exit(2)
        }

        // Same choice as SettingsModel.appGroup(): the App Group suite, else the app's
        // own defaults.
        let (store, kind, suite): (SettingsStore, String, String) = {
            if let store = SettingsStore.appGroup(),
               let suite = SettingsStore.appGroupIdentifier() {
                return (store, "appGroup", suite)
            }
            let suite = Bundle.main.bundleIdentifier ?? "Dau"
            return (SettingsStore(defaults: .standard, suiteName: suite), "standard", suite)
        }()

        var settings = store.load()
        let previous = settings.typingMethod.rawValue
        settings.typingMethod = method
        store.save(settings) // also posts the Darwin notification
        // Hand the write to cfprefsd before the process exits. Returns false when cfprefsd
        // refused the write: the value read back below then only comes from this
        // process's cache and no other process will see it.
        let synchronized = store.defaults.synchronize()

        let readBack = store.load().typingMethod.rawValue
        print("saved store=\(kind) typingMethod=\(readBack) previous=\(previous) "
              + "synchronize=\(synchronized ? "ok" : "failed") "
              + "notification=\(store.changeNotificationName) path=\(plistPath(kind: kind, suite: suite))")
        exit(readBack == method.rawValue ? 0 : 1)
    }

    /// Where the suite's plist lives, as the app sees it, with whether the
    /// file exists. "unknown" when the App Group container cannot be resolved.
    private static func plistPath(kind: String, suite: String) -> String {
        let fileManager = FileManager.default
        let url: URL?
        if kind == "appGroup" {
            url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: suite)?
                .appendingPathComponent("Library/Preferences/\(suite).plist")
        } else {
            // The app's standard suite (not sandboxed since D37: ~/Library/Preferences).
            url = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Preferences/\(suite).plist")
        }
        guard let url else { return "unknown" }
        let exists = fileManager.fileExists(atPath: url.path)
        return "\(url.path) exists=\(exists ? "yes" : "no")"
    }
}
#endif
