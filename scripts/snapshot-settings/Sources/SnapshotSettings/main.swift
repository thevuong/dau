import AppKit
import SwiftUI
import DauShared

// Usage: SnapshotSettings <output-dir> [<artboard-dir>]
// - Renders every page in light, dark and high-contrast appearance, the 2×2 grids of
//   the four sections, and checks that the layout does not move between sections
//   (exit 1 if it does).
// - With <artboard-dir> (the canvas export holding Settings*.dc.html), also renders
//   each artboard and writes "<page>-compare-<mode>.png" (mockup | app) plus a table
//   of measurements, mockup against app.
// - With <real-capture-dir> (written by the Debug app: Dau --capture-window <dir>),
//   the app side of the comparisons uses those captures of the real SwiftUI scene and
//   its frames.json: this hand-made window does not reproduce the scene's chrome,
//   system colors and control sizes exactly.

var arguments: [String] = []
var skipNext = false
for arg in CommandLine.arguments.dropFirst() {
    if skipNext { skipNext = false; continue }
    if arg.hasPrefix("-") { skipNext = true; continue }   // -Key value pairs
    arguments.append(arg)
}
let outDir = URL(fileURLWithPath: arguments.first ?? FileManager.default.currentDirectoryPath, isDirectory: true)
let artboards = arguments.count > 1 ? URL(fileURLWithPath: arguments[1], isDirectory: true) : nil
let realDir = arguments.count > 2 ? URL(fileURLWithPath: arguments[2], isDirectory: true) : nil

/// A real-window capture and its probe frames, if present.
func realCapture(_ key: String) -> (NSBitmapImageRep, [String: CGRect])? {
    guard let realDir,
          let rep = NSBitmapImageRep(data: (try? Data(contentsOf: realDir.appendingPathComponent("\(key).png"))) ?? Data()),
          let json = try? JSONSerialization.jsonObject(with: Data(contentsOf: realDir.appendingPathComponent("frames.json"))) as? [String: [String: [Double]]]
    else { return nil }
    var frames: [String: CGRect] = [:]
    for (name, v) in json[key] ?? [:] where v.count == 4 { frames[name] = CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
    return (rep, frames)
}
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
    let window820 = CGSize(width: 820, height: 600)

    @MainActor func window(_ section: SettingsSection, _ status: InputSourceStatus) -> some View {
        SettingsWindow(initialSection: section).environment(model).environment(status)
    }

    let appearances: [(String, NSAppearance.Name)] = [
        ("light", .aqua), ("dark", .darkAqua),
        ("light-high-contrast", .accessibilityHighContrastAqua),
        ("dark-high-contrast", .accessibilityHighContrastDarkAqua),
    ]
    var measured: [(String, [String: CGRect])] = []
    var app: [String: Snapshot.Result] = [:]

    for (mode, appearance) in appearances {
        func file(_ name: String) -> URL { outDir.appendingPathComponent("\(name)-\(mode).png") }
        for section in SettingsSection.allCases {
            let result = Snapshot.render(window(section, enabled), to: file(section.rawValue), appearance: appearance)
            if let result {
                app["\(section.rawValue)-\(mode)"] = result
                if mode == "light" { measured.append((section.rawValue, result.frames)) }
            }
        }
        app["not-enabled-\(mode)"] = Snapshot.render(window(.typing, notEnabled), to: file("typing-not-enabled"),
                                                       appearance: appearance)
        app["smart-advanced-\(mode)"] = Snapshot.render(
            window(.smart, enabled).environment(\.smartAdvancedExpanded, true),
            to: file("smart-advanced"), appearance: appearance, size: CGSize(width: 820, height: 680))
    }

    Snapshot.grid(SettingsSection.allCases.map { outDir.appendingPathComponent("\($0.rawValue)-light.png") },
                  columns: 2, to: outDir.appendingPathComponent("sections-grid.png"))
    Snapshot.grid(SettingsSection.allCases.map { outDir.appendingPathComponent("\($0.rawValue)-dark.png") },
                  columns: 2, to: outDir.appendingPathComponent("sections-grid-dark.png"))

    // Layout: the same in every section, to the point.
    func f(_ r: CGRect?) -> String {
        guard let r else { return "—" }
        return String(format: "%.0f,%.0f %.0f×%.0f", r.minX, r.minY, r.width, r.height)
    }
    let same = ["window", "sidebar", "close", "zoom"]
    print("\nLayout (points, top-left origin, window 820×600, light):")
    print((["section"] + same + ["title", "firstCard"]).joined(separator: " | "))
    for (section, frames) in measured {
        print(([section] + (same + ["title", "firstCard"]).map { f(frames[$0]) }).joined(separator: " | "))
    }
    var moved = false
    func check(_ key: String, _ value: (CGRect) -> String) {
        let values = Set(measured.compactMap { $0.1[key] }.map(value))
        if values.count > 1 { moved = true; print("MOVED: \(key) \(values.sorted())") }
        if measured.contains(where: { $0.1[key] == nil }) { moved = true; print("MISSING: \(key)") }
    }
    for key in same { check(key) { "\($0)" } }
    // Positions must match; widths may differ only by a legacy scroll bar, and only on
    // a page that shows one.
    let legacyWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    for (section, frames) in measured {
        let r = frames["scrollRoom"]?.width ?? 0
        if abs(r) > 0.5 && abs(r - legacyWidth) > 0.5 { moved = true; print("SCROLL BAR: \(section) takes \(r) pt") }
    }
    func checkWidth(_ key: String, y: Bool) {
        let values = Set(measured.compactMap { item -> String? in
            guard let r = item.1[key] else { return nil }
            return "\(r.minX),\(y ? r.minY : 0),\(r.width + (item.1["scrollRoom"]?.width ?? 0))"
        })
        if values.count > 1 { moved = true; print("MOVED: \(key) \(values.sorted())") }
    }
    checkWidth("content", y: true)                         // height is the page's
    check("title") { "\($0.minX),\($0.minY)" }            // width is the text's
    checkWidth("firstCard", y: false)                      // y depends on a group title
    print(moved ? "Layout: MOVES between sections" : "Layout: identical in all sections")

    // Mockup against app.
    if let artboards {
        struct Board { let page: String; let file: String; let size: CGSize; let mode: String }
        let boards = [
            Board(page: "typing", file: "SettingsTyping", size: CGSize(width: 900, height: 680), mode: "light"),
            Board(page: "typing", file: "SettingsDark", size: CGSize(width: 900, height: 680), mode: "dark"),
            Board(page: "smart", file: "SettingsSmart", size: CGSize(width: 900, height: 680), mode: "light"),
            Board(page: "smart-advanced", file: "SettingsSmartAdvanced", size: CGSize(width: 900, height: 760), mode: "light"),
            Board(page: "apps", file: "SettingsApps", size: CGSize(width: 900, height: 680), mode: "light"),
            Board(page: "updates", file: "SettingsAbout", size: CGSize(width: 900, height: 680), mode: "light"),
            Board(page: "not-enabled", file: "SettingsNotEnabled", size: CGSize(width: 900, height: 680), mode: "light"),
        ]
        let measure = [
            "firstCard": "document.querySelector('main [role=status], main .card').getBoundingClientRect()",
            "segmented": "document.querySelector('main .seg') && document.querySelector('main .seg').getBoundingClientRect()",
            "switch": "document.querySelector('main .sw') && document.querySelector('main .sw').getBoundingClientRect()",
            "button": "document.querySelector('main .btn') && document.querySelector('main .btn').getBoundingClientRect()",
            "close": "document.querySelector('nav [aria-hidden=true] span').getBoundingClientRect()",
            "title": "(() => { const r = document.createRange(); r.selectNodeContents(document.querySelector('main header h1')); return r.getBoundingClientRect(); })()",
            "header": "document.querySelector('main header').getBoundingClientRect()",
            "sidebar": "document.querySelector('nav').getBoundingClientRect()",
            "headerSearch": "document.querySelector('main header label') && document.querySelector('main header label').getBoundingClientRect()",
            "headerAdd": "document.querySelector('main header .btn') && document.querySelector('main header .btn').getBoundingClientRect()",
        ]
        var rows: [String] = []
        for board in boards {
            let crop = CGRect(x: 40, y: 40, width: board.size.width - 80, height: board.size.height - 80)
            guard let mock = Mockup.render(artboards.appendingPathComponent("\(board.file).dc.html"),
                                           size: board.size, crop: crop, measure: measure),
                  let shot = app["\(board.page)-\(board.mode)"] else { print("cannot render \(board.file)"); continue }
            let real = realCapture("\(board.page)-\(board.mode)")
            if board.page == "apps", let realShot = real?.0 {
                // The Apps header (title, search field, +), 3×, against the real window.
                let header = CGRect(x: 220, y: 0, width: 600, height: 56)
                if let a = Snapshot.crop(mock.image, header, scale: 3), let b = Snapshot.crop(realShot, header, scale: 3) {
                    Snapshot.sideBySide([a, b], to: outDir.appendingPathComponent("apps-header-compare-\(board.mode).png"))
                }
                // No dark artboard exists for this page: the light mockup beside the dark app.
                if let dark = realCapture("apps-dark")?.0,
                   let a = Snapshot.crop(mock.image, header, scale: 3), let b = Snapshot.crop(dark, header, scale: 3) {
                    Snapshot.sideBySide([a, b], to: outDir.appendingPathComponent("apps-header-compare-dark.png"))
                }
                for key in ["headerSearch", "headerAdd"] {
                    rows.append("apps-\(board.mode) | \(key) | \(f(mock.frames[key])) | \(f(real?.1[key]))")
                }
            }
            if board.page == "typing" {
                // Sidebar only, 4×: the real-window capture does not draw the sidebar's
                // vibrant content, so the app side is this tool's window.
                let area = CGRect(x: 0, y: 0, width: 220, height: 280)
                if let a = Snapshot.crop(mock.image, area, scale: 4), let b = Snapshot.crop(shot.rep, area, scale: 4) {
                    Snapshot.sideBySide([a, b], to: outDir.appendingPathComponent("sidebar-compare-\(board.mode).png"))
                }
                // The "Kiểu gõ" card, 3×, against the real window when captured.
                let card = CGRect(x: 246, y: 214, width: 548, height: 140)
                if let a = Snapshot.crop(mock.image, card, scale: 3), let b = Snapshot.crop(real?.0 ?? shot.rep, card, scale: 3) {
                    Snapshot.sideBySide([a, b], to: outDir.appendingPathComponent("segmented-compare-\(board.mode).png"))
                }
            }
            Snapshot.sideBySide([mock.image, real?.0 ?? shot.rep],
                                to: outDir.appendingPathComponent("\(board.page)-compare-\(board.mode).png"))
            for key in ["close", "title", "firstCard", "segmented", "switch", "button"] {
                rows.append("\(board.page)-\(board.mode) | \(key) | \(f(mock.frames[key])) | \(f((real?.1 ?? shot.frames)[key]))")
            }
        }
        // The add-rule sheet: the dialog only.
        if let full = Mockup.render(artboards.appendingPathComponent("SettingsAppsAdd.dc.html"),
                                    size: CGSize(width: 900, height: 680), crop: .zero,
                                    measure: ["dialog": "document.querySelector('[role=dialog]').getBoundingClientRect()"]),
           let dialog = full.frames["dialog"] {
            let crop = dialog.integral
            for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let sheet = Snapshot.render(AddAppRuleSheet().environment(model).fixedSize(),
                                            to: outDir.appendingPathComponent("apps-add-sheet-\(mode).png"),
                                            appearance: appearance, size: CGSize(width: 460, height: crop.height),
                                            settle: 60)
                if mode == "light", let mock = Mockup.render(
                    artboards.appendingPathComponent("SettingsAppsAdd.dc.html"),
                    size: CGSize(width: 900, height: 680), crop: crop, measure: [:]), let sheet {
                    Snapshot.sideBySide([mock.image, sheet.rep],
                                        to: outDir.appendingPathComponent("apps-add-compare-light.png"))
                }
            }
        }
        print("\nMockup | app (points, window origin top-left):")
        print("page | element | mockup | app" + (realDir == nil ? " (snapshot window)" : " (real window)"))
        rows.forEach { print($0) }
    }
    _ = window820
    return moved
}
exit(failed ? 1 : 0)
