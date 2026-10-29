import DauShared

/// D2: "Tiếng Việt" and "Tiếng Anh" are two input modes of the same input source.
enum InputMode: String, Sendable, Equatable {
    case vietnamese
    case english

    init(_ mode: AppRule.Mode) {
        switch mode {
        case .vietnamese: self = .vietnamese
        case .english: self = .english
        }
    }

    var ruleMode: AppRule.Mode {
        switch self {
        case .vietnamese: .vietnamese
        case .english: .english
        }
    }

    /// Mode IDs are the keys of `tsInputModeListKey` in Info.plist: the input method's
    /// bundle ID + ".vi" / ".en".
    func identifier(base: String) -> String {
        switch self {
        case .vietnamese: base + ".vi"
        case .english: base + ".en"
        }
    }

    /// The mode for an input source / input mode ID, or nil if the ID is not one of
    /// Dấu's two modes (another input source, garbage from IMK — D18).
    init?(identifier: String, base: String) {
        guard !base.isEmpty else { return nil }
        if identifier == base + ".vi" {
            self = .vietnamese
        } else if identifier == base + ".en" {
            self = .english
        } else {
            return nil
        }
    }
}

/// Which mode each app should start in (D5). Pure value type, unit tested.
///
/// The input method process holds one of these (`ModeMemory`), because the rule is about
/// apps, not about one client session: IMK creates a new controller for every text field,
/// and switching between two fields of the same app must not re-apply the start mode.
struct AppModeMemory: Sendable, Equatable {
    /// Upper bound on remembered apps, so a long-running process never grows without
    /// limit. The oldest entry is dropped first.
    static let capacity = 256
    /// Longest bundle ID accepted (CFBundleIdentifier is far shorter in practice; D18).
    static let maxBundleIDLength = 255

    /// App of the last activated client, to tell "switched to another app" from
    /// "another text field of the same app".
    private(set) var lastBundleID: String?
    /// D5 "Nhớ chế độ theo từng ứng dụng": last mode used per app, oldest first.
    private(set) var remembered: [Entry] = []

    struct Entry: Sendable, Equatable {
        var bundleID: String
        var mode: InputMode
    }

    init() {}

    func rememberedMode(for bundleID: String) -> InputMode? {
        remembered.last { $0.bundleID == bundleID }?.mode
    }

    /// A client of `bundleID` became active while the input source is in `current`.
    /// Returns the mode to switch to, or nil to keep the current one.
    ///
    /// Only a change of app applies the start mode: a new field (or window) of the same
    /// app keeps whatever the user chose there. The decision itself is D5, implemented
    /// once in `DauSettings.startMode(for:remembered:)`.
    mutating func activate(bundleID: String, current: InputMode, settings: DauSettings) -> InputMode? {
        guard AppModeMemory.isUsable(bundleID) else { return nil }
        let previous = lastBundleID
        lastBundleID = bundleID
        guard previous != bundleID else { return nil }
        guard let target = settings.startMode(for: bundleID,
                                              remembered: rememberedMode(for: bundleID)?.ruleMode) else {
            return nil
        }
        let mode = InputMode(target)
        return mode == current ? nil : mode
    }

    /// The user is in `mode` in `bundleID` (mode switched, or the app is being left).
    /// Kept only while "Nhớ chế độ theo từng ứng dụng" is on and the app has no rule of
    /// its own (D5: a rule always wins, so remembering would be dead data).
    /// Returns true if the memory changed.
    @discardableResult
    mutating func record(_ mode: InputMode, for bundleID: String, settings: DauSettings) -> Bool {
        guard settings.rememberModePerApp,
              AppModeMemory.isUsable(bundleID),
              settings.rule(for: bundleID) == nil else { return false }
        if let index = remembered.firstIndex(where: { $0.bundleID == bundleID }) {
            if remembered[index].mode == mode && index == remembered.count - 1 { return false }
            remembered.remove(at: index)
        }
        remembered.append(Entry(bundleID: bundleID, mode: mode))
        if remembered.count > AppModeMemory.capacity {
            remembered.removeFirst(remembered.count - AppModeMemory.capacity)
        }
        return true
    }

    /// Drops every remembered mode (the setting was turned off). Returns true if anything
    /// was dropped.
    @discardableResult
    mutating func forgetRemembered() -> Bool {
        guard !remembered.isEmpty else { return false }
        remembered.removeAll()
        return true
    }

    // MARK: - Persistence

    /// Remembered modes as a property list: an array of `[bundleID, mode]` pairs, oldest
    /// first. `lastBundleID` is not persisted (a new process starts with no current app).
    var propertyList: [[String]] {
        remembered.map { [$0.bundleID, $0.mode.rawValue] }
    }

    /// Restores remembered modes from `propertyList`; anything malformed is skipped (D18).
    init(propertyList: Any?) {
        guard let pairs = propertyList as? [Any] else { return }
        for pair in pairs.suffix(AppModeMemory.capacity) {
            guard let pair = pair as? [String], pair.count == 2,
                  AppModeMemory.isUsable(pair[0]),
                  let mode = InputMode(rawValue: pair[1]) else { continue }
            remembered.removeAll { $0.bundleID == pair[0] }
            remembered.append(Entry(bundleID: pair[0], mode: mode))
        }
    }

    static func isUsable(_ bundleID: String) -> Bool {
        !bundleID.isEmpty && bundleID.utf8.count <= maxBundleIDLength
    }
}
