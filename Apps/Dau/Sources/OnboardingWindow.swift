import AppKit
import Carbon
import SwiftUI
import DauShared

// The onboarding window (D14, docs/UI.md "Onboarding", mockup artboards
// "OnboardingConflict", "OnboardingEnable", "Onboarding"): a 230 pt sidebar with the app
// icon, the name and the three steps, and the current step on the right. 720 × 500 pt,
// no title text. System controls and colors only (D9).

@MainActor
enum OnboardingScene {
    nonisolated static let id = "onboarding"
    /// The window, title bar included (mockup).
    static let size = CGSize(width: 720, height: 500)
    /// The hidden title bar still counts as top safe area, and SwiftUI adds it to the
    /// window's size: the content is laid out below it (32 pt on macOS 27, 28 before).
    static let titleBarHeight: CGFloat = {
        let content = NSRect(x: 0, y: 0, width: 100, height: 100)
        return NSWindow.frameRect(forContentRect: content, styleMask: [.titled, .closable]).height - content.height
    }()

    /// Distance from the window's top edge, turned into one from the safe area's.
    static func belowTitleBar(_ top: CGFloat) -> CGFloat { max(0, top - titleBarHeight) }
}

struct OnboardingWindow: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        // A plain split, not NavigationSplitView: the steps are not a selectable list,
        // and the mockup's sidebar runs the full height under the traffic lights.
        HStack(spacing: 0) {
            // 229 + the 1 pt divider: the content starts at 230, as in the mockup.
            OnboardingSidebar()
                .frame(width: 229)
                .frame(maxHeight: .infinity)
                .background { SidebarMaterial().ignoresSafeArea() }
                .layoutProbe("onbSidebar")
            Divider().ignoresSafeArea()
            OnboardingStepView()
        }
        .frame(width: OnboardingScene.size.width,
               height: OnboardingScene.size.height - OnboardingScene.titleBarHeight)
        .background(HiddenWindowTitle())
        .onAppear { flow.start() }
        // Step 1 is rechecked whenever the user comes back to the window.
        .onChange(of: activeState) { _, state in
            if state == .key { flow.refresh() }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))) { _ in
            flow.refresh()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))) { _ in
            flow.refresh()
        }
    }
}

// MARK: - Sidebar

struct OnboardingSidebar: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Text(verbatim: "Dấu")
                    .font(.system(size: 17, weight: .bold))
            }
            .layoutProbe("onbAppName")

            VStack(alignment: .leading, spacing: 18) {
                ForEach(OnboardingFlow.Step.allCases, id: \.self) { step in
                    StepRow(step: step, state: flow.state(of: step))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Các bước thiết lập"))
            .layoutProbe("onbSteps")

            Spacer(minLength: 0)

            // Permissions the setup needs: filled in once M5 has verified them (N5).
            Hint(Text("[Quyền cần cấp — điền sau khi kiểm chứng ở M5]"))
        }
        // Mockup: 16 pt inset, the 12 pt traffic lights, then 22 pt to the app name.
        .padding(.top, OnboardingScene.belowTitleBar(50))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The system's sidebar material (behind-window vibrancy), as in a sidebar.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// One step in the sidebar: a 24 pt circle (check when done, number otherwise), the
/// step's name (semibold when current) and a hint.
struct StepRow: View {
    let step: OnboardingFlow.Step
    let state: OnboardingFlow.StepState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StepBadge(number: step.rawValue, state: state)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.sidebarTitle)
                    .font(.system(size: 13, weight: state == .current ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Hint(step.sidebarHint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Bước \(step.rawValue): \(Text(step.sidebarTitle))"))
        .accessibilityValue(state.spoken)
        .accessibilityAddTraits(state == .current ? [.isStaticText, .isSelected] : .isStaticText)
    }
}

struct StepBadge: View {
    let number: Int
    let state: OnboardingFlow.StepState

    var body: some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(Color.green)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            case .current:
                Circle().fill(Color.accentColor)
                Text(verbatim: "\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            case .pending:
                Circle().fill(.fill)
                Text(verbatim: "\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

extension OnboardingFlow.Step {
    var sidebarTitle: LocalizedStringResource {
        switch self {
        case .oldInputMethods: "Kiểm tra bộ gõ cũ"
        case .enable: "Bật Dấu"
        case .typing: "Chọn kiểu gõ"
        }
    }

    var sidebarHint: Text {
        switch self {
        case .oldInputMethods: Text("Tránh gõ ra chữ lỗi")
        case .enable: Text("Thêm vào nguồn nhập liệu")
        case .typing: Text("Và gõ thử")
        }
    }
}

extension OnboardingFlow.StepState {
    var spoken: Text {
        switch self {
        case .done: Text("Đã xong")
        case .current: Text("Đang làm")
        case .pending: Text("Chưa làm")
        }
    }
}

// MARK: - Steps

struct OnboardingStepView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        Group {
            switch flow.step {
            case .oldInputMethods: ConflictStep()
            case .enable: EnableStep()
            case .typing: TypingStep()
            }
        }
        .padding(.top, OnboardingScene.belowTitleBar(40))
        .padding(.horizontal, 36)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { SettingsColors.page.ignoresSafeArea() }
        .layoutProbe("onbDetail")
    }
}

/// Title (22 bold), subtitle (13 secondary), content, then the buttons at the bottom
/// right, as in the three artboards.
struct StepLayout<Content: View, Buttons: View>: View {
    /// Names the layout probes (captures): a step leaving the window can still report.
    let step: OnboardingFlow.Step
    let title: Text
    let subtitle: Text
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                title
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .layoutProbe("onbTitle-\(step.rawValue)")
                // Mockup line height 1.5: 19.5 pt per line.
                subtitle
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3.5)
                    .padding(.vertical, 1.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                buttons
            }
            .settingsButton()
            .layoutProbe("onbButtons-\(step.rawValue)")
        }
    }
}

/// A card as on the Settings pages, with 16 pt padding and 12 pt between items.
struct OnboardingCard<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        SettingsCard(padding: 16) {
            VStack(alignment: .leading, spacing: spacing) { content }
        }
    }
}

// MARK: Step 1

struct ConflictStep: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        let names = flow.conflicts.map(\.name).formatted(.list(type: .and))
        StepLayout(step: .oldInputMethods, title: Text("Tắt bộ gõ cũ trước đã"),
                   subtitle: Text("\(names) đang chạy. Hai bộ gõ cùng chạy sẽ thêm dấu hai lần và ra chữ lỗi.")) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(flow.conflicts) { app in
                        ConflictCard(app: app)
                            .layoutProbe(app == flow.conflicts.first ? "onbCard-1" : "onbCard-1-more")
                    }
                    Hint(Text("Dấu tự kiểm tra lại khi bạn quay về cửa sổ này."))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        } buttons: {
            Button("Bỏ qua") { flow.skip() }
                .accessibilityHint(Text("Tiếp tục khi bộ gõ cũ vẫn đang chạy"))
            Button("Kiểm tra lại") { flow.recheck() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}

struct ConflictCard: View {
    let app: DetectedInputMethod

    var body: some View {
        OnboardingCard {
            HStack(spacing: 12) {
                OtherAppIcon(bundleID: app.bundleID, name: app.name)
                Text(verbatim: app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if app.isRunning {
                    RunningChip()
                }
            }
            .accessibilityElement(children: .combine)
            // Mockup line height 1.7: about 22 pt per line.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(app.quitSteps.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: "\(index + 1).")
                            .monospacedDigit()
                        Text(verbatim: line)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 13))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 3)
            .padding(.leading, 4)
        }
    }
}

/// "Đang chạy": a capsule on the system orange tint.
struct RunningChip: View {
    var body: some View {
        Text("Đang chạy")
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(Color.orange.quaternary, in: Capsule())
    }
}

/// Another app's icon (32 pt) from Launch Services, or its initial on a system fill.
struct OtherAppIcon: View {
    let bundleID: String
    let name: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Text(verbatim: String(name.prefix(1)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

// MARK: Step 2

struct EnableStep: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        StepLayout(step: .enable, title: Text("Bật Dấu"), subtitle: subtitle) {
            OnboardingCard {
                Text("Sau khi bật, bạn sẽ thấy")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 12) {
                    InputModeBadge()
                        .fill(.primary, style: FillStyle(eoFill: true))
                        .frame(width: 22, height: 16)
                        .accessibilityHidden(true)
                    Text("Biểu tượng V trên thanh menu khi đang gõ tiếng Việt")
                        .font(.system(size: 13))
                }
                ShortcutLine(reading: flow.shortcut, englishLayout: flow.englishLayout)
            }
            .layoutProbe("onbCard-2")
            EnableResult()
        } buttons: {
            if flow.canGoBack {
                Button("Quay lại") { flow.back() }
            }
            if flow.enabledHere {
                Button("Hoàn tác") { Task { await flow.undoEnable() } }
                    .accessibilityHint(Text("Gỡ Dấu khỏi nguồn nhập liệu"))
            }
            if flow.status.isEnabled {
                Button("Tiếp tục") { flow.next() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Bật Dấu") { Task { await flow.enable() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .disabled(flow.isWorking)
    }

    private var subtitle: Text {
        flow.status.isEnabled
            ? Text("Dấu đã có trong Nguồn nhập liệu của macOS, cạnh bàn phím bạn đang dùng.")
            : Text("Dấu sẽ được thêm vào Nguồn nhập liệu của macOS, cạnh bàn phím bạn đang dùng.")
    }
}

/// The input source shortcut row of step 2: the real shortcut as keycaps (D2), never a
/// guessed one; when there is none, or it cannot be read, a way to Keyboard settings.
struct ShortcutLine: View {
    let reading: InputSourceShortcut.Reading
    let englishLayout: String?

    var body: some View {
        switch reading {
        case .shortcut(let shortcut):
            HStack(spacing: 12) {
                ShortcutKeycaps(shortcut: shortcut)
                switchText
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .none:
            HStack(spacing: 12) {
                Text("Chưa có phím tắt để chuyển nhanh sang bàn phím tiếng Anh.")
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                OpenKeyboardSettingsButton()
            }
        case .unknown:
            HStack(spacing: 12) {
                ShortcutKeycaps(shortcut: nil)
                switchText
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                OpenKeyboardSettingsButton()
            }
        }
    }

    private var switchText: Text {
        if let englishLayout {
            Text("Phím tắt nguồn nhập liệu của macOS để chuyển sang “\(englishLayout)” gõ tiếng Anh")
        } else {
            Text("Phím tắt nguồn nhập liệu của macOS để chuyển sang bàn phím tiếng Anh")
        }
    }
}

struct OpenKeyboardSettingsButton: View {
    var body: some View {
        Button("Mở Cài đặt Bàn phím…") { SystemSettings.openKeyboard() }
            .settingsButton()
            .fixedSize()
    }
}

/// Under the card: the result of the last action, or the room kept for macOS's
/// confirmation (open question, verified in M5).
struct EnableResult: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        if flow.failed {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)
                Text("Chưa bật được Dấu. Bạn có thể tự thêm “Dấu – Tiếng Việt” trong Cài đặt Bàn phím › Nguồn đầu vào.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                OpenKeyboardSettingsButton()
            }
            .accessibilityElement(children: .contain)
        } else if flow.enabledHere {
            Label {
                Text("Đã bật Dấu. Bấm Hoàn tác nếu bạn đổi ý.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        } else if !flow.status.isEnabled {
            Hint(Text("[Nếu macOS yêu cầu xác nhận, hướng dẫn sẽ hiện ở đây — kiểm chứng ở M5]"))
        }
    }
}

/// The input mode icon, drawn from the same geometry as `scripts/make-mode-icons.swift`
/// (22 × 16 pt: a rounded badge with the V cut out). Fill it with even-odd so the V is
/// a hole, like the template image the menu bar shows.
struct InputModeBadge: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 22, sy = rect.height / 16
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            // The script draws with the origin at the bottom left.
            CGPoint(x: rect.minX + x * sx, y: rect.minY + (16 - y) * sy)
        }
        var path = Path(roundedRect: CGRect(x: rect.minX + 0.5 * sx, y: rect.minY + 0.5 * sy,
                                            width: 21 * sx, height: 15 * sy),
                        cornerRadius: 4 * min(sx, sy), style: .circular)
        path.addLines([p(6.5, 12.25), p(8.3, 12.25), p(11.0, 5.875), p(13.7, 12.25),
                       p(15.5, 12.25), p(11.9, 3.75), p(10.1, 3.75)])
        path.closeSubpath()
        return path
    }
}

// MARK: Step 3

struct TypingStep: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(SettingsModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        @Bindable var flow = flow
        StepLayout(step: .typing, title: Text("Chọn kiểu gõ và gõ thử"),
                   subtitle: Text("Đổi lại bất cứ lúc nào trong Cài đặt.")) {
            SegmentedPicker(String(localized: "Kiểu gõ"), selection: $model.settings.typingMethod,
                            options: DauSettings.TypingMethod.allCases.map { ($0, $0.title) })
                .layoutProbe("onbSegmented-3")
            OnboardingCard(spacing: 10) {
                Text("Gõ thử")
                    .font(.system(size: 13, weight: .semibold))
                TextField(text: $flow.tryText, prompt: Text("Gõ ở đây")) {
                    Text("Gõ thử")
                }
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .font(.system(size: 16))
                .accessibilityLabel(Text("Gõ thử"))
                .layoutProbe("onbTryField-3")
                Hint(Text("Gợi ý: \(SettingsSamples.tryIt(model.settings.typingMethod).keys)"))
                if flow.status != .selected {
                    Hint(notActiveText)
                }
            }
            .layoutProbe("onbCard-3")
        } buttons: {
            Button("Quay lại") { flow.back() }
            Button("Bắt đầu gõ") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    /// The field types with the current input source, which is not Dấu yet.
    private var notActiveText: Text {
        if let shortcut = flow.shortcut.shortcut {
            Text("Dấu chưa phải nguồn nhập liệu đang dùng: chọn “Dấu – Tiếng Việt” trên thanh menu hoặc bấm \(shortcut.inlineText) rồi gõ thử.")
        } else {
            Text("Dấu chưa phải nguồn nhập liệu đang dùng: chọn “Dấu – Tiếng Việt” trên thanh menu rồi gõ thử.")
        }
    }
}
