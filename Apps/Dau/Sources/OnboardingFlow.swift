import Foundation
import Observation

/// The onboarding window's state (D14, docs/UI.md "Onboarding"): which step shows, what
/// was detected, Dấu's status and the result of the last action. Views only read it and
/// call its actions; services come in through protocols (`OldInputMethodDetector`,
/// `InputMethodInstaller`) so tests drive it with fakes.
///
/// Steps:
/// 1. "Tắt bộ gõ cũ trước đã": only while another Vietnamese input method is running.
///    Rechecked when the window becomes active; skipping is allowed.
/// 2. "Bật Dấu": install if needed, then enable, with undo. The result is read back from
///    Text Input Sources (N4, N5): still off → Keyboard settings and the steps; not
///    listed at all → log out and in once (first install, D37).
/// 3. "Chọn kiểu gõ và gõ thử".
@MainActor
@Observable
final class OnboardingFlow {
    enum Step: Int, CaseIterable, Sendable {
        case oldInputMethods = 1, enable, typing
    }

    enum StepState: Equatable, Sendable {
        case done, current, pending
    }

    private(set) var step: Step = .enable
    /// Other input methods running now (installed but not running ones do not clash).
    private(set) var conflicts: [DetectedInputMethod] = []
    private(set) var status: InputMethodStatus = .unknown
    private(set) var shortcut: InputSourceShortcut.Reading = .unknown
    /// Name of the keyboard layout used for English, e.g. "ABC"; nil if unknown.
    private(set) var englishLayout: String?
    /// Other Vietnamese input sources enabled in the system (soft note, step 2).
    private(set) var otherSources: [String] = []
    /// Dấu was enabled from this window, so "Hoàn tác" is offered.
    private(set) var enabledHere = false
    private(set) var isWorking = false
    /// What went wrong with the last action, shown under step 2's card.
    private(set) var problem: Problem?
    /// "Bật Dấu" went through but macOS kept Dấu off; if it turns on later (the user
    /// allowed it, or added it in Keyboard settings) it still counts as enabled here.
    private(set) var awaitingSystem = false

    enum Problem: Equatable, Sendable {
        /// An error: the copy, the signature, the registration…
        case failed
        /// Text Input Sources still reports Dấu off after "Bật Dấu".
        case notEnabled
        /// Text Input Sources does not list Dấu: log out and in once (D37).
        case needsLogout
    }

    var failed: Bool { problem != nil }
    /// Text of the try-it field (step 3).
    var tryText = ""
    /// Step to open at instead of the usual first step, once (debug flag `--onboarding`).
    @ObservationIgnored var forcedStartStep: Step?

    @ObservationIgnored private let detector: OldInputMethodDetector
    @ObservationIgnored private let installer: InputMethodInstaller
    @ObservationIgnored private let readShortcut: () -> InputSourceShortcut.Reading
    @ObservationIgnored private let readEnglishLayout: () -> String?
    @ObservationIgnored private let openKeyboardSettings: () -> Void

    init(detector: OldInputMethodDetector, installer: InputMethodInstaller,
         shortcut: @escaping () -> InputSourceShortcut.Reading = InputSourceShortcut.read,
         englishLayout: @escaping () -> String? = InputSourceStatus.englishLayoutName,
         openKeyboardSettings: @escaping () -> Void = SystemSettings.openKeyboard) {
        self.detector = detector
        self.installer = installer
        self.readShortcut = shortcut
        self.readEnglishLayout = englishLayout
        self.openKeyboardSettings = openKeyboardSettings
    }

    /// Starts over: step 1 if another input method is running, else step 2.
    func start() {
        enabledHere = false
        awaitingSystem = false
        problem = nil
        readSystem()
        step = conflicts.isEmpty ? .enable : .oldInputMethods
        if let forced = forcedStartStep {
            step = forced
            forcedStartStep = nil
        }
    }

    /// Reads everything again (window became active, input sources changed). On step
    /// 1, moves on by itself once nothing clashes any more.
    func refresh() {
        readSystem()
        if step == .oldInputMethods && conflicts.isEmpty { step = .enable }
        if awaitingSystem && status.isEnabled {
            awaitingSystem = false
            enabledHere = true
            problem = nil
        }
    }

    /// Step 1, "Kiểm tra lại".
    func recheck() { refresh() }

    /// Step 1, "Bỏ qua": go on with the other input method still running.
    func skip() {
        guard step == .oldInputMethods else { return }
        step = .enable
    }

    var canGoBack: Bool {
        switch step {
        case .oldInputMethods: false
        case .enable: !conflicts.isEmpty
        case .typing: true
        }
    }

    func back() {
        guard canGoBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        problem = nil
        step = previous
    }

    /// Step 2 → 3, once Dấu is enabled.
    func next() {
        guard step == .enable, status.isEnabled else { return }
        problem = nil
        step = .typing
    }

    /// Step 2, "Bật Dấu": installs first when needed.
    func enable() async {
        guard step == .enable, !isWorking, !status.isEnabled else { return }
        isWorking = true
        problem = nil
        defer { isWorking = false }
        do {
            if status == .notInstalled { try await installer.install() }
            switch try await installer.enable() {
            case .enabled:
                enabledHere = true
                awaitingSystem = false
            case .notEnabled:
                // N4: guide, in the right pane of System Settings.
                problem = .notEnabled
                awaitingSystem = true
                openKeyboardSettings()
            case .notListed:
                problem = .needsLogout
            }
        } catch {
            problem = .failed
        }
        status = installer.status()
        if awaitingSystem && status.isEnabled {
            awaitingSystem = false
            enabledHere = true
            problem = nil
        }
    }

    /// Step 2, "Hoàn tác" after `enable()`.
    func undoEnable() async {
        guard enabledHere, !isWorking else { return }
        isWorking = true
        problem = nil
        defer { isWorking = false }
        do {
            try await installer.undoEnable()
            enabledHere = false
        } catch {
            problem = .failed
        }
        status = installer.status()
    }

    func state(of step: Step) -> StepState {
        if step == self.step { return .current }
        switch step {
        case .oldInputMethods:
            // Skipped with an input method still running: not done.
            return conflicts.isEmpty ? .done : .pending
        case .enable:
            return status.isEnabled ? .done : .pending
        case .typing:
            return .pending
        }
    }

    /// Debug captures: show a step as is.
    func show(_ step: Step) {
        self.step = step
    }

    private func readSystem() {
        conflicts = detector.detect().filter(\.isRunning)
        otherSources = detector.otherVietnameseSources()
        status = installer.status()
        shortcut = readShortcut()
        englishLayout = readEnglishLayout()
    }
}

/// Which window opens at launch (docs/UI.md): onboarding while Dấu is not installed or
/// not enabled, Settings otherwise. Unknown status opens Settings (nothing is claimed).
enum LaunchRouter {
    static func opensOnboarding(_ status: InputMethodStatus) -> Bool {
        switch status {
        case .notInstalled, .installed: true
        case .unknown, .enabled, .selected: false
        }
    }
}
