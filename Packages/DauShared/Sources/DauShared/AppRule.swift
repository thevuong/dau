// A per-app rule (D5, D13).

/// What Dấu does in one app, identified by bundle ID. A rule always applies (D5),
/// whether the user added it or it came from the compatibility list.
public struct AppRule: Sendable, Codable, Equatable, Hashable, Identifiable {
    /// Input mode to switch to when the app becomes active.
    public enum Mode: String, Sendable, Codable, CaseIterable {
        /// "Tiếng Việt".
        case vietnamese
        /// "Tiếng Anh".
        case english
    }

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
    public var mode: Mode
    /// Use marked text (underlined) instead of replacing in place (D13).
    public var underline: Bool
    public var source: Source

    public var id: String { bundleID }

    public init(
        bundleID: String,
        displayName: String? = nil,
        mode: Mode = .vietnamese,
        underline: Bool = false,
        source: Source = .user
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.mode = mode
        self.underline = underline
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, displayName, mode, underline, source
    }

    /// Lenient like `DauSettings`: only `bundleID` is required.
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
            mode: value(.mode, .vietnamese),
            underline: value(.underline, false),
            source: value(.source, .user)
        )
    }
}
