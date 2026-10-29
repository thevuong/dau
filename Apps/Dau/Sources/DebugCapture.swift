#if DEBUG
import AppKit
import SwiftUI

/// Debug only: `--capture-window <dir>` launches the real Settings scene, moves its
/// window off screen, and for light and dark mode and every section writes
/// `<section>-<mode>.png` (title bar included) plus `frames.json`: the layout probes,
/// the traffic lights, and system colors resolved in that window. The hand-made window
/// of `scripts/snapshot-settings` does not reproduce the SwiftUI scene's chrome and
/// colors exactly, so this is the reference for the real app. The sandbox only allows
/// writing inside the app's container: run it on a copy signed without the sandbox
/// entitlement.
@MainActor
enum DebugCapture {
    static let directory: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--capture-window"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }()

    static let selectSection = Notification.Name("DauDebugSelectSection")
    static var frames: [String: CGRect] = [:]

    /// The probe closure installed in the scene while capturing.
    static var probe: (@MainActor @Sendable (String, CGRect) -> Void)? {
        guard directory != nil else { return nil }
        return { @MainActor name, frame in DebugCapture.frames[name] = frame }
    }

    static func start() {
        guard let directory else { return }
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else {
                print("no window"); exit(1)
            }
            window.setFrame(NSRect(x: -9000, y: -9000, width: 820, height: 600), display: false)
            // `--active`: make the window key so controls draw their active look
            // (accent colors). Takes focus from the frontmost app for a few seconds.
            if CommandLine.arguments.contains("--active") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
            }
            // Start from another section so the first page's probes fire again.
            NotificationCenter.default.post(name: selectSection, object: SettingsSection.updates.rawValue)
            try? await Task.sleep(for: .milliseconds(400))
            var report: [String: [String: [Double]]] = [:]
            for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                NSApp.appearance = NSAppearance(named: name)
                for section in SettingsSection.allCases {
                    frames = [:]
                    NotificationCenter.default.post(name: selectSection, object: section.rawValue)
                    try? await Task.sleep(for: .milliseconds(900))
                    capture(window, to: directory.appendingPathComponent("\(section.rawValue)-\(mode).png"))
                    var entry = frames.mapValues { [Double($0.minX), Double($0.minY), Double($0.width), Double($0.height)] }
                    for (key, kind) in [("close", NSWindow.ButtonType.closeButton), ("zoom", .zoomButton)] {
                        if let b = window.standardWindowButton(kind), let s = b.superview {
                            let r = s.convert(b.frame, to: nil)
                            entry[key] = [Double(r.minX), Double(window.frame.height - r.maxY), Double(r.width), Double(r.height)]
                        }
                    }
                    report["\(section.rawValue)-\(mode)"] = entry
                }
                report["colors-\(mode)"] = colors(window.effectiveAppearance)
            }
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) {
                try? data.write(to: directory.appendingPathComponent("frames.json"))
            }
            print("captured to \(directory.path)")
            exit(0)
        }
    }

    private static func capture(_ window: NSWindow, to url: URL) {
        guard let frameView = window.contentView?.superview else { return }
        frameView.display()
        let bounds = frameView.bounds
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        frameView.cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// System colors resolved under the window's appearance, as sRGB + alpha.
    private static func colors(_ appearance: NSAppearance) -> [String: [Double]] {
        let list: [(String, NSColor)] = [
            ("windowBackground", .windowBackgroundColor), ("controlBackground", .controlBackgroundColor),
            ("underPageBackground", .underPageBackgroundColor), ("textBackground", .textBackgroundColor),
            ("control", .controlColor), ("separator", .separatorColor), ("secondaryLabel", .secondaryLabelColor),
            ("quaternarySystemFill", .quaternarySystemFill), ("tertiarySystemFill", .tertiarySystemFill),
            ("secondarySystemFill", .secondarySystemFill), ("systemFill", .systemFill),
            ("unemphasizedSelectedContentBackground", .unemphasizedSelectedContentBackgroundColor),
        ]
        var out: [String: [Double]] = [:]
        appearance.performAsCurrentDrawingAppearance {
            for (name, color) in list {
                if let c = color.usingColorSpace(.sRGB) {
                    out[name] = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)]
                }
            }
        }
        return out
    }
}
#endif
