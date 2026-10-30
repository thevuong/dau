import AppKit
import Carbon
import Observation

/// Whether Dấu is among the user's enabled input sources (Text Input Sources, read only).
/// Drives the "Dấu chưa được bật" banner. Rechecked when the app becomes active and
/// when the system announces a change of enabled input sources.
@MainActor
@Observable
final class InputSourceStatus {
    /// `nil` when the state cannot be determined (no input method bundle found):
    /// the banner stays hidden rather than showing something unverified (N5).
    private(set) var isEnabled: Bool?

    @ObservationIgnored private var tokens: [NSObjectProtocol] = []

    init() {
        refresh()
        let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main, using: refresh))
        tokens.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main, using: refresh))
    }

    /// For previews and snapshots.
    init(fixed: Bool?) {
        isEnabled = fixed
    }

    func refresh() {
        isEnabled = Self.query()
    }

    /// Reads the enabled input sources now: is "Dấu – Tiếng Việt" (the `.vi` mode, D2)
    /// among them? The same test as `SystemInputMethodInstaller.status()`: the parent
    /// input method alone being on does not let the user type. `nil` when the input
    /// method bundle is not found inside the app.
    nonisolated static func query() -> Bool? {
        guard let modeID = inputModeID else { return nil }
        let filter = [kTISPropertyInputSourceID as String: modeID] as CFDictionary
        // includeAllInstalled = false: only enabled sources are returned.
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return false
        }
        return CFArrayGetCount(list) > 0
    }

    /// The Vietnamese input mode ID of the input method inside this app.
    nonisolated static let inputModeID: String? = InputMethodBundleFiles.info(
        at: Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Input Methods/DauInputMethod.app"))?
        .vietnameseModeID

    /// Bundle ID of the input method shipped inside this app (project.yml embeds it in
    /// Contents/Library/Input Methods).
    nonisolated static let inputMethodBundleID: String? = {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/Input Methods/DauInputMethod.app")
        return Bundle(url: url)?.bundleIdentifier
    }()
}
