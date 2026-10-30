#if DEBUG
import AppKit
import ApplicationServices
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
        guard directory != nil || onboardingDirectory != nil else { return nil }
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
                    var scrollInfo: [String: [Double]] = [:]
                    if let offset = scrollOffset, let scrollView = pageScrollView(in: window) {
                        // `--scroll <pt>`: scroll the page down, flash the scroll bars
                        // (overlay style hides them otherwise), then capture.
                        let clip = scrollView.contentView
                        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: clip.bounds.origin.y + offset))
                        scrollView.reflectScrolledClipView(clip)
                        scrollView.flashScrollers()
                        try? await Task.sleep(for: .milliseconds(150))
                        scrollInfo = describe(scrollView, in: window)
                    }
                    capture(window, to: directory.appendingPathComponent("\(section.rawValue)-\(mode).png"))
                    var entry = frames.mapValues { [Double($0.minX), Double($0.minY), Double($0.width), Double($0.height)] }
                    for (key, kind) in [("close", NSWindow.ButtonType.closeButton), ("zoom", .zoomButton)] {
                        if let b = window.standardWindowButton(kind), let s = b.superview {
                            let r = s.convert(b.frame, to: nil)
                            entry[key] = [Double(r.minX), Double(window.frame.height - r.maxY), Double(r.width), Double(r.height)]
                        }
                    }
                    entry.merge(scrollInfo) { a, _ in a }
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

    // MARK: Onboarding

    /// `--onboarding <1|2|3>`: open the onboarding window at that step (real services).
    static let onboardingStep: OnboardingFlow.Step? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--onboarding"), i + 1 < args.count,
              let n = Int(args[i + 1]) else { return nil }
        return OnboardingFlow.Step(rawValue: n)
    }()

    /// `--capture-onboarding <dir>`: like `--capture-window`, for the onboarding window
    /// on fixed services (OpenKey running, Dấu installed but not enabled). Writes
    /// `onboarding-<step>-<mode>.png` for steps 1, 2, 2 after "Bật Dấu" (`2-enabled`) and
    /// 3, light and dark, plus `frames.json`.
    static let onboardingDirectory: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--capture-onboarding"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }()

    /// `--shortcut none|unknown`: pretend the input source shortcut reads so (captures).
    static let shortcutOverride: (() -> InputSourceShortcut.Reading)? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--shortcut"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "none": return { .none }
        case "unknown": return { .unknown }
        default: return nil
        }
    }()

    static var onboardingFlow: OnboardingFlow?
    static var onboardingDetector: FakeInputMethodDetector?

    static func startOnboarding() {
        guard let directory = onboardingDirectory else { return }
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task { @MainActor in
            // The window opens once the Settings window has appeared (LaunchRouting):
            // wait for it, up to 10 s.
            var found: NSWindow?
            for _ in 0..<50 where found == nil {
                try? await Task.sleep(for: .milliseconds(200))
                found = NSApp.windows.first { $0.isVisible && $0.title == String(localized: "Thiết lập Dấu") }
            }
            try? await Task.sleep(for: .milliseconds(500))
            guard let flow = onboardingFlow, let window = found else {
                print("no onboarding window:", NSApp.windows.map { "\($0.title) \($0.frame) visible=\($0.isVisible)" })
                exit(1)
            }
            window.setFrameOrigin(NSPoint(x: -9000, y: -9000))
            if CommandLine.arguments.contains("--active") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
            }
            var report: [String: [String: [Double]]] = [:]
            // Show another step first so step 1's probes report again; drop the
            // Settings window's probes.
            flow.show(.typing)
            try? await Task.sleep(for: .milliseconds(300))
            frames = frames.filter { $0.key.hasPrefix("onb") }
            for (mode, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                NSApp.appearance = NSAppearance(named: name)
                let openKey = onboardingDetector?.found ?? []
                flow.start()
                flow.tryText = ""
                let shots: [(String, @MainActor () async -> Void)] = [
                    ("1", { flow.show(.oldInputMethods) }),
                    // As in the mockup: the user quit OpenKey, step 1 is done.
                    ("2", { onboardingDetector?.found = []; flow.refresh(); flow.show(.enable) }),
                    ("2-enabled", { await flow.enable() }),
                    ("3", { flow.tryText = "Tôi yêu tiếng Việt"; flow.show(.typing) }),
                ]
                for (key, setUp) in shots {
                    // Probes report changes only: frames carry over between shots, the
                    // step's own views report again when the step changes.
                    await setUp()
                    try? await Task.sleep(for: .milliseconds(700))
                    capture(window, to: directory.appendingPathComponent("onboarding-\(key)-\(mode).png"))
                    // Step views name their probes "<name>-<step>": keep the shown step's.
                    var entry: [String: [Double]] = [:]
                    for (name, r) in frames {
                        let parts = name.split(separator: "-", maxSplits: 1).map(String.init)
                        if parts.count == 2 {
                            guard parts[1] == "\(flow.step.rawValue)" else { continue }
                            entry[parts[0]] = [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
                        } else {
                            entry[name] = [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
                        }
                    }
                    if let b = window.standardWindowButton(.closeButton), let s = b.superview {
                        let r = s.convert(b.frame, to: nil)
                        entry["close"] = [Double(r.minX), Double(window.frame.height - r.maxY), Double(r.width), Double(r.height)]
                    }
                    entry["window"] = [0, 0, Double(window.frame.width), Double(window.frame.height)]
                    report["onboarding-\(key)-\(mode)"] = entry
                    if mode == "light" {
                        try? await accessibilityTree(window).write(
                            to: directory.appendingPathComponent("onboarding-\(key)-accessibility.txt"),
                            atomically: true, encoding: .utf8)
                    }
                }
                await flow.undoEnable()
                onboardingDetector?.found = openKey
            }
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) {
                try? data.write(to: directory.appendingPathComponent("frames.json"))
            }
            print("captured to \(directory.path)")
            exit(0)
        }
    }

    /// The window's accessibility tree as VoiceOver gets it, one element per line:
    /// role, title/description, value, help, indented by depth. Uses the AX API on this
    /// process (SwiftUI builds its tree only for an AX client), from a background thread
    /// while the main thread keeps answering. Needs the Accessibility permission of the
    /// launching app (Terminal); empty without it.
    static func accessibilityTree(_ window: NSWindow) async -> String {
        let pid = ProcessInfo.processInfo.processIdentifier
        let title = window.title
        return await withCheckedContinuation { continuation in
            Thread.detachNewThread {
                continuation.resume(returning: axDump(pid: pid, windowTitle: title))
            }
        }
    }

    nonisolated private static func axDump(pid: pid_t, windowTitle: String) -> String {
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
        }
        func string(_ element: AXUIElement, _ name: String) -> String? {
            guard let value = attribute(element, name) else { return nil }
            if CFGetTypeID(value) == CFStringGetTypeID() { return value as? String }
            if CFGetTypeID(value) == CFNumberGetTypeID() || CFGetTypeID(value) == CFBooleanGetTypeID() { return "\(value)" }
            return nil
        }
        var lines: [String] = []
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 40 else { return }
            var parts = [string(element, kAXRoleAttribute) ?? "?"]
            for (key, name) in [("title", kAXTitleAttribute), ("desc", kAXDescriptionAttribute),
                                ("value", kAXValueAttribute), ("help", kAXHelpAttribute)] {
                if let v = string(element, name), !v.isEmpty { parts.append("\(key)=\"\(v)\"") }
            }
            if string(element, kAXEnabledAttribute) == "0" { parts.append("disabled") }
            lines.append(String(repeating: "  ", count: depth) + parts.joined(separator: " "))
            for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
                walk(child, depth: depth + 1)
            }
        }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 5)
        let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        guard let window = windows.first(where: { string($0, kAXTitleAttribute) == windowTitle }) ?? windows.first else {
            return "no AX window (trusted: \(AXIsProcessTrusted()))\n"
        }
        walk(window, depth: 0)
        return lines.joined(separator: "\n") + "\n"
    }

    /// `--scroll <pt>`.
    static let scrollOffset: CGFloat? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--scroll"), i + 1 < args.count, let v = Double(args[i + 1]) else { return nil }
        return CGFloat(v)
    }()

    /// The page's scroll view: the scroll view in the detail column with the tallest
    /// document (the sidebar's list is narrower than 300 pt).
    private static func pageScrollView(in window: NSWindow) -> NSScrollView? {
        var found: [NSScrollView] = []
        func walk(_ view: NSView) {
            if let s = view as? NSScrollView, s.frame.width > 300 { found.append(s) }
            view.subviews.forEach(walk)
        }
        if let root = window.contentView?.superview { walk(root) }
        return found.max { ($0.documentView?.frame.height ?? 0) < ($1.documentView?.frame.height ?? 0) }
    }

    /// Scroll view, clip and scroller frames (top-left window points), scroller style
    /// and visibility.
    private static func describe(_ scrollView: NSScrollView, in window: NSWindow) -> [String: [Double]] {
        let h = Double(window.frame.height)
        func r(_ v: NSView) -> [Double] {
            let f = v.convert(v.bounds, to: nil)
            return [Double(f.minX), h - Double(f.maxY), Double(f.width), Double(f.height)]
        }
        var out: [String: [Double]] = ["scrollView": r(scrollView), "clip": r(scrollView.contentView)]
        if let doc = scrollView.documentView { out["document"] = r(doc) }
        if let s = scrollView.verticalScroller {
            out["scroller"] = r(s)
            out["scrollerState"] = [s.isHidden ? 1 : 0, Double(s.alphaValue),
                                    scrollView.scrollerStyle == .overlay ? 1 : 0,
                                    scrollView.hasVerticalScroller ? 1 : 0]
        }
        out["insets"] = [Double(scrollView.contentInsets.top), Double(scrollView.contentView.bounds.origin.y)]
        return out
    }

    /// The window as the window server composites it (materials, scroll edge effects),
    /// through `CGWindowListCreateImage`, which needs no permission for the app's own
    /// windows. The function is unavailable to Swift in the macOS 15+ SDK, so it is
    /// looked up at run time; nil if it is gone.
    private static func compositedImage(_ window: NSWindow) -> CGImage? {
        typealias Create = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen(nil, RTLD_NOW), let sym = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(sym, to: Create.self)
        // kCGWindowListOptionIncludingWindow = 8; kCGWindowImageBoundsIgnoreFraming = 1,
        // kCGWindowImageBestResolution = 8.
        return create(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue()
    }

    private static func capture(_ window: NSWindow, to url: URL) {
        if let image = compositedImage(window) {
            let rep = NSBitmapImageRep(cgImage: image)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            return
        }
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
