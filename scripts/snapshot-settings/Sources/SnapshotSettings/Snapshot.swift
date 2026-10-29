import AppKit
import SwiftUI
import DauShared

/// Renders SwiftUI views in an off-screen window and writes PNGs.
@MainActor
enum Snapshot {
    static func render<V: View>(_ view: V, to url: URL, dark: Bool,
                                size: CGSize = CGSize(width: 820, height: 600), settle: Int = 30) {
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view)
        host.appearance = window.appearance
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        for _ in 0..<settle {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }
        // Capture the window's frame view: it draws the window background and the
        // toolbar, which the hosting view alone does not.
        let frameView = host.superview ?? host
        frameView.display()
        let bounds = frameView.convert(host.bounds, from: host)
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        frameView.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try data.write(to: url)
            print(url.path)
        } catch {
            print("cannot write \(url.path): \(error)")
        }
        window.orderOut(nil)
    }

    /// Settings with the rules from the mockup ("SettingsApps").
    static func sampleSettings() -> DauSettings {
        var s = DauSettings.defaults
        s.upsert(AppRule(bundleID: "com.apple.Terminal", displayName: "Terminal",
                         mode: .english, underline: true, source: .suggested))
        s.upsert(AppRule(bundleID: "com.microsoft.VSCode", displayName: "Visual Studio Code",
                         mode: .english, source: .suggested))
        s.upsert(AppRule(bundleID: "com.google.Chrome", displayName: "Google Chrome", source: .suggested))
        s.upsert(AppRule(bundleID: "com.tinyspeck.slackmacgap", displayName: "Slack"))
        s.upsert(AppRule(bundleID: "com.microsoft.Word", displayName: "Microsoft Word"))
        return s
    }
}
