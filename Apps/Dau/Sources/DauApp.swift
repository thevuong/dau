import AppKit
import SwiftUI
import DauShared

/// Host app: the Settings window (M4). Onboarding (M5) and updates (M7) come later.
///
/// The Settings window is the app's main window, so opening Dấu (from Finder or from
/// the input menu's "Cài đặt Dấu…") shows it. ⌘, reopens it after it was closed.
@main
struct DauApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = SettingsModel.appGroup()
    @State private var inputSource = InputSourceStatus()

    var body: some Scene {
        Window(Text("Cài đặt Dấu"), id: SettingsScene.id) {
            SettingsWindow()
                .environment(model)
                .environment(inputSource)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SettingsCommands()
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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Dấu has no other window; closing Settings quits, like System Settings.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
