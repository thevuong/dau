import DauShared
import Testing

@Suite("AppModeMemory (D5 start mode per app)")
struct AppModeMemoryTests {
    private let terminal = "com.apple.Terminal"
    private let safari = "com.apple.Safari"
    private let notes = "com.apple.Notes"

    private func settings(remember: Bool = false, rules: [AppRule] = []) -> DauSettings {
        DauSettings(rememberModePerApp: remember, appRules: rules)
    }

    @Test("mode IDs map to Dấu's two modes only (D2, D18)")
    func identifiers() {
        let base = "com.example.dau.inputmethod.Dau"
        #expect(InputMode.vietnamese.identifier(base: base) == base + ".vi")
        #expect(InputMode.english.identifier(base: base) == base + ".en")
        #expect(InputMode(identifier: base + ".vi", base: base) == .vietnamese)
        #expect(InputMode(identifier: base + ".en", base: base) == .english)
        #expect(InputMode(identifier: base, base: base) == nil)
        #expect(InputMode(identifier: "com.apple.keylayout.ABC", base: base) == nil)
        #expect(InputMode(identifier: ".vi", base: "") == nil)
        #expect(InputMode(identifier: "", base: base) == nil)
    }

    @Test("no rule and remembering off: keep the current mode")
    func noRule() {
        var m = AppModeMemory()
        do { let r = m.activate(bundleID: safari, current: .vietnamese, settings: settings()); #expect(r == nil) }
        do { let r = m.activate(bundleID: notes, current: .english, settings: settings()); #expect(r == nil) }
    }

    @Test("an app rule switches the mode when the app is entered")
    func ruleSwitches() {
        let s = settings(rules: [AppRule(bundleID: terminal, mode: .english)])
        var m = AppModeMemory()
        do { let r = m.activate(bundleID: terminal, current: .vietnamese, settings: s); #expect(r == .english) }
        // Already in the rule's mode: no switch.
        var m2 = AppModeMemory()
        do { let r = m2.activate(bundleID: terminal, current: .english, settings: s); #expect(r == nil) }
    }

    @Test("another field of the same app keeps the user's choice")
    func sameAppNoReapply() {
        let s = settings(rules: [AppRule(bundleID: terminal, mode: .english)])
        var m = AppModeMemory()
        do { let r = m.activate(bundleID: terminal, current: .vietnamese, settings: s); #expect(r == .english) }
        // The user switches back to Vietnamese, then opens a new tab: no forced switch.
        do { let r = m.activate(bundleID: terminal, current: .vietnamese, settings: s); #expect(r == nil) }
        // Leaving and coming back applies the rule again.
        do { let r = m.activate(bundleID: safari, current: .vietnamese, settings: s); #expect(r == nil) }
        do { let r = m.activate(bundleID: terminal, current: .vietnamese, settings: s); #expect(r == .english) }
    }

    @Test("remembered mode applies only when the setting is on")
    func remembered() {
        var on = settings(remember: true)
        var m = AppModeMemory()
        do { let r = m.record(.english, for: safari, settings: on); #expect(r) }
        do { let r = m.activate(bundleID: notes, current: .vietnamese, settings: on); #expect(r == nil) }
        do { let r = m.activate(bundleID: safari, current: .vietnamese, settings: on); #expect(r == .english) }
        // Setting turned off: the remembered mode is ignored (D5 default off).
        on.rememberModePerApp = false
        do { let r = m.activate(bundleID: notes, current: .vietnamese, settings: on); #expect(r == nil) }
        do { let r = m.activate(bundleID: safari, current: .vietnamese, settings: on); #expect(r == nil) }
    }

    @Test("a rule always wins over a remembered mode (D5)")
    func ruleBeatsRemembered() {
        let s = settings(remember: true, rules: [AppRule(bundleID: terminal, mode: .vietnamese)])
        var m = AppModeMemory()
        // Nothing is remembered for an app that has a rule…
        do { let r = m.record(.english, for: terminal, settings: s); #expect(r == false) }
        #expect(m.rememberedMode(for: terminal) == nil)
        // …and the rule decides.
        do { let r = m.activate(bundleID: terminal, current: .english, settings: s); #expect(r == .vietnamese) }
    }

    @Test("nothing is recorded while remembering is off")
    func noRecordWhenOff() {
        var m = AppModeMemory()
        do { let r = m.record(.english, for: safari, settings: settings()); #expect(r == false) }
        #expect(m.rememberedMode(for: safari) == nil)
    }

    @Test("recording again updates the mode; forget clears everything")
    func updateAndForget() {
        let s = settings(remember: true)
        var m = AppModeMemory()
        m.record(.english, for: safari, settings: s)
        m.record(.english, for: notes, settings: s)
        do { let r = m.record(.vietnamese, for: safari, settings: s); #expect(r) }
        #expect(m.rememberedMode(for: safari) == .vietnamese)
        #expect(m.remembered.map(\.bundleID) == [notes, safari])
        // Same mode, already the newest: no change (no write to defaults).
        do { let r = m.record(.vietnamese, for: safari, settings: s); #expect(r == false) }
        do { let r = m.forgetRemembered(); #expect(r) }
        #expect(m.rememberedMode(for: safari) == nil)
        do { let r = m.forgetRemembered(); #expect(r == false) }
    }

    @Test("bad bundle IDs are ignored (D18)")
    func badBundleIDs() {
        let s = settings(remember: true, rules: [AppRule(bundleID: terminal, mode: .english)])
        var m = AppModeMemory()
        do { let r = m.activate(bundleID: "", current: .vietnamese, settings: s); #expect(r == nil) }
        do { let r = m.record(.english, for: "", settings: s); #expect(r == false) }
        let long = String(repeating: "a", count: AppModeMemory.maxBundleIDLength + 1)
        do { let r = m.record(.english, for: long, settings: s); #expect(r == false) }
        do { let r = m.activate(bundleID: long, current: .vietnamese, settings: s); #expect(r == nil) }
        #expect(m.lastBundleID == nil)
    }

    @Test("memory is bounded; the oldest app is dropped first")
    func capacity() {
        let s = settings(remember: true)
        var m = AppModeMemory()
        for i in 0...AppModeMemory.capacity {
            m.record(.english, for: "app.\(i)", settings: s)
        }
        #expect(m.remembered.count == AppModeMemory.capacity)
        #expect(m.rememberedMode(for: "app.0") == nil)
        #expect(m.rememberedMode(for: "app.\(AppModeMemory.capacity)") == .english)
    }

    @Test("property list round trip; malformed entries are skipped (D18)")
    func persistence() {
        let s = settings(remember: true)
        var m = AppModeMemory()
        m.record(.english, for: safari, settings: s)
        m.record(.vietnamese, for: notes, settings: s)
        let restored = AppModeMemory(propertyList: m.propertyList)
        #expect(restored.remembered == m.remembered)
        #expect(restored.lastBundleID == nil)

        let messy: [Any] = [
            [safari, "english"],
            [notes, "klingon"],
            ["", "english"],
            [terminal],
            42,
            [terminal, "vietnamese", "extra"],
            [notes, "vietnamese"],
            [safari, "vietnamese"],
        ]
        let parsed = AppModeMemory(propertyList: messy)
        #expect(parsed.remembered == [
            AppModeMemory.Entry(bundleID: notes, mode: .vietnamese),
            AppModeMemory.Entry(bundleID: safari, mode: .vietnamese),
        ])
        #expect(AppModeMemory(propertyList: nil).remembered.isEmpty)
        #expect(AppModeMemory(propertyList: "garbage").remembered.isEmpty)
    }
}
