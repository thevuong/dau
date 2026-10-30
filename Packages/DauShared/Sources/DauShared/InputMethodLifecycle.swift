import Foundation
import notify

/// How the host app asks the running input method to quit (D7, D16, D37): after the
/// bundle in ~/Library/Input Methods was replaced (upgrade) or before it is moved to the
/// Trash (uninstall). The host posts a Darwin notification; the input method commits
/// the word it shows (underline mode) and exits, and macOS launches the new bundle at
/// the next key. No signal to any system process (`imklaunchagent` and the like are
/// never touched, docs/research/M5-INSTALL.md section 3).
///
/// The name is derived from the input method's bundle ID, which never changes between
/// versions (D37), so an old input method hears a new host app.
///
/// Any process of the user can post a Darwin notification, so any process can make the
/// input method quit; macOS launches it again at the next key, so the worst case is a
/// word whose marks restart. Accepted: it carries no data and changes no setting.
public enum InputMethodLifecycle {
    public static func quitNotificationName(inputMethodBundleID: String) -> String {
        inputMethodBundleID + ".quitRequested"
    }

    /// Asks the input method with this bundle ID to quit.
    public static func requestQuit(inputMethodBundleID: String) {
        notify_post(quitNotificationName(inputMethodBundleID: inputMethodBundleID))
    }

    /// Calls `handler` on `queue` whenever a quit is requested. Keep the returned object
    /// alive; `nil` if the system refuses the registration.
    public static func observeQuitRequests(
        inputMethodBundleID: String,
        on queue: DispatchQueue,
        handler: @escaping @Sendable () -> Void
    ) -> SettingsChangeObserver? {
        SettingsChangeObserver(name: quitNotificationName(inputMethodBundleID: inputMethodBundleID),
                               queue: queue, handler: handler)
    }
}
