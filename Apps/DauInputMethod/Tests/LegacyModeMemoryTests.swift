import Foundation
import Testing

@Suite("Legacy per-app mode memory (D2/D5, removed 30/10/2026)")
struct LegacyModeMemoryTests {
    @Test("the old key is removed once; other keys are untouched")
    func removesOldKey() throws {
        let name = "dau.tests.legacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set([["com.apple.Safari", "english"]], forKey: LegacyModeMemory.defaultsKey)
        defaults.set(true, forKey: "other")

        #expect(LegacyModeMemory.removeIfPresent(from: defaults))
        #expect(defaults.object(forKey: LegacyModeMemory.defaultsKey) == nil)
        #expect(defaults.bool(forKey: "other"))
        // Nothing left: a second launch does nothing.
        #expect(!LegacyModeMemory.removeIfPresent(from: defaults))
    }

    @Test("a malformed old value is removed too (D18)")
    func removesGarbage() throws {
        let name = "dau.tests.legacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("garbage", forKey: LegacyModeMemory.defaultsKey)
        #expect(LegacyModeMemory.removeIfPresent(from: defaults))
        #expect(defaults.object(forKey: LegacyModeMemory.defaultsKey) == nil)
    }
}
