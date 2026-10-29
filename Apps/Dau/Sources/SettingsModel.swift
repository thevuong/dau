import Foundation
import Observation
import DauShared
import os

/// The host app's view of the shared settings. Every change is saved right away to the
/// App Group suite, which posts the change notification the input method listens to.
/// Changes made elsewhere (the input method's "Kiểu gõ" menu) are reloaded the same way.
@MainActor
@Observable
final class SettingsModel {
    var settings: DauSettings {
        didSet {
            guard settings != oldValue, !isReloading else { return }
            store.save(settings)
        }
    }

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var observer: SettingsChangeObserver?
    @ObservationIgnored private var isReloading = false

    init(store: SettingsStore) {
        self.store = store
        self.settings = store.load()
        observer = store.observeChanges { [weak self] in
            // Delivered on the main queue (observeChanges default).
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    /// The App Group store declared in Info.plist. Falls back to the app's own defaults
    /// when no App Group is available, so Settings stays usable; the input method will
    /// not see those changes.
    static func appGroup() -> SettingsModel {
        if let store = SettingsStore.appGroup() {
            return SettingsModel(store: store)
        }
        Logger.settings.error("No App Group suite; settings stay local to the app")
        return SettingsModel(store: SettingsStore(
            defaults: .standard, suiteName: Bundle.main.bundleIdentifier ?? "Dau"))
    }

    private func reload() {
        let loaded = store.load()
        guard loaded != settings else { return }
        isReloading = true
        settings = loaded
        isReloading = false
    }
}

extension Logger {
    static let settings = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dau", category: "settings")
}
