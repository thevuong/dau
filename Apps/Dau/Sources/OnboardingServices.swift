import AppKit
import Carbon

// Services the onboarding window (D14) and the Settings window call through protocols,
// so previews, captures and tests run on fakes: detecting other Vietnamese input methods
// (NSWorkspace, Text Input Sources) and installing, enabling, upgrading and removing
// Dấu's input method (`SystemInputMethodInstaller`, InputMethodInstaller.swift).

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

/// Finds other Vietnamese input methods.
@MainActor
protocol OldInputMethodDetector {
    /// Key-intercepting apps (event taps) installed or running. Only running ones clash
    /// with Dấu: they change keys whatever input source is selected.
    func detect() -> [DetectedInputMethod]
    /// Names of other Vietnamese input sources enabled in the system (Apple's
    /// Vietnamese input modes, another IMK input method). They only handle keys while
    /// selected, so they never type over Dấu: a soft note, not a block (D14).
    func otherVietnameseSources() -> [String]
}

/// The key-intercepting input methods step 1 looks for, with the bundle IDs read from
/// each app's released Info.plist (docs/research/M5-INSTALL.md section 5, 30/10/2026).
/// Matched by bundle ID, never by process name. UniKey, VietKey and Laban Key have no
/// macOS app. XKey also installs an IMK input method (`com.codetay.inputmethod.XKey`,
/// process `XKeyIM`): as an input source it is only a soft note
/// (`otherVietnameseSources`), so it is not listed here.
enum KnownInputMethods {
    struct Entry: Sendable {
        let name: String
        let bundleIDs: [String]
        /// Steps verified for this app (research section 5); nil: the generic steps.
        let steps: [String]?
    }

    static let all: [Entry] = [
        Entry(name: "OpenKey", bundleIDs: ["com.tuyenmai.openkey"], steps: [
            String(localized: "Trong “Bảng điều khiển…” của OpenKey, tắt “Khởi động cùng macOS”"),
            String(localized: "Bấm biểu tượng OpenKey trên thanh menu, chọn “Thoát”"),
            loginItemsStep("OpenKey"),
        ]),
        Entry(name: "EVKey", bundleIDs: ["com.lamquangminh.evkey"], steps: nil),
        Entry(name: "GoTiengViet", bundleIDs: ["com.trankynam.GoTiengViet"], steps: nil),
        Entry(name: "XKey", bundleIDs: ["com.codetay.XKey"], steps: [
            String(localized: "Trong cài đặt của XKey, tắt “Khởi động cùng hệ thống”"),
            String(localized: "Chọn “Thoát XKey” trong menu của XKey"),
            loginItemsStep("XKey"),
        ]),
        Entry(name: "PHTV", bundleIDs: ["com.phamhungtien.phtv"], steps: [
            String(localized: "Trong cài đặt của PHTV, tắt “Khởi động cùng macOS”"),
            String(localized: "Thoát PHTV"),
            loginItemsStep("PHTV"),
        ]),
        Entry(name: "Gõ Nhanh", bundleIDs: ["org.gonhanh.GoNhanh"], steps: [
            String(localized: "Trong cài đặt của Gõ Nhanh, tắt “Launch at login”"),
            String(localized: "Thoát Gõ Nhanh"),
            loginItemsStep("Gõ Nhanh"),
        ]),
        Entry(name: "GoKey", bundleIDs: ["com.goxkey.app"], steps: nil),
    ]

    /// The steps shown for `name`: the verified ones, or generic ones that claim no
    /// menu wording (N5).
    static func quitSteps(for name: String) -> [String] {
        all.first { $0.name == name }?.steps ?? [
            String(localized: "Thoát \(name)"),
            loginItemsStep(name),
        ]
    }

    /// System Settings path on macOS 27.2 (research section 2.5).
    static func loginItemsStep(_ name: String) -> String {
        String(localized: "Nếu \(name) tự mở lại: Cài đặt hệ thống › Cài đặt chung › Mục đăng nhập & Phần mở rộng, tắt \(name)")
    }
}

/// Real detector, read only: running apps of this user session (NSWorkspace) and
/// installed apps by bundle ID; enabled input sources (Text Input Sources).
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

    func otherVietnameseSources() -> [String] {
        InputSourceStatus.otherVietnameseSourceNames()
    }
}

/// Fixed answers, for previews, captures and tests.
@MainActor
final class FakeInputMethodDetector: OldInputMethodDetector {
    var found: [DetectedInputMethod]
    var otherSources: [String]
    init(_ found: [DetectedInputMethod] = [], otherSources: [String] = []) {
        self.found = found
        self.otherSources = otherSources
    }
    func detect() -> [DetectedInputMethod] { found }
    func otherVietnameseSources() -> [String] { otherSources }

    static func running(_ name: String, bundleID: String = "com.example.ime") -> DetectedInputMethod {
        DetectedInputMethod(name: name, bundleID: bundleID, isRunning: true,
                            quitSteps: KnownInputMethods.quitSteps(for: name))
    }
}

// MARK: - Dấu's own input method (step 2, Settings)

/// Where Dấu's input source stands in the system.
enum InputMethodStatus: Equatable, Sendable {
    /// Cannot be read (no input method bundle inside the app): nothing is claimed (N5).
    case unknown
    case notInstalled
    /// Installed in ~/Library/Input Methods but "Dấu – Tiếng Việt" is not among the
    /// enabled input sources. `version` is nil when it cannot be read.
    case installed(version: String?)
    /// Among the enabled input sources.
    case enabled
    /// Enabled and the current input source.
    case selected

    var isEnabled: Bool { self == .enabled || self == .selected }
}

enum InputMethodInstallerError: Error, Equatable {
    /// The action is not available (no input method bundle inside the app).
    case unavailable
    /// The input method inside the app is not validly signed by the app's own team.
    case invalidSignature
    case failed(String)
}

/// What Text Input Sources reports after "Bật Dấu" (N4: re-read, never assumed).
enum EnableOutcome: Equatable, Sendable {
    /// "Dấu – Tiếng Việt" is among the enabled input sources.
    case enabled
    /// The calls went through but the source is still off (macOS may wait for the user
    /// to allow it, or ignore the call: docs/research/M5-INSTALL.md section 2.2).
    case notEnabled
    /// Text Input Sources does not list Dấu at all: a first install shows up only after
    /// logging out and in once (D37).
    case notListed
}

/// What `upgradeIfNeeded` did (D7, D37).
enum UpgradeOutcome: Equatable, Sendable {
    /// Nothing installed (the first install is the user's, from onboarding).
    case notInstalled
    case upToDate
    case upgraded(from: String?, to: String)
    /// Not replaced: the installed bundle has another identity (D37: IDs never change).
    case skipped(String)
}

/// What `uninstall` did (D16), for the result alert.
struct UninstallReport: Equatable, Sendable {
    /// The keyboard selected first because Dấu was the current input source, when it
    /// reads back as the current source.
    var switchedTo: String?
    /// The input method bundle was moved to the Trash (false: it was not installed).
    var movedToTrash = false
    /// One of Dấu's sources still reads as enabled afterwards.
    var stillEnabled = false
    /// The App Group settings were deleted (the user ticked the box).
    var dataDeleted = false
}

/// Installs, enables, upgrades and removes Dấu's input method. The user starts enable,
/// undo and uninstall (N4); enabling can be undone; results are read back from Text
/// Input Sources (N5).
@MainActor
protocol InputMethodInstaller: AnyObject {
    func status() -> InputMethodStatus
    /// Copies the input method bundled in the app to ~/Library/Input Methods and
    /// registers it.
    func install() async throws
    /// Adds "Dấu – Tiếng Việt" to the user's input sources, then reads it back.
    func enable() async throws -> EnableOutcome
    /// Disables what `enable()` turned on.
    func undoEnable() async throws
    /// Replaces an older installed input method with the one in the app (D7).
    func upgradeIfNeeded() async throws -> UpgradeOutcome
    /// Removes the input method (D16); `deleteSettings` also deletes the App Group data.
    func uninstall(deleteSettings: Bool) async throws -> UninstallReport
}

/// In-memory installer for previews, captures and tests. Records the calls it gets.
@MainActor
final class FakeInputMethodInstaller: InputMethodInstaller {
    var current: InputMethodStatus
    var failure: InputMethodInstallerError?
    /// What the next `enable()` reports.
    var enableOutcome: EnableOutcome = .enabled
    var uninstallReport = UninstallReport()
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

    func enable() async throws -> EnableOutcome {
        calls.append("enable")
        if let failure { throw failure }
        guard current != .notInstalled else { throw InputMethodInstallerError.failed("not installed") }
        if enableOutcome == .enabled, !current.isEnabled { current = .enabled }
        return enableOutcome
    }

    func undoEnable() async throws {
        calls.append("undoEnable")
        if let failure { throw failure }
        current = .installed(version: nil)
    }

    func upgradeIfNeeded() async throws -> UpgradeOutcome {
        calls.append("upgrade")
        if let failure { throw failure }
        return .upToDate
    }

    func uninstall(deleteSettings: Bool) async throws -> UninstallReport {
        calls.append(deleteSettings ? "uninstall+data" : "uninstall")
        if let failure { throw failure }
        current = .notInstalled
        return uninstallReport
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

    /// Localized names of enabled, selectable Vietnamese input sources that are not
    /// Dấu's (Apple's Telex/VNI modes, XKeyIM…), for step 2's soft note.
    nonisolated static func otherVietnameseSourceNames() -> [String] {
        let filter = [kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        func string(_ source: TISInputSource, _ key: CFString) -> String? {
            TISGetInputSourceProperty(source, key).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
        }
        return list.compactMap { source in
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
                  (Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue() as? [String])?.first == "vi",
                  string(source, kTISPropertyBundleID) != inputMethodBundleID,
                  let type = string(source, kTISPropertyInputSourceType),
                  type == (kTISTypeKeyboardInputMode as String) || type == (kTISTypeKeyboardInputMethodWithoutModes as String)
            else { return nil }
            return string(source, kTISPropertyLocalizedName)
        }
    }
}
