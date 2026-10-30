// User settings shared by the host app (writes) and the input method (reads).
// Defaults follow D15. Stored as one JSON value by `SettingsStore`.

/// Every user-facing setting of Dấu.
///
/// Decoding is lenient: a missing key or an unknown enum value falls back to the D15
/// default, and a malformed app rule is dropped without losing the others. Settings
/// written by a newer or older version of the app therefore never make the input
/// method fail (D18 spirit).
public struct DauSettings: Sendable, Codable, Equatable {
    /// "Kiểu gõ".
    public enum TypingMethod: String, Sendable, Codable, CaseIterable {
        case telex
        case vni
        /// "Telex đơn giản" (D29).
        case simpleTelex
    }

    /// "Vị trí dấu thanh".
    public enum TonePlacement: String, Sendable, Codable, CaseIterable {
        /// "Kiểu mới": hoà, thuý (D15 default).
        case modern
        /// "Kiểu cũ": hòa, thúy.
        case classic
    }

    /// The "Nâng cao" group. One value instead of two booleans so the mutually
    /// exclusive options of D22 cannot both be on.
    public enum Advanced: String, Sendable, Codable, CaseIterable {
        case off
        /// "Gõ tắt phụ âm" (D21).
        case consonantShortcuts
        /// "Cho phép phụ âm z, f, w, j" (D22).
        case allowZFWJ
    }

    public var typingMethod: TypingMethod
    public var tonePlacement: TonePlacement
    /// "Bỏ dấu tự do" (D28).
    public var freeMarking: Bool
    /// "Tự khôi phục từ không phải tiếng Việt" (D4, D30, D33).
    public var autoRestore: Bool
    /// "Thêm dấu cho từ đã gõ" (D20). Handled by the input method (it seeds the engine
    /// from the app's text), not by `EngineOptions`.
    public var addMarksToTypedWords: Bool
    /// "Nâng cao" (D21, D22).
    public var advanced: Advanced
    /// Per-app rules (D5, D13), at most one per bundle ID, in display order.
    /// (No "Nhớ chế độ theo từng ứng dụng" since 30/10/2026, D5: an old
    /// `"rememberModePerApp"` key is ignored when decoding and dropped on the next save.)
    public private(set) var appRules: [AppRule]

    /// D15 defaults.
    public init(
        typingMethod: TypingMethod = .telex,
        tonePlacement: TonePlacement = .modern,
        freeMarking: Bool = true,
        autoRestore: Bool = true,
        addMarksToTypedWords: Bool = true,
        advanced: Advanced = .off,
        appRules: [AppRule] = []
    ) {
        self.typingMethod = typingMethod
        self.tonePlacement = tonePlacement
        self.freeMarking = freeMarking
        self.autoRestore = autoRestore
        self.addMarksToTypedWords = addMarksToTypedWords
        self.advanced = advanced
        self.appRules = []
        for rule in appRules { upsert(rule) }
    }

    /// The D15 defaults.
    public static let defaults = DauSettings()

    // MARK: - D22: two switches over one value

    /// "Gõ tắt phụ âm". Turning it on turns "Cho phép phụ âm z, f, w, j" off (D22).
    public var consonantShortcuts: Bool {
        get { advanced == .consonantShortcuts }
        set {
            if newValue {
                advanced = .consonantShortcuts
            } else if advanced == .consonantShortcuts {
                advanced = .off
            }
        }
    }

    /// "Cho phép phụ âm z, f, w, j". Turning it on turns "Gõ tắt phụ âm" off (D22).
    public var allowZFWJ: Bool {
        get { advanced == .allowZFWJ }
        set {
            if newValue {
                advanced = .allowZFWJ
            } else if advanced == .allowZFWJ {
                advanced = .off
            }
        }
    }

    // MARK: - App rules (D5, D13)

    /// The rule for `bundleID`, if any.
    public func rule(for bundleID: String) -> AppRule? {
        appRules.first { $0.bundleID == bundleID }
    }

    /// Adds `rule`, or replaces the existing rule for the same bundle ID in place.
    public mutating func upsert(_ rule: AppRule) {
        if let index = appRules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            appRules[index] = rule
        } else {
            appRules.append(rule)
        }
    }

    /// Removes the rule for `bundleID`, if any.
    public mutating func removeRule(for bundleID: String) {
        appRules.removeAll { $0.bundleID == bundleID }
    }

    // MARK: - Codable (lenient)

    private enum CodingKeys: String, CodingKey {
        case typingMethod, tonePlacement, freeMarking, autoRestore, addMarksToTypedWords
        case advanced, appRules
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DauSettings.defaults
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            // `try?` also absorbs unknown enum raw values and wrong types.
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        let rules = ((try? c.decodeIfPresent([Lenient<AppRule>].self, forKey: .appRules)) ?? nil) ?? []
        self.init(
            typingMethod: value(.typingMethod, d.typingMethod),
            tonePlacement: value(.tonePlacement, d.tonePlacement),
            freeMarking: value(.freeMarking, d.freeMarking),
            autoRestore: value(.autoRestore, d.autoRestore),
            addMarksToTypedWords: value(.addMarksToTypedWords, d.addMarksToTypedWords),
            advanced: value(.advanced, d.advanced),
            appRules: rules.compactMap(\.value)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(typingMethod, forKey: .typingMethod)
        try c.encode(tonePlacement, forKey: .tonePlacement)
        try c.encode(freeMarking, forKey: .freeMarking)
        try c.encode(autoRestore, forKey: .autoRestore)
        try c.encode(addMarksToTypedWords, forKey: .addMarksToTypedWords)
        try c.encode(advanced, forKey: .advanced)
        try c.encode(appRules, forKey: .appRules)
    }
}

/// Decodes `T` or yields `nil` instead of failing the whole array.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: any Decoder) throws {
        value = try? T(from: decoder)
    }
}
