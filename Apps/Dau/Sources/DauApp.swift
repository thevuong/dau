import SwiftUI
import DauShared

/// Host app. M0 scaffold only: a Settings scene placeholder.
/// The real Settings window (sidebar, 4 sections), onboarding and updates come in M4/M5/M7.
@main
struct DauApp: App {
    var body: some Scene {
        Settings {
            SettingsPlaceholderView()
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Cài đặt")
            .padding()
            .frame(minWidth: 320, minHeight: 200)
    }
}
