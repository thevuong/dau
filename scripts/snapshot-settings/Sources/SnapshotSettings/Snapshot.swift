import AppKit
import SwiftUI
import DauShared

/// Frames reported by the app's `layoutProbe` modifiers, in window points (top-left).
@MainActor
final class ProbeLog {
    var frames: [String: CGRect] = [:]
}

/// An off-screen window that draws as the key, main window, so controls and the
/// sidebar selection show their active look (accent colors) as in the mockup.
final class ActiveLookWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

/// Renders SwiftUI views in an off-screen window and writes PNGs.
@MainActor
enum Snapshot {
    struct Result {
        let rep: NSBitmapImageRep
        let frames: [String: CGRect]
        let scale: CGFloat
    }

    @discardableResult
    static func render<V: View>(_ view: V, to url: URL?, appearance: NSAppearance.Name,
                                size: CGSize = CGSize(width: 820, height: 600), settle: Int = 30) -> Result? {
        let log = ProbeLog()
        let window = ActiveLookWindow(contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: appearance)
        let root = view
            .environment(\.layoutProbe) { name, frame in log.frames[name] = frame }
            .environment(\.appearsActive, true)
        let host = NSHostingView(rootView: root)
        host.appearance = window.appearance
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        for _ in 0..<settle {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }
        // The window's frame view draws the window background and title bar too.
        let frameView = host.superview ?? host
        frameView.display()
        let bounds = frameView.convert(host.bounds, from: host)
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        frameView.cacheDisplay(in: bounds, to: rep)
        if let url, let data = rep.representation(using: .png, properties: [:]) {
            do {
                try data.write(to: url)
                print(url.path)
            } catch {
                print("cannot write \(url.path): \(error)")
            }
        }
        // Traffic lights, in the same top-left window coordinates as the probes.
        var frames = log.frames
        for (name, kind) in [("close", NSWindow.ButtonType.closeButton), ("zoom", .zoomButton)] {
            if let button = window.standardWindowButton(kind), let superview = button.superview {
                let r = superview.convert(button.frame, to: nil)
                frames[name] = CGRect(x: r.minX, y: size.height - r.maxY, width: r.width, height: r.height)
            }
        }
        window.orderOut(nil)
        return Result(rep: rep, frames: frames, scale: CGFloat(rep.pixelsWide) / size.width)
    }

    /// Raw sRGB bytes of one pixel (the capture's bytes are sRGB values even though the
    /// bitmap is tagged Display P3; converting would shift mid-grays).
    static func pixel(_ result: Result, at point: CGPoint) -> (r: Double, g: Double, b: Double) {
        var p = [Int](repeating: 0, count: 4)
        let x = min(max(Int(point.x * result.scale), 0), result.rep.pixelsWide - 1)
        let y = min(max(Int(point.y * result.scale), 0), result.rep.pixelsHigh - 1)
        result.rep.getPixel(&p, atX: x, y: y)
        return (Double(p[0]) / 255, Double(p[1]) / 255, Double(p[2]) / 255)
    }

    /// Writes bitmaps side by side, top-aligned, with a gap.
    static func sideBySide(_ reps: [NSBitmapImageRep], to url: URL) {
        let gap = 40
        let w = reps.map(\.pixelsWide).reduce(0, +) + gap * (reps.count - 1)
        let h = reps.map(\.pixelsHigh).max() ?? 0
        guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        NSColor.gray.setFill()
        CGRect(x: 0, y: 0, width: w, height: h).fill()
        var x = 0
        for rep in reps {
            rep.draw(in: CGRect(x: x, y: h - rep.pixelsHigh, width: rep.pixelsWide, height: rep.pixelsHigh))
            x += rep.pixelsWide + gap
        }
        NSGraphicsContext.restoreGraphicsState()
        if let data = out.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
            print(url.path)
        }
    }

    /// Writes images side by side in a grid.
    static func grid(_ images: [URL], columns: Int, to url: URL) {
        let loaded = images.compactMap { NSImage(contentsOf: $0) }
        guard let first = loaded.first?.representations.first else { return }
        let w = first.pixelsWide, h = first.pixelsHigh
        let rows = (loaded.count + columns - 1) / columns
        guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * columns, pixelsHigh: h * rows,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        for (i, image) in loaded.enumerated() {
            let col = i % columns, row = i / columns
            image.draw(in: CGRect(x: col * w, y: (rows - 1 - row) * h, width: w, height: h))
        }
        NSGraphicsContext.restoreGraphicsState()
        if let data = out.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
            print(url.path)
        }
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

/// WCAG contrast ratio of two sRGB colors.
func contrastRatio(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
    func lum(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func ch(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }
    let la = lum(a), lb = lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

/// `color` (with alpha) resolved under `appearance` and composited over `background`.
@MainActor
func composite(_ color: NSColor, over background: (r: Double, g: Double, b: Double),
               appearance: NSAppearance.Name) -> (r: Double, g: Double, b: Double) {
    var c = color
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        c = color.usingColorSpace(.sRGB) ?? color
    }
    let a = Double(c.alphaComponent)
    return (Double(c.redComponent) * a + background.r * (1 - a),
            Double(c.greenComponent) * a + background.g * (1 - a),
            Double(c.blueComponent) * a + background.b * (1 - a))
}
