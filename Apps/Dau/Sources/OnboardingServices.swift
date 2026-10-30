import AppKit
import Carbon

// Services the onboarding window (D14) calls through protocols, so the real install
// service (M5 T3) plugs in without touching the views, and previews, captures and tests
// run on fakes. This file holds the read-only parts only: detecting other Vietnamese
// input methods (NSWorkspace) and reading Dấu's status (Text Input Sources). Copying,
// registering and enabling the input method are T3's.

// MARK: - Other Vietnamese input methods (step 1)

/// Another Vietnamese input method found on this Mac.
struct DetectedInputMethod: Identifiable, Equatable, Sendable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    let isRunning: Bool
    /// How to quit it and keep it from starting again, one line per step (N4: Dấu only
    /// explains, it never quits other apps or edits login items).
    let quitSteps: [String]
}

/// Finds other Vietnamese input methods installed or running.
@MainActor
protocol OldInputMethodDetector {
    func detect() -> [DetectedInputMethod]
}

/// The input methods step 1 looks for, in one place.
///
/// TODO(M5 T1): the researcher delivers the verified bundle IDs and the exact menu
/// wording of each app (docs/research/M5-INSTALL.md). Only OpenKey's ID is checked, in
/// its project file (`PRODUCT_BUNDLE_IDENTIFIER`); the others are best guesses. The
/// quit steps follow the mockup and are not verified per app yet (N5).
enum KnownInputMethods {
    struct Entry: Sendable {
        let name: String
        let bundleIDs: [String]
    }

    static let all: [Entry] = [
        Entry(name: "OpenKey", bundleIDs: ["com.tuyenmai.openkey"]),
        Entry(name: "EVKey", bundleIDs: ["com.lamquangminh.evkey"]),
        Entry(name: "GoTiengViet", bundleIDs: ["com.trankynam.GoTiengViet"]),
    ]

    /// Mockup "OnboardingConflict": quit from the menu bar, then remove the login item.
    static func quitSteps(for name: String) -> [String] {
        [
            String(localized: "Bấm biểu tượng \(name) trên thanh menu, chọn Thoát"),
            String(localized: "Trong Cài đặt hệ thống › Chung › Mục đăng nhập, tắt \(name)"),
        ]
    }
}

/// Real detector: running apps and installed apps by bundle ID, read only.
@MainActor
struct WorkspaceInputMethodDetector: OldInputMethodDetector {
    var entries: [KnownInputMethods.Entry] = KnownInputMethods.all

    func detect() -> [DetectedInputMethod] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return entries.compactMap { entry in
            let isRunning = entry.bundleIDs.contains(where: running.contains)
            let installedID = entry.bundleIDs.first {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
            }
            guard let bundleID = entry.bundleIDs.first(where: running.contains) ?? installedID else { return nil }
            return DetectedInputMethod(name: entry.name, bundleID: bundleID, isRunning: isRunning,
                                       quitSteps: KnownInputMethods.quitSteps(for: entry.name))
        }
    }
}

/// Fixed answers, for previews, captures and tests.
@MainActor
final class FakeInputMethodDetector: OldInputMethodDetector {
    var found: [DetectedInputMethod]
    init(_ found: [DetectedInputMethod] = []) { self.found = found }
    func detect() -> [DetectedInputMethod] { found }

    static func running(_ name: String, bundleID: String = "com.example.ime") -> DetectedInputMethod {
        DetectedInputMethod(name: name, bundleID: bundleID, isRunning: true,
                            quitSteps: KnownInputMethods.quitSteps(for: name))
    }
}

// MARK: - Dấu's own input method (step 2)

/// Where Dấu's input source stands in the system.
enum InputMethodStatus: Equatable, Sendable {
    /// Cannot be read (no input method bundle inside the app): nothing is claimed (N5).
    case unknown
    case notInstalled
    /// Installed in ~/Library/Input Methods but not in the user's input sources.
    /// `version` is nil when it cannot be read.
    case installed(version: String?)
    /// Among the enabled input sources.
    case enabled
    /// Enabled and the current input source.
    case selected

    var isEnabled: Bool { self == .enabled || self == .selected }
}

enum InputMethodInstallerError: Error, Equatable {
    /// The action is not available in this build (read-only service, until M5 T3).
    case unavailable
    case failed(String)
}

/// Installs and enables Dấu's input method. The user starts every action (N4); enabling
/// can be undone.
@MainActor
protocol InputMethodInstaller: AnyObject {
    func status() -> InputMethodStatus
    /// Copies the input method bundled in the app to ~/Library/Input Methods and
    /// registers it.
    func install() async throws
    /// Adds "Dấu – Tiếng Việt" to the user's input sources.
    func enable() async throws
    /// Removes it again, right after `enable()`.
    func undoEnable() async throws
    /// Removes the input method (D16).
    func uninstall() async throws
}

/// Real status, read only, from Text Input Sources (`InputSourceStatus`). Every action
/// throws `.unavailable`: M5 T3 replaces this with the real service.
@MainActor
final class ReadOnlyInputMethodInstaller: InputMethodInstaller {
    func status() -> InputMethodStatus {
        guard let installed = InputSourceStatus.queryInstalled() else { return .unknown }
        guard installed else { return .notInstalled }
        if InputSourceStatus.querySelected() == true { return .selected }
        if InputSourceStatus.query() == true { return .enabled }
        // TODO(M5 T3): the installed version, from the bundle in ~/Library/Input Methods.
        return .installed(version: nil)
    }

    func install() async throws { throw InputMethodInstallerError.unavailable }
    func enable() async throws { throw InputMethodInstallerError.unavailable }
    func undoEnable() async throws { throw InputMethodInstallerError.unavailable }
    func uninstall() async throws { throw InputMethodInstallerError.unavailable }
}

/// In-memory installer for previews, captures and tests. Records the calls it gets.
@MainActor
final class FakeInputMethodInstaller: InputMethodInstaller {
    var current: InputMethodStatus
    var failure: InputMethodInstallerError?
    private(set) var calls: [String] = []

    init(_ status: InputMethodStatus = .notInstalled, failure: InputMethodInstallerError? = nil) {
        current = status
        self.failure = failure
    }

    func status() -> InputMethodStatus { current }

    func install() async throws {
        calls.append("install")
        if let failure { throw failure }
        if current == .notInstalled || current == .unknown { current = .installed(version: nil) }
    }

    func enable() async throws {
        calls.append("enable")
        if let failure { throw failure }
        guard current != .notInstalled else { throw InputMethodInstallerError.failed("not installed") }
        if !current.isEnabled { current = .enabled }
    }

    func undoEnable() async throws {
        calls.append("undoEnable")
        if let failure { throw failure }
        current = .installed(version: nil)
    }

    func uninstall() async throws {
        calls.append("uninstall")
        if let failure { throw failure }
        current = .notInstalled
    }
}

// MARK: - Text Input Sources, read only

extension InputSourceStatus {
    /// Whether the input method is installed (registered with Text Input Sources,
    /// enabled or not). `nil` when the bundle is not found inside the app.
    nonisolated static func queryInstalled() -> Bool? {
        guard let bundleID = inputMethodBundleID else { return nil }
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else { return false }
        return CFArrayGetCount(list) > 0
    }

    /// Whether Dấu is the current input source. `nil` when unknown.
    nonisolated static func querySelected() -> Bool? {
        guard let bundleID = inputMethodBundleID,
              let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return nil }
        let current = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        return current == bundleID
    }

    /// Localized name of an enabled keyboard layout other than Dấu, e.g. "ABC": the one
    /// the user switches to for English (D2). `nil` when there is none to name.
    nonisolated static func englishLayoutName() -> String? {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
                      kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        func string(_ source: TISInputSource, _ key: CFString) -> String? {
            TISGetInputSourceProperty(source, key).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
        }
        func isEnglish(_ source: TISInputSource) -> Bool {
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
            let languages = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String] ?? []
            return languages.first == "en"
        }
        // An English layout first (ABC, U.S.…), else any other layout.
        let ordered = list.filter(isEnglish) + list.filter { !isEnglish($0) }
        return ordered.lazy.compactMap { string($0, kTISPropertyLocalizedName) }.first { !$0.isEmpty }
    }
}
