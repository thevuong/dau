import Foundation
import DauEngine

/// Minimal settings for M2: only the typing method, chosen from the input menu.
///
/// Stored in the input method's own sandbox defaults, not the App Group yet: reading the
/// App Group container from an ad-hoc signed build may raise a system consent prompt
/// (open question in DECISIONS.md), which must never happen while the user types.
/// TODO(M4): move to the shared settings model in DauShared, read from the App Group,
/// and observe changes from the host app.
enum InputSettings {
    static let typingMethodKey = "typingMethod"

    static func typingMethod(_ defaults: UserDefaults = .standard) -> EngineOptions.InputMethod {
        switch defaults.string(forKey: typingMethodKey) {
        case "vni": return .vni
        case "simpleTelex": return .simpleTelex
        default: return .telex // D15
        }
    }

    static func setTypingMethod(_ method: EngineOptions.InputMethod, _ defaults: UserDefaults = .standard) {
        let value: String
        switch method {
        case .telex: value = "telex"
        case .simpleTelex: value = "simpleTelex"
        case .vni: value = "vni"
        }
        defaults.set(value, forKey: typingMethodKey)
    }

    /// Engine options for M2: D15 defaults plus the chosen typing method.
    static func engineOptions(_ defaults: UserDefaults = .standard) -> EngineOptions {
        EngineOptions(inputMethod: typingMethod(defaults))
    }
}
