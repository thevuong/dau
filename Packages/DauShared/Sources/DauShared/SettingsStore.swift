import Foundation
import notify

/// Reads and writes `DauSettings` in a `UserDefaults` suite and announces changes with
/// a Darwin notification, so the input method can apply them right away.
///
/// The host app and the input method open the same suite: the App Group identifier
/// found in each bundle's Info.plist under `appGroupInfoKey` (see project.yml,
/// `APP_GROUP_ID`). Settings are one JSON value under `settingsKey`, written in one
/// `set` call, so a reader never sees half of a change.
public struct SettingsStore: @unchecked Sendable {
    // @unchecked: `UserDefaults` is documented as thread-safe; the other stored
    // properties are immutable values.

    /// Info.plist key, present in both bundles, whose value is the App Group identifier.
    public static let appGroupInfoKey = "DauAppGroupIdentifier"
    /// UserDefaults key holding the JSON-encoded `DauSettings`.
    public static let settingsKey = "settings"

    public let defaults: UserDefaults
    /// Darwin notification posted after every `save`. Observers must re-read with
    /// `load()`; the notification carries no payload.
    public let changeNotificationName: String

    /// - Parameters:
    ///   - defaults: the suite to read and write.
    ///   - suiteName: the suite's name, used to derive `changeNotificationName` so two
    ///     installations with different App Groups never hear each other.
    public init(defaults: UserDefaults, suiteName: String) {
        self.defaults = defaults
        self.changeNotificationName = SettingsStore.changeNotificationName(suiteName: suiteName)
    }

    /// Name of the Darwin notification announcing a settings change in `suiteName`.
    public static func changeNotificationName(suiteName: String) -> String {
        suiteName + ".settingsDidChange"
    }

    /// The App Group identifier declared in `bundle`'s Info.plist, or `nil` when it is
    /// missing, empty, or an unexpanded build setting.
    public static func appGroupIdentifier(in bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    /// The store backed by the App Group suite of `bundle`, or `nil` if the bundle
    /// declares no App Group or the suite cannot be opened.
    public static func appGroup(bundle: Bundle = .main) -> SettingsStore? {
        guard let suite = appGroupIdentifier(in: bundle),
              let defaults = UserDefaults(suiteName: suite) else { return nil }
        return SettingsStore(defaults: defaults, suiteName: suite)
    }

    /// Current settings; D15 defaults when nothing was saved or the data is unreadable.
    public func load() -> DauSettings {
        guard let data = defaults.data(forKey: SettingsStore.settingsKey),
              let settings = try? JSONDecoder().decode(DauSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    /// Saves `settings` and posts `changeNotificationName`.
    public func save(_ settings: DauSettings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: SettingsStore.settingsKey)
        postChange()
    }

    /// Posts `changeNotificationName` as a Darwin notification (notify(3)), heard by
    /// every process, including the sandboxed input method.
    public func postChange() {
        notify_post(changeNotificationName)
    }

    /// Starts observing changes; `handler` runs on `queue`. Keep the returned object
    /// alive for as long as you want to be called. Returns `nil` if the system refuses
    /// the registration.
    public func observeChanges(
        on queue: DispatchQueue = .main,
        _ handler: @escaping @Sendable () -> Void
    ) -> SettingsChangeObserver? {
        SettingsChangeObserver(name: changeNotificationName, queue: queue, handler: handler)
    }
}

/// Calls a handler whenever the Darwin notification `name` is posted, by any process.
/// Observation stops when the object is released.
public final class SettingsChangeObserver: Sendable {
    public let name: String
    private let token: Int32

    init?(name: String, queue: DispatchQueue, handler: @escaping @Sendable () -> Void) {
        var token: Int32 = 0
        let status = notify_register_dispatch(name, &token, queue) { _ in handler() }
        guard status == NOTIFY_STATUS_OK else { return nil }
        self.name = name
        self.token = token
    }

    deinit {
        notify_cancel(token)
    }
}
