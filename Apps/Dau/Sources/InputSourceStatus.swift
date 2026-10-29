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
        guard let bundleID = Self.inputMethodBundleID else {
            isEnabled = nil
            return
        }
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        // includeAllInstalled = false: only enabled sources are returned.
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            isEnabled = false
            return
        }
        isEnabled = CFArrayGetCount(list) > 0
    }

    /// Bundle ID of the input method shipped inside this app (project.yml embeds it in
    /// Contents/Library/Input Methods).
    static let inputMethodBundleID: String? = {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/Input Methods/DauInputMethod.app")
        return Bundle(url: url)?.bundleIdentifier
    }()
}
