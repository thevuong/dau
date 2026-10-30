import Testing
import DauShared
@testable import SnapshotSettings

/// The onboarding window's state machine (D14, docs/UI.md "Onboarding") on fake
/// services: which step shows, what the sidebar marks done, enabling with undo, and
/// which window opens at launch.
@MainActor
@Suite("Onboarding flow")
struct OnboardingFlowTests {
    let openKey = FakeInputMethodDetector.running("OpenKey", bundleID: "com.tuyenmai.openkey")

    final class Opened { var count = 0 }
    let opened = Opened()

    func flow(_ found: [DetectedInputMethod] = [], status: InputMethodStatus = .notInstalled,
              failure: InputMethodInstallerError? = nil,
              shortcut: InputSourceShortcut.Reading = .unknown)
        -> (OnboardingFlow, FakeInputMethodDetector, FakeInputMethodInstaller) {
        let detector = FakeInputMethodDetector(found)
        let installer = FakeInputMethodInstaller(status, failure: failure)
        let opened = self.opened
        let flow = OnboardingFlow(detector: detector, installer: installer,
                                  shortcut: { shortcut }, englishLayout: { "ABC" },
                                  openKeyboardSettings: { opened.count += 1 })
        return (flow, detector, installer)
    }

    @Test("step 1 shows only while another input method runs")
    func conflictStepOnlyWhenRunning() {
        let (withConflict, _, _) = flow([openKey])
        withConflict.start()
        #expect(withConflict.step == .oldInputMethods)
        #expect(withConflict.conflicts.map(\.name) == ["OpenKey"])

        let installedOnly = DetectedInputMethod(name: "EVKey", bundleID: "x", isRunning: false, quitSteps: [])
        let (clear, _, _) = flow([installedOnly])
        clear.start()
        #expect(clear.step == .enable)
        #expect(clear.conflicts.isEmpty)
        #expect(clear.state(of: .oldInputMethods) == .done)
        #expect(!clear.canGoBack)
    }

    @Test("rechecking moves on once the other input method has quit")
    func recheck() {
        let (flow, detector, _) = flow([openKey])
        flow.start()
        flow.recheck()
        #expect(flow.step == .oldInputMethods)
        detector.found = []
        flow.refresh()   // the window became active again
        #expect(flow.step == .enable)
        #expect(flow.state(of: .oldInputMethods) == .done)
    }

    @Test("skipping keeps step 1 not done and allows going back")
    func skip() {
        let (flow, _, _) = flow([openKey])
        flow.start()
        flow.skip()
        #expect(flow.step == .enable)
        #expect(flow.state(of: .oldInputMethods) == .pending)
        #expect(flow.state(of: .enable) == .current)
        #expect(flow.canGoBack)
        flow.back()
        #expect(flow.step == .oldInputMethods)
    }

    @Test("enable installs first when needed, then offers undo")
    func enableAndUndo() async {
        let (flow, _, installer) = flow(status: .notInstalled)
        flow.start()
        flow.next()   // not enabled yet: stays
        #expect(flow.step == .enable)

        await flow.enable()
        #expect(installer.calls == ["install", "enable"])
        #expect(flow.status == .enabled)
        #expect(flow.enabledHere)
        #expect(!flow.failed)

        await flow.undoEnable()
        #expect(installer.calls == ["install", "enable", "undoEnable"])
        #expect(!flow.status.isEnabled)
        #expect(!flow.enabledHere)

        await flow.enable()
        #expect(installer.calls.suffix(1) == ["enable"])   // installed already
        flow.next()
        #expect(flow.step == .typing)
        #expect(flow.state(of: .enable) == .done)
        #expect(flow.state(of: .typing) == .current)
        flow.back()
        #expect(flow.step == .enable)
    }

    @Test("a failed action says so and offers no undo")
    func failure() async {
        let (flow, _, installer) = flow(status: .installed(version: nil), failure: .unavailable)
        flow.start()
        await flow.enable()
        #expect(flow.failed)
        #expect(!flow.enabledHere)
        #expect(installer.calls == ["enable"])
        #expect(flow.step == .enable)
        flow.next()
        #expect(flow.step == .enable)
    }

    @Test("enable read back as off: guidance, Keyboard settings opened, no success claimed (N4, N5)")
    func enableStillOff() async {
        let (flow, _, installer) = flow(status: .installed(version: nil))
        installer.enableOutcome = .notEnabled
        flow.start()
        await flow.enable()
        #expect(flow.problem == .notEnabled)
        #expect(!flow.enabledHere)
        #expect(opened.count == 1)
        flow.next()
        #expect(flow.step == .enable)
        // macOS turns it on later (the user allowed it): enabled here, with undo.
        installer.current = .enabled
        flow.refresh()
        #expect(flow.problem == nil)
        #expect(flow.enabledHere)
        await flow.undoEnable()
        #expect(installer.calls.suffix(1) == ["undoEnable"])
    }

    @Test("not listed by macOS: the logout guidance, nothing opened")
    func enableNeedsLogout() async {
        let (flow, _, installer) = flow(status: .notInstalled)
        installer.enableOutcome = .notListed
        flow.start()
        await flow.enable()
        #expect(installer.calls == ["install", "enable"])
        #expect(flow.problem == .needsLogout)
        #expect(opened.count == 0)
        #expect(!flow.enabledHere)
        // Added by the user in Settings without "Bật Dấu" pending: not "enabled here".
        installer.current = .enabled
        flow.refresh()
        #expect(!flow.enabledHere)
    }

    @Test("other Vietnamese input sources are a soft note, not step 1")
    func otherSources() {
        let (flow, detector, _) = flow()
        detector.otherSources = ["Tiếng Việt – Telex"]
        flow.start()
        #expect(flow.step == .enable)
        #expect(flow.otherSources == ["Tiếng Việt – Telex"])
    }

    @Test("already enabled: step 2 is done and goes straight on")
    func alreadyEnabled() async {
        let (flow, _, installer) = flow(status: .selected)
        flow.start()
        #expect(flow.step == .enable)
        await flow.enable()   // nothing to do
        #expect(installer.calls.isEmpty)
        #expect(!flow.enabledHere)
        flow.next()
        #expect(flow.step == .typing)
        #expect(flow.state(of: .enable) == .done)
    }

    @Test("start over resets the session; a forced step applies once")
    func restart() async {
        let (flow, _, _) = flow([openKey], status: .installed(version: nil))
        flow.forcedStartStep = .typing
        flow.start()
        #expect(flow.step == .typing)
        flow.start()
        #expect(flow.step == .oldInputMethods)
        flow.skip()
        await flow.enable()
        #expect(flow.enabledHere)
        flow.start()
        #expect(!flow.enabledHere)
    }

    @Test("reads the shortcut and the English layout on start")
    func readsSystem() {
        let shortcut = InputSourceShortcut(keys: ["⌃", "Space"], globeKey: false)
        let (flow, _, _) = flow(shortcut: .shortcut(shortcut))
        flow.start()
        #expect(flow.shortcut == .shortcut(shortcut))
        #expect(flow.englishLayout == "ABC")
    }

    @Test("launch opens onboarding only when Dấu is known to be missing or off")
    func launch() {
        #expect(LaunchRouter.opensOnboarding(.notInstalled))
        #expect(LaunchRouter.opensOnboarding(.installed(version: "1.0")))
        #expect(!LaunchRouter.opensOnboarding(.enabled))
        #expect(!LaunchRouter.opensOnboarding(.selected))
        #expect(!LaunchRouter.opensOnboarding(.unknown))
    }

    @Test("known input methods: one entry per app, unique bundle IDs, quit steps name the app")
    func knownList() {
        let ids = KnownInputMethods.all.flatMap(\.bundleIDs)
        #expect(Set(ids).count == ids.count)
        // Bundle IDs from the released apps (docs/research/M5-INSTALL.md section 5).
        #expect(Set(ids) == ["com.tuyenmai.openkey", "com.lamquangminh.evkey", "com.trankynam.GoTiengViet",
                             "com.codetay.XKey", "com.phamhungtien.phtv", "org.gonhanh.GoNhanh", "com.goxkey.app"])
        // XKey's IMK input method is an input source (soft note), not a conflict.
        #expect(!ids.contains("com.codetay.inputmethod.XKey"))
        for entry in KnownInputMethods.all {
            #expect(KnownInputMethods.quitSteps(for: entry.name).allSatisfy { $0.contains(entry.name) })
        }
        // Unverified apps get the generic steps, which name no menu item (N5).
        #expect(KnownInputMethods.quitSteps(for: "EVKey").count == 2)
    }
}

@Suite("Input source shortcut reading (N5)")
struct ShortcutReadingTests {
    func entry(_ enabled: Bool) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [32, 49, 262_144], "type": "standard"]]
    }

    @Test("shortcut, none, unknown")
    func readings() {
        let control = InputSourceShortcut(keys: ["⌃", "Space"], globeKey: false)
        #expect(InputSourceShortcut.reading(hotKeys: ["60": entry(true)], fnUsage: nil) == .shortcut(control))
        #expect(InputSourceShortcut.reading(hotKeys: ["60": entry(false), "61": entry(false)], fnUsage: 2) == .none)
        // The 🌐 key alone is a shortcut.
        #expect(InputSourceShortcut.reading(hotKeys: ["60": entry(false), "61": entry(false)], fnUsage: 1)
                == .shortcut(InputSourceShortcut(keys: [], globeKey: true)))
        // Entries missing: the system default applies, which is not guessed.
        #expect(InputSourceShortcut.reading(hotKeys: [:], fnUsage: 2) == .unknown)
        #expect(InputSourceShortcut.reading(hotKeys: ["60": entry(false)], fnUsage: 2) == .unknown)
        // The 🌐 setting unknown: it may switch input sources.
        #expect(InputSourceShortcut.reading(hotKeys: ["60": entry(false), "61": entry(false)], fnUsage: nil) == .unknown)
        #expect(InputSourceShortcut.reading(hotKeys: nil, fnUsage: nil) == .unknown)
    }

    @Test("inline text for running sentences")
    func inline() {
        #expect(InputSourceShortcut(keys: ["⌃", "Space"], globeKey: false).inlineText == "⌃Space")
        #expect(InputSourceShortcut(keys: [], globeKey: true).inlineText == "🌐")
        #expect(InputSourceShortcut(keys: ["⌃", "Space"], globeKey: true).inlineText == "⌃Space hoặc 🌐")
    }
}

@Suite("Onboarding try-it hint")
struct TryItSampleTests {
    @Test("the hint's keys type the mockup sentence (N5)", arguments: DauSettings.TypingMethod.allCases)
    func tryIt(_ method: DauSettings.TypingMethod) {
        #expect(SettingsSamples.tryIt(method).result == "tôi yêu tiếng Việt")
    }
}
