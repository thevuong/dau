import AppKit
import Carbon
import DauShared
import Security
import os

// The real `InputMethodInstaller` (M5, D14, D16, D37; docs/research/M5-INSTALL.md
// sections 2–4). It talks to the system through three narrow interfaces, so the order of
// operations and every failure path are tested with fakes
// (scripts/snapshot-settings/Tests/…/InputMethodInstallerTests.swift):
// - `InputMethodFiles`: the bundle inside the app and the copy in ~/Library/Input Methods;
// - `TextInputSources`: register, enable, disable, select, read back;
// - `InputMethodProcesses`: is the input method running, ask it to quit.
//
// N4: install copies Dấu's own files; enable, undo and uninstall run only from a button
// the user clicked ("Bật Dấu", "Bật lại", "Hoàn tác", "Gỡ cài đặt"); upgrade replaces
// Dấu's own bundle (D7). Dấu never selects itself as the input source.

let installLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Dau", category: "install")

// MARK: - Interfaces

/// What the installer needs from an input method bundle's Info.plist.
struct InputMethodBundleInfo: Equatable, Sendable {
    let bundleID: String
    /// CFBundleVersion, compared to decide on an upgrade.
    let version: String?
    /// CFBundleShortVersionString, for display.
    let shortVersion: String?
    /// Input mode IDs declared in ComponentInputModeDict.
    let modeIDs: [String]

    /// The Vietnamese mode (D2, D24: "….Dau.vi").
    var vietnameseModeID: String {
        modeIDs.first { $0.hasSuffix(".vi") } ?? bundleID + ".vi"
    }
}

@MainActor
protocol InputMethodFiles {
    /// The input method shipped inside the app; nil when missing or unreadable.
    var embedded: InputMethodBundleInfo? { get }
    /// Where the input method is installed (~/Library/Input Methods/DauInputMethod.app).
    var installedURL: URL { get }
    var isInstalled: Bool { get }
    /// The installed copy's Info.plist, read fresh from disk (no Bundle cache).
    var installed: InputMethodBundleInfo? { get }
    /// Copies the embedded bundle to a staging folder next to the destination, clears
    /// quarantine, checks the signature, then swaps it in place in one rename.
    func installEmbedded() throws
    func moveInstalledToTrash() throws
}

/// One input source as Text Input Sources reports it.
struct InputSourceEntry: Equatable, Sendable {
    let id: String
    let bundleID: String?
    /// An input mode (kTISTypeKeyboardInputMode), as opposed to the parent input method.
    let isMode: Bool
    let name: String
}

@MainActor
protocol TextInputSources: AnyObject {
    func register(_ url: URL) -> OSStatus
    /// Sources of `bundleID`; `includeDisabled` false returns the enabled ones only.
    func sources(bundleID: String, includeDisabled: Bool) -> [InputSourceEntry]
    func enable(_ id: String) -> OSStatus
    func disable(_ id: String) -> OSStatus
    func select(_ id: String) -> OSStatus
    func current() -> InputSourceEntry?
    /// An enabled ASCII-capable keyboard layout to select before Dấu goes away: the
    /// last-used one (`TISCopyCurrentASCIICapableKeyboardLayoutInputSource`), else the
    /// first enabled one; never one of `excludingBundleID`.
    func asciiKeyboard(excludingBundleID: String) -> InputSourceEntry?
}

@MainActor
protocol InputMethodProcesses: AnyObject {
    func isRunning(bundleID: String) -> Bool
    /// Darwin notification the input method exits on (`InputMethodLifecycle`).
    func requestQuit(bundleID: String)
    /// Last resort when the request is not heard (an input method older than the
    /// request): ends Dấu's own input method process, nothing else.
    func forceQuit(bundleID: String)
}

// MARK: - Installer

@MainActor
final class SystemInputMethodInstaller: InputMethodInstaller {
    private let files: InputMethodFiles
    private let sources: TextInputSources
    private let processes: InputMethodProcesses
    /// Deletes the App Group data (settings, app rules); true on success.
    private let deleteSharedData: @MainActor () -> Bool
    private let pause: @MainActor (Duration) async -> Void

    /// Source IDs `enable()` turned on (parent first), for `undoEnable()`. Kept across
    /// attempts: when macOS turns Dấu on later (after the user allowed it), undo still
    /// knows what to turn off.
    private(set) var enabledHere: [String] = []
    /// Read-backs after enabling, `rereadInterval` apart (TIS may settle late).
    var rereadAttempts = 5
    var rereadInterval: Duration = .milliseconds(300)
    /// How long the input method has to quit on request before it is ended.
    var quitTimeout: Duration = .seconds(2)
    private let pollInterval: Duration = .milliseconds(100)

    init(files: InputMethodFiles, sources: TextInputSources, processes: InputMethodProcesses,
         deleteSharedData: @escaping @MainActor () -> Bool,
         pause: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.files = files
        self.sources = sources
        self.processes = processes
        self.deleteSharedData = deleteSharedData
        self.pause = pause
    }

    /// The installer on the real system.
    static func standard() -> SystemInputMethodInstaller {
        SystemInputMethodInstaller(files: InputMethodBundleFiles.standard(),
                                   sources: SystemTextInputSources(),
                                   processes: SystemInputMethodProcesses(),
                                   deleteSharedData: SharedData.delete)
    }

    func status() -> InputMethodStatus {
        guard let embedded = files.embedded else { return .unknown }
        guard files.isInstalled else { return .notInstalled }
        let mode = embedded.vietnameseModeID
        guard isEnabled(mode, of: embedded.bundleID) else {
            return .installed(version: files.installed?.shortVersion)
        }
        return sources.current()?.id == mode ? .selected : .enabled
    }

    func install() async throws {
        guard let embedded = files.embedded else { throw InputMethodInstallerError.unavailable }
        try files.installEmbedded()
        installLogger.notice("event=installed version=\(embedded.version ?? "?", privacy: .public)")
        // A process still running from an older copy keeps the old code until it exits.
        await stopInputMethod(embedded.bundleID)
        let status = sources.register(files.installedURL)
        installLogger.notice("event=register status=\(status)")
        guard status == noErr else { throw InputMethodInstallerError.failed("TISRegisterInputSource \(status)") }
    }

    func enable() async throws -> EnableOutcome {
        guard let embedded = files.embedded else { throw InputMethodInstallerError.unavailable }
        guard files.isInstalled else { throw InputMethodInstallerError.failed("not installed") }
        let bundleID = embedded.bundleID, mode = embedded.vietnameseModeID

        var known = sources.sources(bundleID: bundleID, includeDisabled: true)
        if known.isEmpty {
            // Registered in another session, or never: register (harmless) and look again.
            _ = sources.register(files.installedURL)
            known = sources.sources(bundleID: bundleID, includeDisabled: true)
        }
        guard !known.isEmpty else {
            installLogger.notice("event=enable-not-listed")
            return .notListed
        }

        // The parent input method first, then the mode (TextInputSources.h).
        let enabledBefore = Set(sources.sources(bundleID: bundleID, includeDisabled: false).map(\.id))
        for id in [bundleID, mode] where known.contains(where: { $0.id == id }) && !enabledBefore.contains(id) {
            let status = sources.enable(id)
            installLogger.notice("event=enable id=\(id, privacy: .public) status=\(status)")
            if !enabledHere.contains(id) { enabledHere.append(id) }
        }

        // The status code proves nothing (noErr with the mode still off was reported on
        // macOS 27.0): read back (N4, N5).
        for attempt in 0..<max(1, rereadAttempts) {
            if isEnabled(mode, of: bundleID) { return .enabled }
            if attempt + 1 < rereadAttempts { await pause(rereadInterval) }
        }
        installLogger.notice("event=enable-still-off")
        return .notEnabled
    }

    func undoEnable() async throws {
        guard let embedded = files.embedded else { throw InputMethodInstallerError.unavailable }
        guard !enabledHere.isEmpty else { return }
        let bundleID = embedded.bundleID
        selectOtherKeyboardIfDauIsCurrent(bundleID: bundleID)
        // Mode before parent: the reverse of `enable()`.
        for id in enabledHere.reversed() {
            let status = sources.disable(id)
            installLogger.notice("event=undo-enable id=\(id, privacy: .public) status=\(status)")
        }
        enabledHere = []
        if isEnabled(embedded.vietnameseModeID, of: bundleID) {
            throw InputMethodInstallerError.failed("still enabled")
        }
    }

    func upgradeIfNeeded() async throws -> UpgradeOutcome {
        guard let embedded = files.embedded, files.isInstalled else { return .notInstalled }
        guard let installed = files.installed else {
            return .skipped("installed bundle unreadable")
        }
        guard installed.bundleID == embedded.bundleID else {
            // D37: IDs never change between versions; another identity means another
            // install, which needs the user (and a logout), not a silent swap.
            return .skipped("bundle ID \(installed.bundleID)")
        }
        guard let new = embedded.version, Self.isNewer(new, than: installed.version) else { return .upToDate }
        try files.installEmbedded()
        // The old process keeps the old code mapped: ask it to quit; macOS launches the
        // new bundle at the next key. Then register again (harmless, keeps TIS current).
        await stopInputMethod(embedded.bundleID)
        let status = sources.register(files.installedURL)
        installLogger.notice("event=upgraded from=\(installed.version ?? "?", privacy: .public) to=\(new, privacy: .public) register=\(status)")
        return .upgraded(from: installed.version, to: new)
    }

    func uninstall(deleteSettings: Bool) async throws -> UninstallReport {
        guard let embedded = files.embedded else { throw InputMethodInstallerError.unavailable }
        let bundleID = embedded.bundleID
        var report = UninstallReport()

        // 1. Dấu is the current source: select a keyboard first, so the system does not
        //    pick one by itself when Dấu goes away (research section 4).
        report.switchedTo = selectOtherKeyboardIfDauIsCurrent(bundleID: bundleID)

        // 2. Disable the modes, then the parent.
        let enabled = sources.sources(bundleID: bundleID, includeDisabled: false)
        for entry in enabled.filter(\.isMode) + enabled.filter({ !$0.isMode }) {
            let status = sources.disable(entry.id)
            installLogger.notice("event=uninstall-disable id=\(entry.id, privacy: .public) status=\(status)")
        }
        enabledHere = []

        // 3. Stop the input method, 4. move it to the Trash.
        await stopInputMethod(bundleID)
        if files.isInstalled {
            try files.moveInstalledToTrash()
            report.movedToTrash = true
        }

        // 5. The App Group data, only when asked.
        if deleteSettings {
            report.dataDeleted = deleteSharedData()
        }
        report.stillEnabled = !sources.sources(bundleID: bundleID, includeDisabled: false).isEmpty
        installLogger.notice("event=uninstalled switched=\(report.switchedTo != nil) stillEnabled=\(report.stillEnabled) dataDeleted=\(report.dataDeleted)")
        return report
    }

    // MARK: Helpers

    private func isEnabled(_ mode: String, of bundleID: String) -> Bool {
        sources.sources(bundleID: bundleID, includeDisabled: false).contains { $0.id == mode }
    }

    /// Selects an ASCII keyboard when Dấu is the current source. Returns its name.
    @discardableResult
    private func selectOtherKeyboardIfDauIsCurrent(bundleID: String) -> String? {
        guard sources.current()?.bundleID == bundleID else { return nil }
        guard let keyboard = sources.asciiKeyboard(excludingBundleID: bundleID) else {
            installLogger.error("event=no-ascii-keyboard")
            return nil
        }
        let status = sources.select(keyboard.id)
        installLogger.notice("event=select id=\(keyboard.id, privacy: .public) status=\(status)")
        // Named to the user only if it reads back as the current source (N5).
        return sources.current()?.id == keyboard.id ? keyboard.name : nil
    }

    /// Asks the input method to quit, waits up to `quitTimeout`, then ends it. Returns
    /// false if it still runs.
    @discardableResult
    private func stopInputMethod(_ bundleID: String) async -> Bool {
        guard processes.isRunning(bundleID: bundleID) else { return true }
        processes.requestQuit(bundleID: bundleID)
        var waited: Duration = .zero
        while waited < quitTimeout {
            await pause(pollInterval)
            waited += pollInterval
            if !processes.isRunning(bundleID: bundleID) { return true }
        }
        installLogger.notice("event=quit-timeout, ending the input method")
        processes.forceQuit(bundleID: bundleID)
        for _ in 0..<10 {
            await pause(pollInterval)
            if !processes.isRunning(bundleID: bundleID) { return true }
        }
        installLogger.error("event=still-running")
        return false
    }

    /// CFBundleVersion order ("1.10" > "1.9"); an unreadable installed version is older.
    nonisolated static func isNewer(_ candidate: String, than installed: String?) -> Bool {
        guard let installed else { return true }
        return candidate.compare(installed, options: .numeric) == .orderedDescending
    }
}

// MARK: - Files

/// The real bundle files. Directories are parameters so tests run on a temp folder.
struct InputMethodBundleFiles: InputMethodFiles {
    let embeddedURL: URL
    let directory: URL
    /// Signature check of the staged copy (default: valid, same team as this app).
    var verify: (URL) -> Bool = CodeSignature.isValidAndSameTeam
    /// Default: the user's Trash (`FileManager.trashItem`).
    var trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    static func standard() -> InputMethodBundleFiles {
        InputMethodBundleFiles(
            embeddedURL: Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Input Methods/DauInputMethod.app"),
            directory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods"))
    }

    /// Same file name as inside the app (D37: never changes).
    var installedURL: URL { directory.appendingPathComponent(embeddedURL.lastPathComponent) }

    var embedded: InputMethodBundleInfo? { Self.info(at: embeddedURL) }
    var installed: InputMethodBundleInfo? { Self.info(at: installedURL) }
    var isInstalled: Bool {
        (try? installedURL.checkResourceIsReachable()) == true
    }

    nonisolated static func info(at url: URL) -> InputMethodBundleInfo? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = dict["CFBundleIdentifier"] as? String, !bundleID.isEmpty else { return nil }
        let modes = (dict["ComponentInputModeDict"] as? [String: Any])?["tsInputModeListKey"] as? [String: Any]
        return InputMethodBundleInfo(bundleID: bundleID,
                                     version: dict["CFBundleVersion"] as? String,
                                     shortVersion: dict["CFBundleShortVersionString"] as? String,
                                     modeIDs: modes.map { $0.keys.sorted() } ?? [])
    }

    func installEmbedded() throws {
        let fm = FileManager.default
        guard (try? embeddedURL.checkResourceIsReachable()) == true else {
            throw InputMethodInstallerError.unavailable
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        // Hidden, no ".app": Text Input Sources does not pick up the staging copy.
        let staging = directory.appendingPathComponent(".DauInputMethod-staging-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: embeddedURL, to: staging)
        Quarantine.clear(staging)
        guard verify(staging) else { throw InputMethodInstallerError.invalidSignature }
        if fm.fileExists(atPath: installedURL.path) {
            // One atomic swap: the running process never sees half a bundle. The old
            // bundle ends up at `staging` and is removed by the defer above.
            guard renamex_np(staging.path, installedURL.path, UInt32(RENAME_SWAP)) == 0 else {
                throw InputMethodInstallerError.failed("swap errno \(errno)")
            }
        } else {
            guard renamex_np(staging.path, installedURL.path, UInt32(RENAME_EXCL)) == 0 else {
                throw InputMethodInstallerError.failed("rename errno \(errno)")
            }
        }
    }

    func moveInstalledToTrash() throws {
        try trash(installedURL)
    }
}

/// `com.apple.quarantine` on files the app copies (D37: an unsandboxed app may clear it).
enum Quarantine {
    static let attribute = "com.apple.quarantine"

    /// Removes the attribute from `url` and everything inside it.
    static func clear(_ url: URL) {
        removexattr(url.path, attribute, XATTR_NOFOLLOW)
        guard let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { return }
        for case let item as URL in items {
            removexattr(item.path, attribute, XATTR_NOFOLLOW)
        }
    }

    static func isSet(_ url: URL) -> Bool {
        getxattr(url.path, attribute, nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }
}

/// Code signature checks of the input method before it is installed.
enum CodeSignature {
    /// Valid signature (all architectures, nested code) by the same team as this app.
    static func isValidAndSameTeam(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return false }
        let flags = SecCSFlags(rawValue: SecCSFlags.RawValue(kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate))
        guard SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess else {
            installLogger.error("event=signature-invalid")
            return false
        }
        let theirs = teamID(of: code)
        let ours = hostTeamID()
        if theirs != ours {
            installLogger.error("event=signature-team-mismatch theirs=\(theirs ?? "-", privacy: .public) ours=\(ours ?? "-", privacy: .public)")
        }
        return theirs == ours
    }

    private static func teamID(of code: SecStaticCode) -> String? {
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: SecCSFlags.RawValue(kSecCSSigningInformation)), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private static func hostTeamID() -> String? {
        var me: SecCode?
        var staticMe: SecStaticCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me,
              SecCodeCopyStaticCode(me, [], &staticMe) == errSecSuccess, let staticMe else { return nil }
        return teamID(of: staticMe)
    }
}

/// The App Group data (settings and app rules, `SettingsStore`).
enum SharedData {
    /// Deletes the App Group suite and tells listeners. True on success.
    @MainActor
    static func delete() -> Bool {
        guard let suite = SettingsStore.appGroupIdentifier(),
              let store = SettingsStore.appGroup() else { return false }
        store.defaults.removePersistentDomain(forName: suite)
        store.postChange()
        return store.defaults.data(forKey: SettingsStore.settingsKey) == nil
    }
}

// MARK: - Text Input Sources

@MainActor
final class SystemTextInputSources: TextInputSources {
    func register(_ url: URL) -> OSStatus {
        TISRegisterInputSource(url as CFURL)
    }

    func sources(bundleID: String, includeDisabled: Bool) -> [InputSourceEntry] {
        list([kTISPropertyBundleID as String: bundleID], includeDisabled: includeDisabled).map(Self.entry)
    }

    func enable(_ id: String) -> OSStatus {
        guard let source = source(id) else { return OSStatus(paramErr) }
        return TISEnableInputSource(source)
    }

    func disable(_ id: String) -> OSStatus {
        guard let source = source(id) else { return OSStatus(paramErr) }
        return TISDisableInputSource(source)
    }

    func select(_ id: String) -> OSStatus {
        guard let source = source(id) else { return OSStatus(paramErr) }
        return TISSelectInputSource(source)
    }

    func current() -> InputSourceEntry? {
        TISCopyCurrentKeyboardInputSource().map { Self.entry($0.takeRetainedValue()) }
    }

    func asciiKeyboard(excludingBundleID: String) -> InputSourceEntry? {
        let enabledLayouts = list([kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
                                   kTISPropertyInputSourceIsASCIICapable as String: true,
                                   kTISPropertyInputSourceIsSelectCapable as String: true],
                                  includeDisabled: false).map(Self.entry)
            .filter { $0.bundleID != excludingBundleID }
        if let last = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().map({ Self.entry($0.takeRetainedValue()) }),
           enabledLayouts.contains(where: { $0.id == last.id }) {
            return last
        }
        return enabledLayouts.first
    }

    private func list(_ filter: [String: Any], includeDisabled: Bool) -> [TISInputSource] {
        TISCreateInputSourceList(filter as CFDictionary, includeDisabled)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private func source(_ id: String) -> TISInputSource? {
        list([kTISPropertyInputSourceID as String: id], includeDisabled: true).first
    }

    private static func entry(_ source: TISInputSource) -> InputSourceEntry {
        func string(_ key: CFString) -> String? {
            TISGetInputSourceProperty(source, key).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
        }
        return InputSourceEntry(id: string(kTISPropertyInputSourceID) ?? "",
                                bundleID: string(kTISPropertyBundleID),
                                isMode: string(kTISPropertyInputSourceType) == (kTISTypeKeyboardInputMode as String),
                                name: string(kTISPropertyLocalizedName) ?? "")
    }
}

// MARK: - Processes

@MainActor
final class SystemInputMethodProcesses: InputMethodProcesses {
    func isRunning(bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }

    func requestQuit(bundleID: String) {
        InputMethodLifecycle.requestQuit(inputMethodBundleID: bundleID)
    }

    func forceQuit(bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.forceTerminate()
        }
    }
}
