import DauEngine

/// Runs the real engine over a key sequence, the way the input method drives it, and
/// returns the text an app would show. The host app builds every "keys → result"
/// shown in Settings with it (Apps/Dau/Sources/SettingsSamples.swift), so they are
/// produced by the engine itself (N5).
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
