import Foundation

/// The macOS option "Automatically switch to a document's input source" (Keyboard
/// settings › Input Sources). It is what remembers Tiếng Việt / ABC per window; Dấu
/// only shows it on "Ứng dụng" and opens Keyboard settings to change it (D5, N1, N4).
///
/// Read, never written (N4), from `com.apple.HIToolbox` → `AppleGlobalTextInputProperties`
/// → `TextInputGlobalPropertyPerContextInput`, through the read-only shared-preference
/// exception in Dau.entitlements.
enum DocumentInputSource {
    /// Whether the option is on; `nil` when the preference cannot be read or the key is
    /// missing, so the UI shows no value instead of a guess (N5).
    static func isOn() -> Bool? {
        // Pick up a change made in System Settings while Dấu was running.
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        let properties = CFPreferencesCopyAppValue("AppleGlobalTextInputProperties" as CFString, domain)
        return isOn(properties: properties)
    }

    /// The option's value in an `AppleGlobalTextInputProperties` dictionary.
    static func isOn(properties: Any?) -> Bool? {
        guard let properties = properties as? [String: Any],
              let value = properties["TextInputGlobalPropertyPerContextInput"] as? NSNumber
        else { return nil }
        return value.boolValue
    }
}
