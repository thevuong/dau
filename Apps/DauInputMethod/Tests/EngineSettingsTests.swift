import DauEngine
import DauShared
import Testing

@Suite("EngineSettings (shared settings → engine options)")
struct EngineSettingsTests {
    /// An engine plus the text an app would show for the current word.
    private struct Typist {
        var engine: VietEngine
        var screen: [Unicode.Scalar] = []

        init(_ settings: DauSettings) { engine = VietEngine(options: settings.engineOptions) }

        var text: String {
            var view = String.UnicodeScalarView()
            view.append(contentsOf: screen)
            return String(view)
        }

        @discardableResult
        mutating func type(_ keys: String) -> String {
            for key in keys.unicodeScalars {
                switch engine.handle(key) {
                case .passThrough:
                    screen.append(key)
                case .replace(let deleteCount, let insert):
                    screen.removeLast(min(deleteCount, screen.count))
                    screen.append(contentsOf: insert)
                }
            }
            return text
        }

        /// What the input method does on a settings notification.
        mutating func apply(_ settings: DauSettings) -> Bool {
            let changed = EngineSettings.apply(settings, to: &engine)
            if changed { screen.removeAll() } // the word is forgotten; new text starts here
            return changed
        }
    }

    @Test("a new controller's engine uses the stored settings")
    func initialOptions() {
        let settings = DauSettings(typingMethod: .vni, tonePlacement: .classic, freeMarking: false,
                                   autoRestore: false, advanced: .allowZFWJ)
        var t = Typist(settings)
        #expect(t.engine.options == settings.engineOptions)
        #expect(t.type("Vie65t") == "Việt")
    }

    @Test("same engine options: nothing is reset, the word in progress continues")
    func unchanged() {
        var t = Typist(.defaults)
        t.type("vie")
        #expect(t.engine.isComposing)
        // Settings that do not touch the engine (D5, D13, D20) are not an options change.
        var other = DauSettings.defaults
        other.addMarksToTypedWords = false
        other.upsert(AppRule(bundleID: "com.apple.Terminal", underline: true))
        #expect(t.apply(other) == false)
        #expect(t.engine.isComposing)
        #expect(t.type("etj") == "việt")
    }

    @Test("changing options mid-word resets first, then the new method applies")
    func changeMidWord() {
        var t = Typist(.defaults)
        t.type("tie")
        #expect(t.engine.isComposing)
        let vni = DauSettings(typingMethod: .vni)
        #expect(t.apply(vni) == true)
        #expect(t.engine.isComposing == false)
        #expect(t.engine.options == vni.engineOptions)
        // The next keys start a new word under VNI.
        #expect(t.type("tie6ng1") == "tiếng")
    }

    @Test("every engine-relevant setting is an options change")
    func eachSettingCounts() {
        let base = DauSettings.defaults
        var changes: [DauSettings] = []
        var s = base; s.typingMethod = .simpleTelex; changes.append(s)
        s = base; s.tonePlacement = .classic; changes.append(s)
        s = base; s.freeMarking = false; changes.append(s)
        s = base; s.autoRestore = false; changes.append(s)
        s = base; s.consonantShortcuts = true; changes.append(s)
        s = base; s.allowZFWJ = true; changes.append(s)
        for changed in changes {
            var engine = VietEngine(options: base.engineOptions)
            #expect(EngineSettings.apply(changed, to: &engine) == true)
            #expect(engine.options == changed.engineOptions)
        }
    }

    @Test("tone placement follows the new settings")
    func tonePlacement() {
        var t = Typist(.defaults)
        #expect(t.type("hoaf") == "hoà")
        #expect(t.apply(DauSettings(tonePlacement: .classic)) == true)
        #expect(t.type("hoaf") == "hòa")
    }
}
