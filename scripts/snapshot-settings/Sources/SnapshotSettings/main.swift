import AppKit
import SwiftUI
import DauShared

// Usage: SnapshotSettings <output-dir>
// Writes every page in light, dark and increased-contrast appearance, the 2×2 grid of
// the four sections, and prints the layout measurements and hint contrast. Exits 1 if
// the layout moves between sections.

// Positional arguments only: skip "-Key value" pairs such as -AppleShowScrollBars Always.
var arguments: [String] = []
var skipNext = false
for arg in CommandLine.arguments.dropFirst() {
    if skipNext { skipNext = false; continue }
    if arg.hasPrefix("-") { skipNext = true; continue }
    arguments.append(arg)
}
let outDir = URL(fileURLWithPath: arguments.first ?? FileManager.default.currentDirectoryPath, isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

NSApplication.shared.setActivationPolicy(.accessory)

let failed: Bool = MainActor.assumeIsolated {
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

    let appearances: [(String, NSAppearance.Name)] = [
        ("light", .aqua), ("dark", .darkAqua),
        ("light-high-contrast", .accessibilityHighContrastAqua),
        ("dark-high-contrast", .accessibilityHighContrastDarkAqua),
    ]
    var measured: [(String, [String: CGRect])] = []
    var contrast: [(String, Double, Double)] = []

    for (mode, appearance) in appearances {
        func file(_ name: String) -> URL { outDir.appendingPathComponent("\(name)-\(mode).png") }
        for section in SettingsSection.allCases {
            let result = Snapshot.render(window(section, enabled), to: file(section.rawValue), appearance: appearance)
            if let result {
                if mode == "light" { measured.append((section.rawValue, result.frames)) }
                if section == .typing, let row = result.frames["firstRow"] {
                    // Card background just left of the first row's content, inside the card.
                    let bg = Snapshot.pixel(result, at: CGPoint(x: row.minX - 6, y: row.midY))
                    let secondary = composite(.secondaryLabelColor, over: bg, appearance: appearance)
                    let primary = composite(.labelColor, over: bg, appearance: appearance)
                    contrast.append((mode, contrastRatio(secondary, bg), contrastRatio(primary, bg)))
                }
            }
        }
        Snapshot.render(window(.typing, notEnabled), to: file("typing-not-enabled"), appearance: appearance)
        Snapshot.render(
            window(.smart, enabled).environment(\.smartAdvancedExpanded, true),
            to: file("smart-advanced"), appearance: appearance, size: CGSize(width: 820, height: 680))
        Snapshot.render(AddAppRuleSheet().environment(model).frame(width: 460, height: 520),
                        to: file("apps-add-sheet"), appearance: appearance,
                        size: CGSize(width: 460, height: 520), settle: 60)
    }

    Snapshot.grid(SettingsSection.allCases.map { outDir.appendingPathComponent("\($0.rawValue)-light.png") },
                  columns: 2, to: outDir.appendingPathComponent("sections-grid.png"))
    Snapshot.grid(SettingsSection.allCases.map { outDir.appendingPathComponent("\($0.rawValue)-dark.png") },
                  columns: 2, to: outDir.appendingPathComponent("sections-grid-dark.png"))

    // Layout: the same in every section, to the point.
    func f(_ r: CGRect?) -> String {
        guard let r else { return "—" }
        return String(format: "x %.0f y %.0f w %.0f h %.0f", r.minX, r.minY, r.width, r.height)
    }
    let keys = ["window", "sidebar", "header", "title", "form", "firstRow"]
    print("\nLayout (points, window 820×600, light):")
    print(([("section", "")] + keys.map { ($0, "") }).map(\.0).joined(separator: " | "))
    for (section, frames) in measured {
        print(([section] + keys.map { f(frames[$0]) }).joined(separator: " | "))
    }
    var moved = false
    for key in keys where key != "firstRow" && key != "title" {
        let values = Set(measured.compactMap { $0.1[key] }.map { "\($0)" })
        if values.count > 1 { moved = true; print("MOVED: \(key) \(values)") }
    }
    // Title and first row: same origin and width; height may differ with content.
    for key in ["title", "firstRow"] {
        // Title: same origin (its width is the text's). First row: same x and width
        // (its y depends on whether the first group has a header).
        let values = Set(measured.compactMap { $0.1[key] }.map {
            key == "title" ? "\($0.minX),\($0.minY)" : "\($0.minX),\($0.width)"
        })
        if values.count > 1 { moved = true; print("MOVED: \(key) \(values)") }
    }
    print(moved ? "Layout: MOVES between sections" : "Layout: identical in all sections")

    print("\nHint contrast on the card (WCAG):")
    for (mode, secondary, primary) in contrast {
        print(String(format: "%@: secondary %.2f:1, primary %.2f:1", mode, secondary, primary))
    }
    return moved
}
exit(failed ? 1 : 0)
