import DauEngine

/// Simulates a text field driven by the engine the way the IMK layer will drive it:
/// `.passThrough` lets the app insert the key itself, `.replace` deletes and inserts.
///
/// Key script notation:
/// - `⌫` Backspace (`engine.backspace()`)
/// - `←` an arrow key (`engine.reset()`, no restore — D4)
/// - `⏎` Return handled through `engine.endWord()` and then passed to the app as "\n"
/// - everything else goes through `engine.handle(_:)`.
struct Typist {
    var engine: VietEngine
    var text: [Unicode.Scalar] = []

    init(_ options: EngineOptions = EngineOptions()) {
        engine = VietEngine(options: options)
    }

    mutating func apply(_ action: Action, passing key: Unicode.Scalar?) {
        switch action {
        case .passThrough:
            if let key { text.append(key) }
        case .replace(let deleteCount, let insert):
            precondition(deleteCount <= text.count, "engine deleted more than the field holds")
            text.removeLast(deleteCount)
            text.append(contentsOf: insert)
        }
    }

    mutating func type(_ keys: String) {
        for key in keys.unicodeScalars {
            switch key {
            case "⌫":
                let action = engine.backspace()
                if case .passThrough = action {
                    if !text.isEmpty { text.removeLast() }
                } else {
                    apply(action, passing: nil)
                }
            case "←":
                engine.reset()
            case "⏎":
                apply(engine.endWord(), passing: nil)
                text.append("\n")
            default:
                apply(engine.handle(key), passing: key)
            }
        }
    }

    /// Puts `displayed` in the field as if it was already there, then seeds the engine
    /// from it (D20), as the IMK layer will do when the buffer is empty.
    mutating func seed(_ displayed: String) -> Bool {
        text.append(contentsOf: displayed.unicodeScalars)
        return engine.seed(displayed: displayed.unicodeScalars)
    }

    var string: String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: text)
        return String(view)
    }
}

/// Types `keys` into a fresh field and returns the field's text.
func typed(_ keys: String, _ options: EngineOptions = EngineOptions()) -> String {
    var t = Typist(options)
    t.type(keys)
    return t.string
}

/// Field text as raw scalars, to assert NFC output exactly (Swift `String ==` uses
/// canonical equivalence and would accept decomposed text).
func typedScalars(_ keys: String, _ options: EngineOptions = EngineOptions()) -> [UInt32] {
    var t = Typist(options)
    t.type(keys)
    return t.text.map(\.value)
}

func scalars(_ s: String) -> [UInt32] { s.unicodeScalars.map(\.value) }

let classic = EngineOptions(tonePlacement: .classic)
let simpleTelex = EngineOptions(inputMethod: .simpleTelex)
let noFreeMarking = EngineOptions(freeMarking: false)
let noRestore = EngineOptions(autoRestore: false)
let shortcuts = EngineOptions(advanced: .consonantShortcuts)
let zfwj = EngineOptions(advanced: .allowZFWJ)
