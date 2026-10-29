import Testing
import DauEngine

/// Expects `keys` to produce exactly `expected`, scalar for scalar (so NFC is
/// enforced, D3). Expected values follow Vietnamese orthography and DECISIONS.md,
/// never OpenKey's output (D10).
func expectTyped(
    _ keys: String,
    _ expected: String,
    _ options: EngineOptions = EngineOptions(),
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var t = Typist(options)
    t.type(keys)
    #expect(
        t.text.map(\.value) == scalars(expected),
        "\"\(keys)\" gave \"\(t.string)\", expected \"\(expected)\"",
        sourceLocation: sourceLocation
    )
}

/// A key script and the text it must produce.
struct Case: Sendable, CustomTestStringConvertible {
    let keys: String
    let expected: String
    init(_ keys: String, _ expected: String) {
        self.keys = keys
        self.expected = expected
    }
    var testDescription: String { "\(keys) → \(expected)" }
}
