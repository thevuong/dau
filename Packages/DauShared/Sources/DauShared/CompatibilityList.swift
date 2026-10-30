// The compatibility list (D7, D13): apps for which Dấu suggests underlining.
//
// Today the list ships inside the host app as a JSON resource
// (Apps/Dau/Resources/CompatibilityList.json). In M7 the host app also downloads a
// signed copy of the same format into the App Group container (D7, N2); the host app
// then uses whichever valid copy has the higher `version`. The input method never reads
// the list: underlining only follows the stored rules (D13), and a suggestion only
// becomes a rule when the user clicks "Bật gạch chân" in Settings.

import Foundation

/// The apps Dấu labels "Đề xuất" on the Apps page (D13). Suggestions are labels only:
/// every app types without underline until the user turns it on (D13, 30/10/2026).
///
/// Decoding is lenient (D18): unknown keys are ignored, a malformed entry is dropped
/// without losing the others, and blank bundle IDs are skipped.
public struct CompatibilityList: Sendable, Codable, Equatable {
    /// One app. An app may ship under several bundle IDs (e.g. two editions); rules
    /// are per bundle ID, so each installed ID gets its own row.
    public struct Entry: Sendable, Codable, Equatable {
        public var bundleIDs: [String]
        /// Name used when the app's own name is not available.
        public var name: String?
        /// Whether Dấu suggests "Có gạch chân" for this app.
        public var suggestUnderline: Bool
        /// Maintainers' note (where the entry comes from). Not shown to the user (N5).
        public var note: String?

        public init(bundleIDs: [String], name: String? = nil, suggestUnderline: Bool = true,
                    note: String? = nil) {
            self.bundleIDs = bundleIDs
            self.name = name
            self.suggestUnderline = suggestUnderline
            self.note = note
        }

        private enum CodingKeys: String, CodingKey {
            case bundleIDs, name, suggestUnderline, note
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let ids = ((try? c.decodeIfPresent([Lenient<String>].self, forKey: .bundleIDs)) ?? nil) ?? []
            var seen = Set<String>()
            let bundleIDs = ids.compactMap(\.value)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && seen.insert($0).inserted }
            guard !bundleIDs.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .bundleIDs, in: c, debugDescription: "no bundle ID")
            }
            func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
                ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
            }
            self.init(
                bundleIDs: bundleIDs,
                name: value(.name, nil as String?),
                suggestUnderline: value(.suggestUnderline, false),
                note: value(.note, nil as String?))
        }
    }

    /// Increases with every published list; M7 keeps the copy with the higher version.
    public var version: Int
    public var apps: [Entry]

    public init(version: Int = 0, apps: [Entry] = []) {
        self.version = version
        self.apps = apps
    }

    /// No suggestions.
    public static let empty = CompatibilityList()

    private enum CodingKeys: String, CodingKey {
        case version, apps
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let apps = ((try? c.decodeIfPresent([Lenient<Entry>].self, forKey: .apps)) ?? nil) ?? []
        self.init(
            version: ((try? c.decodeIfPresent(Int.self, forKey: .version)) ?? nil) ?? 0,
            apps: apps.compactMap(\.value))
    }

    /// Decodes `data`; an unreadable file gives the empty list (D18).
    public static func decode(_ data: Data) -> CompatibilityList {
        (try? JSONDecoder().decode(CompatibilityList.self, from: data)) ?? .empty
    }

    /// The list at `url`, or the empty list if it is missing or unreadable.
    public static func load(from url: URL?) -> CompatibilityList {
        guard let url, let data = try? Data(contentsOf: url) else { return .empty }
        return decode(data)
    }

    /// File name of the copy bundled with the host app.
    public static let resourceName = "CompatibilityList"

    /// The copy bundled in `bundle` (the host app), or the empty list.
    public static func bundled(in bundle: Bundle = .main) -> CompatibilityList {
        load(from: bundle.url(forResource: resourceName, withExtension: "json"))
    }

    /// Bundle IDs suggested for underlining, in list order, without duplicates.
    public var suggestedBundleIDs: [String] {
        var seen = Set<String>()
        return apps.filter(\.suggestUnderline)
            .flatMap(\.bundleIDs)
            .filter { seen.insert($0).inserted }
    }

    /// The entry suggesting `bundleID`, if any.
    public func suggestion(for bundleID: String) -> Entry? {
        apps.first { $0.suggestUnderline && $0.bundleIDs.contains(bundleID) }
    }
}

extension DauSettings {
    /// The rows of "Đề xuất" (D13): the installed suggested apps that have no stored
    /// rule, in list order. Each row is the rule "Bật gạch chân" would store (underline
    /// on, source `.suggested`); nothing is stored until the user accepts it.
    ///
    /// Any stored rule for the app, user-made or accepted, takes it out of "Đề xuất",
    /// even when it is set back to "Không gạch chân". Removing the rule brings the
    /// suggestion back. "Quy tắc riêng" lists `appRules` as stored.
    public func suggestions(from list: CompatibilityList,
                            isInstalled: (String) -> Bool) -> [AppRule] {
        list.suggestedBundleIDs.compactMap { id in
            guard rule(for: id) == nil, isInstalled(id) else { return nil }
            return AppRule(bundleID: id, displayName: list.suggestion(for: id)?.name,
                           underline: true, source: .suggested)
        }
    }

    /// "Bật gạch chân" on a row of `suggestions`: stores the rule with underline on and
    /// source `.suggested`, at the end of "Quy tắc riêng". D13: this is the only way a
    /// suggestion turns underline on.
    public mutating func acceptSuggestion(_ suggestion: AppRule) {
        var rule = suggestion
        rule.underline = true
        rule.source = .suggested
        upsert(rule)
    }

    /// Sets the underline choice of the stored rule for `bundleID`, keeping the rule and
    /// its source (a suggested rule set to "Không gạch chân" stays a rule). Does nothing
    /// if there is no stored rule.
    public mutating func setUnderline(_ underline: Bool, for bundleID: String) {
        guard var updated = rule(for: bundleID) else { return }
        updated.underline = underline
        upsert(updated)
    }
}
