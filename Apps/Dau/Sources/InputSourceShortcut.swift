import Foundation

/// The system shortcut that switches input sources, read (never written, N4) from the
/// user's preferences so "Gõ phím" can show it as keycaps (D2):
/// - `com.apple.symbolichotkeys` → `AppleSymbolicHotKeys`, entries 60 ("Select the
///   previous input source", ⌃Space by default) and 61 ("Select next source in input
///   menu"); each holds `enabled` and `value.parameters = (character, key code,
///   modifier flags)`.
/// - `com.apple.HIToolbox` → `AppleFnUsageType`; 1 means the 🌐/fn key changes the
///   input source.
/// The sandbox reads them through the read-only shared-preference exception in
/// Dau.entitlements. When nothing can be read the UI keeps a placeholder (N5).
struct InputSourceShortcut: Equatable, Sendable {
    /// Keycaps of the first enabled shortcut, e.g. ["⌃", "Space"]; empty if none.
    var keys: [String]
    /// The 🌐 key also switches input sources.
    var globeKey: Bool

    var isEmpty: Bool { keys.isEmpty && !globeKey }

    /// Reads the current shortcut; `nil` when the preferences cannot be read.
    static func current() -> InputSourceShortcut? {
        let hotKeys = CFPreferencesCopyAppValue(
            "AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any]
        let fnUsage = CFPreferencesCopyAppValue(
            "AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString) as? Int
        guard hotKeys != nil || fnUsage != nil else { return nil }
        let keys = ["60", "61"].lazy.compactMap { hotKeys?[$0].flatMap(keycaps(from:)) }.first ?? []
        let shortcut = InputSourceShortcut(keys: keys, globeKey: fnUsage == 1)
        return shortcut.isEmpty ? nil : shortcut
    }

    /// Keycaps for one `AppleSymbolicHotKeys` entry, or nil if disabled or malformed.
    static func keycaps(from entry: Any) -> [String]? {
        guard let entry = entry as? [String: Any],
              (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1),
              let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int], parameters.count >= 3 else { return nil }
        let character = parameters[0], keyCode = parameters[1], flags = parameters[2]
        var caps: [String] = []
        // Apple's order: ⌃ ⌥ ⇧ ⌘ (NSEvent.ModifierFlags bits).
        if flags & (1 << 23) != 0 { caps.append("🌐") }
        if flags & (1 << 18) != 0 { caps.append("⌃") }
        if flags & (1 << 19) != 0 { caps.append("⌥") }
        if flags & (1 << 17) != 0 { caps.append("⇧") }
        if flags & (1 << 20) != 0 { caps.append("⌘") }
        guard let key = keyName(character: character, keyCode: keyCode) else { return nil }
        caps.append(key)
        return caps
    }

    static func keyName(character: Int, keyCode: Int) -> String? {
        switch keyCode {
        case 49: return "Space"
        case 48: return "⇥"
        case 36: return "↩"
        case 53: return "⎋"
        case 51: return "⌫"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: break
        }
        guard character > 32, character < 65535, let scalar = Unicode.Scalar(character) else { return nil }
        return String(Character(scalar)).uppercased()
    }
}
