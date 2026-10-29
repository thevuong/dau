import AppKit

/// Opens panes of System Settings. Dấu never changes system settings itself; it only
/// opens the right screen (N4).
enum SystemSettings {
    /// Keyboard settings: keyboard shortcuts for input sources and the input source list.
    static func openKeyboard() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
