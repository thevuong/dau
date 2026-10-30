import AppKit
import SwiftUI
import DauShared

/// Host app: the Settings window (M4) and the onboarding window (M5). Updates (M7)
/// come later. The entry point is main.swift, which pins the localization first.
///
/// The Settings window is the app's main window, so opening Dấu from Finder shows it;
/// the input menu's "Cài đặt Dấu…" item is meant to open the app the same way. ⌘,
/// reopens it after it was closed. At launch, while Dấu is not installed or not enabled,
/// the onboarding window opens instead (`LaunchRouter`); "Trợ giúp › Hướng dẫn thiết
/// lập…" opens it at any time.
struct DauApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = SettingsModel.appGroup()
    @State private var inputSource = DauApp.makeInputSourceStatus()
    @State private var onboarding: OnboardingFlow
    private let opensOnboarding: Bool

    init() {
        let (flow, opens) = DauApp.makeOnboarding()
        _onboarding = State(initialValue: flow)
        opensOnboarding = opens
    }

    /// The onboarding flow on the real services, and whether it opens at launch.
    @MainActor
    private static func makeOnboarding() -> (OnboardingFlow, Bool) {
        let installer = ReadOnlyInputMethodInstaller()
        var flow = OnboardingFlow(detector: WorkspaceInputMethodDetector(), installer: installer)
        var opens = LaunchRouter.opensOnboarding(installer.status())
        #if DEBUG
        if DebugCapture.directory != nil { opens = false }
        if let step = DebugCapture.onboardingStep {
            // `--onboarding <1|2|3>`: open onboarding at that step.
            flow.forcedStartStep = step
            opens = true
        }
        if DebugCapture.onboardingDirectory != nil {
            // `--capture-onboarding <dir>`: fixed services, so every step has content.
            let detector = FakeInputMethodDetector([FakeInputMethodDetector.running("OpenKey", bundleID: "com.tuyenmai.openkey")])
            DebugCapture.onboardingDetector = detector
            flow = OnboardingFlow(
                detector: detector,
                installer: FakeInputMethodInstaller(.installed(version: nil)),
                shortcut: DebugCapture.shortcutOverride ?? InputSourceShortcut.read)
            opens = true
        }
        DebugCapture.onboardingFlow = flow
        #endif
        return (flow, opens)
    }

    private static func makeInputSourceStatus() -> InputSourceStatus {
        #if DEBUG
        // `--not-enabled`: show the "Dấu chưa được bật" banner (window captures).
        if CommandLine.arguments.contains("--not-enabled") { return InputSourceStatus(fixed: false) }
        #endif
        return InputSourceStatus()
    }

    var body: some Scene {
        Window(Text("Cài đặt Dấu"), id: SettingsScene.id) {
            SettingsWindow()
                .environment(model)
                .environment(inputSource)
                #if DEBUG
                .environment(\.layoutProbe, DebugCapture.probe)
                #endif
                .modifier(LaunchRouting(opens: opensOnboarding))
        }
        .defaultSize(width: 820, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            SettingsCommands()
        }

        Window(Text("Thiết lập Dấu"), id: OnboardingScene.id) {
            OnboardingWindow()
                .environment(onboarding)
                .environment(model)
                #if DEBUG
                .environment(\.layoutProbe, DebugCapture.probe)
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Opens the onboarding window instead of Settings at launch when `opens` is true.
/// SwiftUI opens the first window scene (Settings) by itself; this swaps it on its first
/// appearance, once per launch.
struct LaunchRouting: ViewModifier {
    let opens: Bool
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @MainActor private static var routed = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !Self.routed else { return }
            Self.routed = true
            guard opens else { return }
            openWindow(id: OnboardingScene.id)
            dismissWindow(id: SettingsScene.id)
        }
    }
}

enum SettingsScene {
    static let id = "settings"
}

/// Replaces the standard "Settings…" item so ⌘, opens the Settings window.
struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Cài đặt…") { openWindow(id: SettingsScene.id) }
                .keyboardShortcut(",", modifiers: .command)
        }
        // Dấu has no help book: the Help menu holds the setup guide instead.
        CommandGroup(replacing: .help) {
            Button("Hướng dẫn thiết lập…") { openWindow(id: OnboardingScene.id) }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        DebugCapture.start()
        DebugCapture.startOnboarding()
        #endif
    }

    /// Closing the last window (Settings or onboarding) quits, like System Settings.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
