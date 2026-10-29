import AppKit
import SwiftUI
import DauShared

let arguments = CommandLine.arguments.dropFirst()
let outDir = URL(fileURLWithPath: arguments.first ?? FileManager.default.currentDirectoryPath, isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

NSApplication.shared.setActivationPolicy(.accessory)

MainActor.assumeIsolated {
    // A throwaway suite so snapshots never touch real settings.
    let suite = "dau.snapshot-settings"
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    let store = SettingsStore(defaults: UserDefaults(suiteName: suite) ?? .standard, suiteName: suite)
    store.save(Snapshot.sampleSettings())
    let model = SettingsModel(store: store)
    let enabled = InputSourceStatus(fixed: true)
    let notEnabled = InputSourceStatus(fixed: false)

    @MainActor func window(_ section: SettingsSection, _ status: InputSourceStatus) -> some View {
        SettingsWindow(initialSection: section).environment(model).environment(status)
    }

    for dark in [false, true] {
        let mode = dark ? "dark" : "light"
        func file(_ name: String) -> URL { outDir.appendingPathComponent("\(name)-\(mode).png") }

        Snapshot.render(window(.typing, enabled), to: file("typing"), dark: dark)
        Snapshot.render(window(.typing, notEnabled), to: file("typing-not-enabled"), dark: dark)
        Snapshot.render(window(.smart, enabled), to: file("smart"), dark: dark)
        Snapshot.render(
            NavigationStack { SmartSettingsView(advancedExpanded: true).navigationTitle(SettingsSection.smart.title) }
                .environment(model).environment(enabled),
            to: file("smart-advanced"), dark: dark, size: CGSize(width: 600, height: 680))
        Snapshot.render(window(.apps, enabled), to: file("apps"), dark: dark)
        Snapshot.render(AddAppRuleSheet().environment(model),
                        to: file("apps-add-sheet"), dark: dark, size: CGSize(width: 460, height: 520), settle: 60)
        Snapshot.render(window(.updates, enabled), to: file("updates"), dark: dark)
    }
}
