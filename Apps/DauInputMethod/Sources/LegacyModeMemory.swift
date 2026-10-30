import Foundation
import os

/// Data left by builds that had "Dấu – Tiếng Anh" and "Nhớ chế độ theo từng ứng dụng"
/// (before 30/10/2026, D2/D5): the input method kept the last mode per app, keyed by
/// bundle ID, in its own defaults. Nothing reads it any more, so it is removed at launch
/// rather than left behind (D8 spirit: no list of the user's apps kept for nothing).
enum LegacyModeMemory {
    static let defaultsKey = "rememberedInputModes"

    /// Removes the old key if present. Returns true if something was removed.
    @discardableResult
    static func removeIfPresent(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: defaultsKey) != nil else { return false }
        defaults.removeObject(forKey: defaultsKey)
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "DauInputMethod", category: "settings")
            .notice("event=legacy-mode-memory-removed")
        return true
    }
}
