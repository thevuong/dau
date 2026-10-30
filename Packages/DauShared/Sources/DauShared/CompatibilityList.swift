// The compatibility list (D7, D13): apps for which Dấu suggests underlining.
//
// Today the list ships inside the host app as a JSON resource
// (Apps/Dau/Resources/CompatibilityList.json). In M7 the host app also downloads a
// signed copy of the same format into the App Group container (D7, N2); the host app
// then uses whichever valid copy has the higher `version`. The input method never reads
// the list: underlining only follows the user's rules (D13), and a suggestion only
// becomes a rule when the user changes it in Settings.

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
    /// The rows of "Quy tắc riêng" (D5, D13).
    ///
    /// - First the suggested apps, in list order: the stored rule if the user changed
    ///   it (source `.suggested`), otherwise, if the app is installed and has no rule,
    ///   an unsaved "Không gạch chân" rule with source `.suggested`. Nothing is stored
    ///   until the user changes it, and a row keeps its place when it gets stored.
    /// - Stored suggested rules whose app left the list follow, then the user's rules
    ///   in stored order. A user rule for a suggested app stays a user rule.
    public func ruleRows(suggesting list: CompatibilityList,
                         isInstalled: (String) -> Bool) -> [AppRule] {
        var rows: [AppRule] = []
        var shown = Set<String>()
        for id in list.suggestedBundleIDs {
            if let stored = rule(for: id) {
                guard stored.source == .suggested else { continue }
                rows.append(stored)
                shown.insert(id)
            } else if isInstalled(id) {
                rows.append(AppRule(bundleID: id, displayName: list.suggestion(for: id)?.name,
                                    underline: false, source: .suggested))
                shown.insert(id)
            }
        }
        for stored in appRules where stored.source == .suggested && !shown.contains(stored.bundleID) {
            rows.append(stored)
            shown.insert(stored.bundleID)
        }
        rows += appRules.filter { !shown.contains($0.bundleID) }
        return rows
    }

    /// Sets the underline choice of a row from `ruleRows`. A suggested app goes back to
    /// having no stored rule when set to "Không gạch chân" (its default, D13); a user
    /// rule keeps its explicit choice.
    public mutating func setUnderline(_ underline: Bool, for row: AppRule) {
        var updated = rule(for: row.bundleID) ?? row
        updated.underline = underline
        if updated.source == .suggested && !underline {
            removeRule(for: row.bundleID)
        } else {
            upsert(updated)
        }
    }
}
