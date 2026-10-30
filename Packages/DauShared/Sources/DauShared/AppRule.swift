// A per-app rule (D5, D13).

/// What Dấu does in one app, identified by bundle ID. A rule always applies (D5),
/// whether the user added it or it came from the compatibility list.
///
/// D5 (30/10/2026): a rule has one setting, underline or not (D13). Dấu has a single
/// input mode (D2), so there is no start mode per app. Rules stored by older versions
/// may still carry a `"mode"` key; it is ignored when decoding and dropped on the next
/// save (D18).
public struct AppRule: Sendable, Codable, Equatable, Hashable, Identifiable {
    /// Where the rule comes from.
    public enum Source: String, Sendable, Codable, CaseIterable {
        /// From the signed compatibility list (D7, D13); shown with the "Đề xuất" badge.
        case suggested
        /// Added by the user.
        case user
    }

    public var bundleID: String
    /// Name to show when the app cannot be found on this Mac (e.g. a suggested rule for
    /// an app that is not installed). The app's own localized name is preferred.
    public var displayName: String?
    /// Use marked text (underlined) instead of replacing in place (D13).
    public var underline: Bool
    public var source: Source

    public var id: String { bundleID }

    public init(
        bundleID: String,
        displayName: String? = nil,
        underline: Bool = false,
        source: Source = .user
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.underline = underline
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, displayName, underline, source
    }

    /// Lenient like `DauSettings`: only `bundleID` is required; unknown keys (such as the
    /// old `"mode"`) are ignored.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let bundleID = try c.decode(String.self, forKey: .bundleID)
        guard !bundleID.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .bundleID, in: c, debugDescription: "empty bundle ID")
        }
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        self.init(
            bundleID: bundleID,
            displayName: value(.displayName, nil as String?),
            underline: value(.underline, false),
            source: value(.source, .user)
        )
    }
}
