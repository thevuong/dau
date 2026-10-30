import Foundation
import Testing
@testable import SnapshotSettings

// The installer's state machine (D14, D16, D37; docs/research/M5-INSTALL.md sections
// 2–4) on fake Text Input Sources, a fake process list and fake bundle files: the order
// of the system calls, read-backs, and failure paths. No test touches the real input
// sources or ~/Library/Input Methods; the file tests run in a temp folder.

private let imID = "com.codefastlabs.dau.inputmethod.Dau"
private let modeID = imID + ".vi"

/// Text Input Sources in memory. `log` records every call that changes something.
@MainActor
final class FakeTextInputSources: TextInputSources {
    struct Source { var entry: InputSourceEntry; var enabled: Bool }
    var all: [Source] = []
    var currentID: String?
    var log: [String] = []
    /// `enable` returns this status and changes nothing when false (the macOS 27.0
    /// report: noErr, mode still off).
    var enableTakesEffect = true
    var enableStatus: OSStatus = noErr
    /// What `register` makes appear (nothing: the source is not listed until logout).
    var registerAdds: [Source] = []
    /// Read-backs left before an enable that did not take effect turns on by itself
    /// (the user clicked "Cho phép" a bit later). nil: never.
    var turnsOnAfterReads: Int?

    static func dau(enabled: Bool = false) -> [Source] {
        [Source(entry: InputSourceEntry(id: imID, bundleID: imID, isMode: false, name: "Dấu"), enabled: enabled),
         Source(entry: InputSourceEntry(id: modeID, bundleID: imID, isMode: true, name: "Dấu – Tiếng Việt"), enabled: enabled)]
    }
    static let abc = Source(entry: InputSourceEntry(id: "com.apple.keylayout.ABC", bundleID: "com.apple.keylayout",
                                                    isMode: false, name: "ABC"), enabled: true)

    func register(_ url: URL) -> OSStatus {
        log.append("register")
        for s in registerAdds where !all.contains(where: { $0.entry.id == s.entry.id }) { all.append(s) }
        return noErr
    }

    func sources(bundleID: String, includeDisabled: Bool) -> [InputSourceEntry] {
        if !includeDisabled, var left = turnsOnAfterReads {
            left -= 1
            turnsOnAfterReads = left
            if left <= 0 {
                turnsOnAfterReads = nil
                for i in all.indices where all[i].entry.bundleID == imID { all[i].enabled = true }
            }
        }
        return all.filter { $0.entry.bundleID == bundleID && (includeDisabled || $0.enabled) }.map(\.entry)
    }

    func enable(_ id: String) -> OSStatus {
        log.append("enable \(id)")
        if enableTakesEffect, let i = all.firstIndex(where: { $0.entry.id == id }) { all[i].enabled = true }
        return enableStatus
    }

    func disable(_ id: String) -> OSStatus {
        log.append("disable \(id)")
        guard let i = all.firstIndex(where: { $0.entry.id == id }) else { return -50 }
        all[i].enabled = false
        if currentID == id { currentID = nil }
        return noErr
    }

    func select(_ id: String) -> OSStatus {
        log.append("select \(id)")
        currentID = id
        return noErr
    }

    func current() -> InputSourceEntry? {
        all.first { $0.entry.id == currentID }?.entry
    }

    func asciiKeyboard(excludingBundleID: String) -> InputSourceEntry? {
        all.first { $0.enabled && $0.entry.bundleID != excludingBundleID && $0.entry.id.contains("keylayout") }?.entry
    }
}

@MainActor
final class FakeProcesses: InputMethodProcesses {
    var running = false
    /// The process exits when asked (an input method that listens for the request).
    var honoursQuit = true
    var log: [String] = []

    func isRunning(bundleID: String) -> Bool { running }
    func requestQuit(bundleID: String) {
        log.append("requestQuit")
        if honoursQuit { running = false }
    }
    func forceQuit(bundleID: String) {
        log.append("forceQuit")
        running = false
    }
}

@MainActor
final class FakeFiles: InputMethodFiles {
    var embedded: InputMethodBundleInfo? = InputMethodBundleInfo(bundleID: imID, version: "2", shortVersion: "0.2.0", modeIDs: [modeID])
    var installed: InputMethodBundleInfo?
    var installedURL = URL(fileURLWithPath: "/tmp/does-not-matter/DauInputMethod.app")
    var isInstalled: Bool { installed != nil }
    var installError: InputMethodInstallerError?
    var trashError: InputMethodInstallerError?
    var log: [String] = []

    func installEmbedded() throws {
        log.append("copy")
        if let installError { throw installError }
        installed = embedded
    }

    func moveInstalledToTrash() throws {
        log.append("trash")
        if let trashError { throw trashError }
        installed = nil
    }
}

@MainActor
struct Rig {
    let files = FakeFiles()
    let tis = FakeTextInputSources()
    let processes = FakeProcesses()
    let installer: SystemInputMethodInstaller

    init(installed: InputMethodBundleInfo? = nil, sources: [FakeTextInputSources.Source] = []) {
        files.installed = installed
        tis.all = sources + [FakeTextInputSources.abc]
        let counter = Counter()
        self.counter = counter
        installer = SystemInputMethodInstaller(files: files, sources: tis, processes: processes,
                                               deleteSharedData: { counter.value += 1; return true },
                                               pause: { _ in })
    }

    let counter: Counter
    @MainActor final class Counter { var value = 0 }
}

@MainActor
@Suite("Input method installer (M5)")
struct InputMethodInstallerTests {
    let old = InputMethodBundleInfo(bundleID: imID, version: "1", shortVersion: "0.1.0", modeIDs: [modeID])

    // MARK: Status

    @Test("status: unknown without the bundle in the app, then installed, enabled, selected")
    func status() {
        let rig = Rig()
        rig.files.embedded = nil
        #expect(rig.installer.status() == .unknown)
        rig.files.embedded = old
        #expect(rig.installer.status() == .notInstalled)
        rig.files.installed = old
        rig.tis.all = FakeTextInputSources.dau()
        #expect(rig.installer.status() == .installed(version: "0.1.0"))
        // Only the parent on: the mode is what the user types with.
        rig.tis.all[0].enabled = true
        #expect(rig.installer.status() == .installed(version: "0.1.0"))
        rig.tis.all[1].enabled = true
        #expect(rig.installer.status() == .enabled)
        rig.tis.currentID = modeID
        #expect(rig.installer.status() == .selected)
    }

    // MARK: Install

    @Test("install: copy, stop the old process, register")
    func install() async throws {
        let rig = Rig()
        rig.processes.running = true
        try await rig.installer.install()
        #expect(rig.files.log == ["copy"])
        #expect(rig.processes.log == ["requestQuit"])
        #expect(rig.tis.log == ["register"])
        #expect(rig.files.isInstalled)
        // Installing never enables or selects anything (N4).
        #expect(!rig.tis.log.contains { $0.hasPrefix("enable") || $0.hasPrefix("select") })
    }

    @Test("install: a failed copy or a bad signature stops before registering")
    func installFails() async {
        for error in [InputMethodInstallerError.invalidSignature, .failed("disk full")] {
            let rig = Rig()
            rig.files.installError = error
            await #expect(throws: error) { try await rig.installer.install() }
            #expect(rig.tis.log.isEmpty)
        }
        let rig = Rig()
        rig.files.embedded = nil
        await #expect(throws: InputMethodInstallerError.unavailable) { try await rig.installer.install() }
        #expect(rig.files.log.isEmpty)
    }

    // MARK: Enable

    @Test("enable: parent then mode, read back as enabled")
    func enable() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau())
        #expect(try await rig.installer.enable() == .enabled)
        #expect(rig.tis.log == ["enable \(imID)", "enable \(modeID)"])
        #expect(rig.installer.enabledHere == [imID, modeID])
        #expect(rig.tis.currentID == nil)   // never selected (N4)
        #expect(rig.installer.status() == .enabled)
    }

    @Test("enable: noErr but TIS still off is reported as not enabled, never as success")
    func enableReturnsOkButStillOff() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau())
        rig.tis.enableTakesEffect = false
        rig.tis.enableStatus = noErr
        #expect(try await rig.installer.enable() == .notEnabled)
        #expect(rig.installer.status() == .installed(version: "0.1.0"))
        // Undo still knows what was asked for, if macOS turns it on later.
        #expect(rig.installer.enabledHere == [imID, modeID])
    }

    @Test("enable: turned on during the read-backs (the user allowed it) counts")
    func enableLate() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau())
        rig.tis.enableTakesEffect = false
        rig.tis.turnsOnAfterReads = 3
        #expect(try await rig.installer.enable() == .enabled)
    }

    @Test("enable: not listed in TIS at all → register once, then report a logout (D37)")
    func enableNotListed() async throws {
        let rig = Rig(installed: old)
        #expect(try await rig.installer.enable() == .notListed)
        #expect(rig.tis.log == ["register"])
        // Registering makes it appear (same session, same ID): enabled normally.
        let again = Rig(installed: old)
        again.tis.registerAdds = FakeTextInputSources.dau()
        #expect(try await again.installer.enable() == .enabled)
        #expect(again.tis.log == ["register", "enable \(imID)", "enable \(modeID)"])
    }

    @Test("enable: only what is off is turned on; nothing to undo when it was all on")
    func enableAlreadyOn() async throws {
        var sources = FakeTextInputSources.dau()
        sources[0].enabled = true
        let rig = Rig(installed: old, sources: sources)
        #expect(try await rig.installer.enable() == .enabled)
        #expect(rig.tis.log == ["enable \(modeID)"])
        try await rig.installer.undoEnable()
        #expect(rig.tis.log.last == "disable \(modeID)")
        #expect(rig.installer.status() == .installed(version: "0.1.0"))
        #expect(rig.tis.all[0].enabled)   // the parent was on before: left on
    }

    @Test("enable: not installed throws; nothing touched")
    func enableNotInstalled() async {
        let rig = Rig()
        await #expect(throws: InputMethodInstallerError.failed("not installed")) { try await rig.installer.enable() }
        #expect(rig.tis.log.isEmpty)
    }

    // MARK: Undo

    @Test("undo: mode before parent; switches keyboards first if Dấu got selected")
    func undo() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau())
        _ = try await rig.installer.enable()
        rig.tis.currentID = modeID
        rig.tis.log = []
        try await rig.installer.undoEnable()
        #expect(rig.tis.log == ["select com.apple.keylayout.ABC", "disable \(modeID)", "disable \(imID)"])
        #expect(rig.installer.enabledHere.isEmpty)
        // A second undo does nothing.
        try await rig.installer.undoEnable()
        #expect(rig.tis.log.count == 3)
    }

    // MARK: Upgrade

    @Test("upgrade: newer build → copy, stop the old process, register; IDs and enabled state kept")
    func upgrade() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau(enabled: true))
        rig.processes.running = true
        #expect(try await rig.installer.upgradeIfNeeded() == .upgraded(from: "1", to: "2"))
        #expect(rig.files.log == ["copy"])
        #expect(rig.processes.log == ["requestQuit"])
        #expect(rig.tis.log == ["register"])
        #expect(rig.installer.status() == .enabled)
    }

    @Test("upgrade: an input method that ignores the request is ended after the timeout")
    func upgradeForceQuit() async throws {
        let rig = Rig(installed: old)
        rig.processes.running = true
        rig.processes.honoursQuit = false
        _ = try await rig.installer.upgradeIfNeeded()
        #expect(rig.processes.log == ["requestQuit", "forceQuit"])
        #expect(!rig.processes.running)
    }

    @Test("upgrade: same or older version, nothing installed, another bundle ID → untouched")
    func noUpgrade() async throws {
        let same = Rig(installed: InputMethodBundleInfo(bundleID: imID, version: "2", shortVersion: nil, modeIDs: [modeID]))
        #expect(try await same.installer.upgradeIfNeeded() == .upToDate)
        let newer = Rig(installed: InputMethodBundleInfo(bundleID: imID, version: "10", shortVersion: nil, modeIDs: [modeID]))
        #expect(try await newer.installer.upgradeIfNeeded() == .upToDate)
        let none = Rig()
        #expect(try await none.installer.upgradeIfNeeded() == .notInstalled)
        let other = Rig(installed: InputMethodBundleInfo(bundleID: "com.example.other", version: "1", shortVersion: nil, modeIDs: []))
        #expect(try await other.installer.upgradeIfNeeded() == .skipped("bundle ID com.example.other"))
        for rig in [same, newer, none, other] {
            #expect(rig.files.log.isEmpty && rig.tis.log.isEmpty && rig.processes.log.isEmpty)
        }
    }

    @Test("version order is numeric")
    func versions() {
        #expect(SystemInputMethodInstaller.isNewer("10", than: "9"))
        #expect(SystemInputMethodInstaller.isNewer("1.10", than: "1.9"))
        #expect(!SystemInputMethodInstaller.isNewer("1", than: "1"))
        #expect(SystemInputMethodInstaller.isNewer("1", than: nil))
    }

    // MARK: Uninstall

    @Test("uninstall: select a keyboard, disable mode then parent, stop, trash; data kept")
    func uninstall() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau(enabled: true))
        rig.tis.currentID = modeID
        rig.processes.running = true
        let report = try await rig.installer.uninstall(deleteSettings: false)
        #expect(rig.tis.log == ["select com.apple.keylayout.ABC", "disable \(modeID)", "disable \(imID)"])
        #expect(rig.processes.log == ["requestQuit"])
        #expect(rig.files.log == ["trash"])
        #expect(report == UninstallReport(switchedTo: "ABC", movedToTrash: true, stillEnabled: false, dataDeleted: false))
        #expect(rig.counter.value == 0)
        #expect(rig.installer.status() == .notInstalled)
    }

    @Test("uninstall: Dấu not selected → no keyboard switch; the box deletes the data")
    func uninstallWithData() async throws {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau(enabled: true))
        rig.tis.currentID = "com.apple.keylayout.ABC"
        let report = try await rig.installer.uninstall(deleteSettings: true)
        #expect(!rig.tis.log.contains { $0.hasPrefix("select") })
        #expect(report.switchedTo == nil)
        #expect(report.dataDeleted)
        #expect(rig.counter.value == 1)
    }

    @Test("uninstall: a failed trash throws and deletes no data")
    func uninstallTrashFails() async {
        let rig = Rig(installed: old, sources: FakeTextInputSources.dau(enabled: true))
        rig.files.trashError = .failed("trash")
        await #expect(throws: InputMethodInstallerError.failed("trash")) {
            _ = try await rig.installer.uninstall(deleteSettings: true)
        }
        #expect(rig.counter.value == 0)
        // The sources were already off: Dấu does not type any more.
        #expect(rig.installer.status() == .installed(version: "0.1.0"))
    }

    @Test("uninstall: not installed (only listed) still disables and reports")
    func uninstallNotInstalled() async throws {
        let rig = Rig(sources: FakeTextInputSources.dau(enabled: true))
        let report = try await rig.installer.uninstall(deleteSettings: false)
        #expect(rig.files.log.isEmpty)
        #expect(!report.movedToTrash)
        #expect(!report.stillEnabled)
    }

    // MARK: Files (temp folder)

    @Test("files: staged copy swapped in, quarantine cleared, old bundle gone, no staging left")
    func files() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("dau-installer-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        func makeBundle(_ url: URL, version: String, marker: String) throws {
            let contents = url.appendingPathComponent("Contents")
            try fm.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
            let info: [String: Any] = [
                "CFBundleIdentifier": imID, "CFBundleVersion": version, "CFBundleShortVersionString": "0.\(version).0",
                "ComponentInputModeDict": ["tsInputModeListKey": [modeID: [:]]],
            ]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            try Data(marker.utf8).write(to: contents.appendingPathComponent("MacOS/DauInputMethod"))
        }
        let embedded = root.appendingPathComponent("App/DauInputMethod.app")
        try makeBundle(embedded, version: "2", marker: "new")
        let quarantine = "0081;00000000;Safari;"
        #expect(setxattr(embedded.appendingPathComponent("Contents/MacOS/DauInputMethod").path, Quarantine.attribute,
                         quarantine, quarantine.utf8.count, 0, 0) == 0)
        let dir = root.appendingPathComponent("Input Methods")
        var verified: [URL] = []
        var trashed: [URL] = []
        var files = InputMethodBundleFiles(embeddedURL: embedded, directory: dir)
        files.verify = { verified.append($0); return true }
        files.trash = { trashed.append($0); try fm.removeItem(at: $0) }

        #expect(!files.isInstalled)
        #expect(files.embedded?.vietnameseModeID == modeID)
        try files.installEmbedded()   // first install: creates the folder
        #expect(files.installed?.version == "2")

        try makeBundle(files.installedURL, version: "1", marker: "old")   // an older one is there
        #expect(files.installed?.version == "1")
        try files.installEmbedded()
        #expect(files.installed?.version == "2")   // read fresh, not from a Bundle cache
        let binary = files.installedURL.appendingPathComponent("Contents/MacOS/DauInputMethod")
        #expect(String(decoding: try Data(contentsOf: binary), as: UTF8.self) == "new")
        #expect(!Quarantine.isSet(binary))
        #expect(Quarantine.isSet(embedded.appendingPathComponent("Contents/MacOS/DauInputMethod")))   // the app's copy untouched
        #expect(try fm.contentsOfDirectory(atPath: dir.path) == ["DauInputMethod.app"])
        // The staged copy was checked, not the app's.
        #expect(verified.count == 2 && verified.allSatisfy { $0.lastPathComponent.hasPrefix(".DauInputMethod-staging-") })

        // A bad signature leaves the installed bundle as it was.
        files.verify = { _ in false }
        #expect(throws: InputMethodInstallerError.invalidSignature) { try files.installEmbedded() }
        #expect(files.installed?.version == "2")
        #expect(try fm.contentsOfDirectory(atPath: dir.path) == ["DauInputMethod.app"])

        try files.moveInstalledToTrash()
        #expect(trashed.map(\.path) == [files.installedURL.path])
        #expect(!files.isInstalled)

        // No bundle inside the app.
        let missing = InputMethodBundleFiles(embeddedURL: root.appendingPathComponent("nope.app"), directory: dir)
        #expect(missing.embedded == nil)
        #expect(throws: InputMethodInstallerError.unavailable) { try missing.installEmbedded() }
    }
}
