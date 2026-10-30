import AppKit
import SwiftUI

/// The Settings window's input method actions: "Bật lại" on the "Dấu chưa được bật"
/// banner (with "Hoàn tác", N4) and "Gỡ cài đặt…" (D16) with its confirmation. Views
/// get it from the environment; nil there (snapshots) leaves the old behavior: "Bật lại"
/// opens Keyboard settings and "Gỡ cài đặt…" is disabled.
@MainActor
@Observable
final class InputMethodActions {
    /// What the banner shows after "Bật lại".
    enum BannerState: Equatable {
        case idle
        case working
        /// Dấu was enabled from the banner: a confirmation with "Hoàn tác".
        case enabled
        /// The calls went through, TIS still reports Dấu off: Keyboard settings opened.
        case notEnabled
        case failed
    }

    private(set) var banner: BannerState = .idle
    private(set) var isUninstalling = false

    @ObservationIgnored let installer: InputMethodInstaller
    @ObservationIgnored private let openKeyboardSettings: () -> Void

    init(installer: InputMethodInstaller, openKeyboardSettings: @escaping () -> Void = SystemSettings.openKeyboard) {
        self.installer = installer
        self.openKeyboardSettings = openKeyboardSettings
    }

    /// "Bật lại". Returns true when the onboarding window should take over: the input
    /// method is not installed, or macOS does not list it yet (first install, logout).
    func enableFromBanner() async -> Bool {
        guard banner != .working else { return false }
        banner = .working
        switch installer.status() {
        case .notInstalled:
            banner = .idle
            return true
        case .unknown:
            // No input method inside the app: nothing to enable here (N4: guide only).
            banner = .idle
            openKeyboardSettings()
            return false
        case .enabled, .selected:
            banner = .idle
            return false
        case .installed:
            break
        }
        do {
            switch try await installer.enable() {
            case .enabled:
                banner = .enabled
            case .notEnabled:
                banner = .notEnabled
                openKeyboardSettings()
            case .notListed:
                banner = .idle
                return true
            }
        } catch {
            banner = .failed
        }
        return false
    }

    /// "Hoàn tác" on the banner after "Bật lại".
    func undoBannerEnable() async {
        guard banner == .enabled else { return }
        banner = .working
        do {
            try await installer.undoEnable()
            banner = .idle
        } catch {
            banner = .failed
        }
    }

    /// The input sources changed: once Dấu is on (e.g. the user added it in Keyboard
    /// settings) the "not enabled" guidance is no longer true.
    func inputSourcesChanged(isEnabled: Bool?) {
        if isEnabled == true, banner == .notEnabled || banner == .failed { banner = .idle }
    }

    // MARK: Uninstall (D16)

    /// "Gỡ cài đặt…": confirmation alert, then the removal and its result.
    func confirmUninstall(in window: NSWindow?) {
        guard !isUninstalling else { return }
        let (alert, deleteData) = UninstallAlert.confirmation()
        UninstallAlert.present(alert, in: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            let delete = deleteData.state == .on
            Task { await self.uninstall(deleteSettings: delete, window: window) }
        }
    }

    func uninstall(deleteSettings: Bool, window: NSWindow?) async {
        isUninstalling = true
        defer { isUninstalling = false }
        do {
            let report = try await installer.uninstall(deleteSettings: deleteSettings)
            UninstallAlert.present(UninstallAlert.done(report), in: window) { _ in
                // The input method is gone; this app would only offer to install it
                // again. It quits; the user removes Dấu.app from Applications.
                NSApp.terminate(nil)
            }
        } catch {
            installLogger.error("event=uninstall-failed error=\(String(describing: error), privacy: .public)")
            UninstallAlert.present(UninstallAlert.failed(), in: window) { _ in }
        }
    }
}

extension EnvironmentValues {
    @Entry var inputMethodActions: InputMethodActions?
}

/// The uninstall alerts (mockup "ConfirmDialogs", "Gỡ Dấu khỏi máy?"): a system alert
/// with the app icon, a checkbox and stacked buttons, the destructive one first. The
/// buttons' look is the system's (D9): macOS 27 draws a destructive button as red text
/// on a red tint, the mockup as white on red.
@MainActor
enum UninstallAlert {
    /// The confirmation, and its "Xoá cả cài đặt và quy tắc ứng dụng" checkbox (off).
    static func confirmation() -> (NSAlert, NSButton) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Gỡ Dấu khỏi máy?")
        // N5: whether the keyboard used before Dấu stays selected is checked in M5 T4
        // (docs/research/M5-INSTALL.md section 4); until then the sentence is a placeholder.
        alert.informativeText = String(localized: "Dấu sẽ bị xoá khỏi Nguồn nhập liệu. [Bàn phím đang dùng trước đó được giữ nguyên — kiểm chứng ở M5 T4]")
        let remove = alert.addButton(withTitle: String(localized: "Gỡ cài đặt"))
        remove.hasDestructiveAction = true
        // Return must not remove Dấu: no default button; Esc cancels.
        remove.keyEquivalent = ""
        let cancel = alert.addButton(withTitle: String(localized: "Huỷ"))
        cancel.keyEquivalent = "\u{1b}"
        alert.showsSuppressionButton = true
        let checkbox = alert.suppressionButton!
        checkbox.title = String(localized: "Xoá cả cài đặt và quy tắc ứng dụng")
        checkbox.state = .off
        return (alert, checkbox)
    }

    static func done(_ report: UninstallReport) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = String(localized: "Đã gỡ bộ gõ Dấu")
        var lines: [String] = []
        if report.movedToTrash {
            lines.append(String(localized: "Bộ gõ đã được chuyển vào Thùng rác."))
        }
        if let keyboard = report.switchedTo {
            lines.append(String(localized: "Nguồn nhập liệu hiện tại: “\(keyboard)”."))
        }
        if report.stillEnabled {
            lines.append(String(localized: "macOS vẫn báo Dấu trong Nguồn nhập liệu; bạn có thể bỏ nó trong Cài đặt Bàn phím."))
        }
        if report.dataDeleted {
            lines.append(String(localized: "Đã xoá cài đặt và quy tắc ứng dụng."))
        }
        lines.append(String(localized: "Muốn xoá cả ứng dụng, kéo Dấu trong thư mục Ứng dụng vào Thùng rác."))
        alert.informativeText = lines.joined(separator: " ")
        alert.addButton(withTitle: String(localized: "Thoát Dấu"))
        return alert
    }

    static func failed() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Chưa gỡ được Dấu")
        alert.informativeText = String(localized: "Bạn có thể bỏ “Dấu – Tiếng Việt” trong Cài đặt Bàn phím › Nguồn đầu vào, rồi thử lại.")
        alert.addButton(withTitle: String(localized: "OK"))
        return alert
    }

    /// App-modal, centered: the mockup's alert (app icon, centered text, stacked
    /// buttons) is how macOS 26+ draws an app-modal alert; as a sheet it is
    /// left-aligned with side-by-side buttons. `window` is brought forward first.
    static func present(_ alert: NSAlert, in window: NSWindow?, then handler: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        window?.makeKeyAndOrderFront(nil)
        // After the button's action returns, so SwiftUI is not inside a modal loop.
        DispatchQueue.main.async {
            MainActor.assumeIsolated { handler(alert.runModal()) }
        }
    }
}
