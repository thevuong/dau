import DauShared

/// Every "keys → result" shown in Settings, with key sequences taken from the mockup.
/// Results always come from the engine (`TypingExample` runs `VietEngine`), so the
/// window can only show what Dấu really types (N5). Pinned by
/// `scripts/snapshot-settings` tests.
enum SettingsSamples {
    /// "Xem trước" on "Gõ phím", typed with the user's settings. With "Bỏ dấu tự do"
    /// off the tone keys follow the vowel directly, since that is how the user types
    /// then (D28).
    static func preview(_ settings: DauSettings) -> TypingExample {
        let keys: String
        switch (settings.typingMethod, settings.freeMarking) {
        case (.vni, true): keys = "hoa2 binh2, tie61ng Vie65t"
        case (.vni, false): keys = "hoa2 bi2nh, tie61ng Vie65t"
        case (_, true): keys = "hoaf binhf, tieengs Vieetj"
        case (_, false): keys = "hoaf bifnh, tieesng Vieejt"
        }
        return TypingExample(keys: keys, options: settings.engineOptions)
    }

    /// The "Thông minh" examples use the user's typing method with automatic restore
    /// on, since they describe what that switch does.
    static func smart(_ keys: String, after displayed: String = "",
                      _ method: DauSettings.TypingMethod) -> TypingExample {
        let settings = DauSettings(typingMethod: method, autoRestore: true)
        return TypingExample(keys: keys, after: displayed, options: settings.engineOptions)
    }

    /// Foreign words come back as typed, Vietnamese words keep their marks (D4).
    static func restore(_ method: DauSettings.TypingMethod) -> [TypingExample] {
        let vietnamese = method == .vni ? "vie65t" : "vieetj"
        return ["windows", "Sunrise", vietnamese].map { smart($0, method) }
    }

    /// Both English-looking and a valid syllable: Vietnamese wins (D4, D36).
    static func vietnameseWins(_ method: DauSettings.TypingMethod) -> TypingExample {
        smart(method == .vni ? "lan2" : "car", method)
    }

    /// Doubling the mark key keeps the original letters (D4, D26).
    static func keepOriginal(_ method: DauSettings.TypingMethod) -> TypingExample {
        smart(method == .vni ? "lan22" : "carr", method)
    }

    /// The hint under the onboarding's try-it field (step 3), for the chosen method.
    static func tryIt(_ method: DauSettings.TypingMethod) -> TypingExample {
        let keys = method == .vni ? "to6i ye6u tie61ng Vie65t" : "tooi yeeu tieengs Vieetj"
        return TypingExample(keys: keys, options: DauSettings(typingMethod: method).engineOptions)
    }

    /// "Thêm dấu cho từ đã gõ" (D20): "hoc" is already in the app, then the nặng key.
    static func addMarks(_ method: DauSettings.TypingMethod) -> TypingExample {
        smart(method == .vni ? "5" : "j", after: "hoc", method)
    }
}
