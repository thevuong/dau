import Testing
import DauEngine
@testable import DauShared

/// Pins every "keys → result" the Settings window shows. The window computes them with
/// the engine at run time; these tests make sure they say what the labels around them
/// claim (N5). Expected values follow Vietnamese spelling and DECISIONS.md.
@Suite("Settings examples")
struct SettingsExamplesTests {
    static let allSettings: [DauSettings] = {
        var all: [DauSettings] = []
        for method in DauSettings.TypingMethod.allCases {
            for placement in DauSettings.TonePlacement.allCases {
                for free in [true, false] {
                    all.append(DauSettings(typingMethod: method, tonePlacement: placement, freeMarking: free))
                }
            }
        }
        return all
    }()

    @Test("preview types the sample sentence correctly in every configuration",
          arguments: allSettings)
    func previewSentence(_ settings: DauSettings) {
        let lines = SettingsExamples.preview(settings)
        #expect(lines.count == 2)
        #expect(lines[0].result == "tôi yêu tiếng Việt")
        let expected = settings.tonePlacement == .modern ? "hoà thuý" : "hòa thúy"
        #expect(lines[1].result == expected)
    }

    @Test("preview results are precomposed (D3)", arguments: allSettings)
    func previewIsNFC(_ settings: DauSettings) {
        for line in SettingsExamples.preview(settings) {
            // Every Vietnamese letter used here is one precomposed scalar.
            #expect(!line.result.unicodeScalars.contains { (0x300...0x36F).contains($0.value) })
        }
    }

    @Test("restore examples: foreign words come back, Vietnamese stays",
          arguments: DauSettings.TypingMethod.allCases)
    func restore(_ method: DauSettings.TypingMethod) {
        let results = SettingsExamples.restore(method).map(\.result)
        #expect(results == ["windows", "Hasaki", "Việt"])
    }

    @Test("Vietnamese wins and doubling keeps the original (D4, D26, D36)",
          arguments: DauSettings.TypingMethod.allCases)
    func vietnameseWins(_ method: DauSettings.TypingMethod) {
        let wins = SettingsExamples.vietnameseWins(method)
        let keep = SettingsExamples.keepOriginal(method)
        if method == .vni {
            #expect(wins.keys == "lan2" && wins.result == "làn")
            #expect(keep.keys == "lan22" && keep.result == "lan2")
        } else {
            #expect(wins.keys == "car" && wins.result == "cả")
            #expect(keep.keys == "carr" && keep.result == "car")
        }
    }

    @Test("adding marks to a typed word: hoc + nặng → học (D20)",
          arguments: DauSettings.TypingMethod.allCases)
    func addMarks(_ method: DauSettings.TypingMethod) {
        let example = SettingsExamples.addMarks(method)
        #expect(example.displayed == "hoc")
        #expect(example.result == "học")
    }

    @Test("UI.md caveat: dep + j gives dẹp, not đẹp")
    func depJ() {
        #expect(TypingPreview.type("j", options: EngineOptions(), after: "dep") == "dẹp")
    }
}
