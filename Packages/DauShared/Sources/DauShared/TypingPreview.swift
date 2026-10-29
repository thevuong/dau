import DauEngine

/// Runs the real engine over a key sequence, the way the input method drives it, and
/// returns the text an app would show. Used by the Settings previews and examples so
/// every "keys → result" shown to the user is produced by the engine itself (N5), and
/// by tests that pin those examples.
public enum TypingPreview {
    /// Types `keys` into a field that already contains `displayed` (D20: the engine is
    /// seeded from it, as the input method does when the buffer is empty), then ends
    /// the word as a word boundary would (D4).
    public static func type(_ keys: String, options: EngineOptions, after displayed: String = "") -> String {
        var engine = VietEngine(options: options)
        var text = Array(displayed.unicodeScalars)
        if !displayed.isEmpty {
            engine.seed(displayed: displayed.unicodeScalars)
        }
        func apply(_ action: Action, key: Unicode.Scalar?) {
            switch action {
            case .passThrough:
                if let key { text.append(key) }
            case .replace(let deleteCount, let insert):
                text.removeLast(min(deleteCount, text.count))
                text.append(contentsOf: insert)
            }
        }
        for key in keys.unicodeScalars {
            apply(engine.handle(key), key: key)
        }
        apply(engine.endWord(), key: nil)
        var view = String.UnicodeScalarView()
        view.append(contentsOf: text)
        return String(view)
    }
}

/// One "keys → result" example shown in Settings. `result` is computed by the engine.
public struct TypingExample: Sendable, Hashable, Identifiable {
    /// Text already in the app before typing (D20 examples), or empty.
    public let displayed: String
    /// Keys the user types.
    public let keys: String
    public let result: String

    public var id: String { displayed + "\u{1}" + keys }

    public init(keys: String, after displayed: String = "", options: EngineOptions) {
        self.displayed = displayed
        self.keys = keys
        self.result = TypingPreview.type(keys, options: options, after: displayed)
    }
}

/// The examples used by the Settings window, per typing method. Key sequences are
/// chosen per method because the same keys mean different things in Telex and VNI;
/// results always come from the engine.
public enum SettingsExamples {
    /// "Xem trước" card on "Gõ phím": a sentence and a tone-placement sample, typed
    /// with the user's current settings. With "Bỏ dấu tự do" off the tone keys follow
    /// the vowel directly, since that is how the user has to type then (D28).
    public static func preview(_ settings: DauSettings) -> [TypingExample] {
        let options = settings.engineOptions
        let keys: [String]
        switch (settings.typingMethod, settings.freeMarking) {
        case (.vni, true): keys = ["to6i ye6u tie6ng1 Vie6t5", "hoa2 thuy1"]
        case (.vni, false): keys = ["to6i ye6u tie61ng Vie65t", "hoa2 thuy1"]
        case (_, true): keys = ["tooi yeeu tieengs Vieetj", "hoaf thuys"]
        case (_, false): keys = ["tooi yeeu tieesng Vieejt", "hoaf thuys"]
        }
        return keys.map { TypingExample(keys: $0, options: options) }
    }

    /// Options for the "Thông minh" examples: the user's method with automatic restore
    /// on, since the examples describe what that switch does.
    static func smartOptions(_ method: DauSettings.TypingMethod) -> EngineOptions {
        var settings = DauSettings(typingMethod: method)
        settings.autoRestore = true
        return settings.engineOptions
    }

    /// "Tự khôi phục từ không phải tiếng Việt": foreign words come back as typed,
    /// Vietnamese words still get their marks.
    public static func restore(_ method: DauSettings.TypingMethod) -> [TypingExample] {
        let options = smartOptions(method)
        let vietnamese = method == .vni ? "Vie65t" : "Vieetj"
        return ["windows", "Hasaki", vietnamese].map { TypingExample(keys: $0, options: options) }
    }

    /// A word that is both English-looking and a valid syllable: Vietnamese wins (D4).
    public static func vietnameseWins(_ method: DauSettings.TypingMethod) -> TypingExample {
        TypingExample(keys: method == .vni ? "lan2" : "car", options: smartOptions(method))
    }

    /// Doubling the mark key keeps the original letters (D4, D26, D36).
    public static func keepOriginal(_ method: DauSettings.TypingMethod) -> TypingExample {
        TypingExample(keys: method == .vni ? "lan22" : "carr", options: smartOptions(method))
    }

    /// The key that adds the dot-below tone (nặng) in `method`.
    public static func dotBelowKey(_ method: DauSettings.TypingMethod) -> String {
        method == .vni ? "5" : "j"
    }

    /// "Thêm dấu cho từ đã gõ" (D20): "hoc" is already in the app, the user types the
    /// tone key.
    public static func addMarks(_ method: DauSettings.TypingMethod) -> TypingExample {
        TypingExample(keys: dotBelowKey(method), after: "hoc", options: smartOptions(method))
    }
}
