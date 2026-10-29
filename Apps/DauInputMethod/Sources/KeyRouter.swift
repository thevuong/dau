import AppKit

/// What the controller does with one key-down event, decided from the event fields only.
/// Pure function so it can be unit tested without IMK (DauInputMethodTests).
enum KeyRoute: Equatable {
    /// Reset the engine and let the app handle the key: ⌘/⌃/⌥ shortcuts, arrows, Esc,
    /// navigation and function keys, dead keys, multi-character events (D4, D18).
    case ignore
    /// Delete key: `VietEngine.backspace()` (D32). 0x7F is never fed to `handle`.
    case backspace
    /// Return, Tab, keypad Enter: `VietEngine.endWord()`, then the app handles the key
    /// itself (a chat app must still send the message on Return).
    case endWord
    /// A character produced by the keyboard layout: `VietEngine.handle(_:)`.
    case character(Unicode.Scalar)
}

enum KeyRouter {
    // Virtual key codes (HIToolbox/Events.h, layout independent).
    static let keyReturn: UInt16 = 0x24
    static let keyTab: UInt16 = 0x30
    static let keyDelete: UInt16 = 0x33
    static let keyEscape: UInt16 = 0x35
    static let keyKeypadEnter: UInt16 = 0x4C
    static let keyForwardDelete: UInt16 = 0x75
    static let keyHome: UInt16 = 0x73
    static let keyEnd: UInt16 = 0x77
    static let keyPageUp: UInt16 = 0x74
    static let keyPageDown: UInt16 = 0x79
    static let keyLeft: UInt16 = 0x7B
    static let keyRight: UInt16 = 0x7C
    static let keyDown: UInt16 = 0x7D
    static let keyUp: UInt16 = 0x7E

    /// Modifiers that turn a key into a shortcut or an alternate character: reset only (D4).
    static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option]

    /// - Parameters:
    ///   - characters: `NSEvent.characters`, read only for key-down events (it throws for
    ///     other event types). nil or empty for dead keys.
    static func route(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String?) -> KeyRoute {
        if !modifiers.intersection(shortcutModifiers).isEmpty { return .ignore }
        switch keyCode {
        case keyDelete:
            return .backspace
        case keyReturn, keyTab, keyKeypadEnter:
            return .endWord
        case keyEscape, keyForwardDelete, keyHome, keyEnd, keyPageUp, keyPageDown,
             keyLeft, keyRight, keyDown, keyUp:
            return .ignore
        default:
            break
        }
        guard let characters else { return .ignore }
        var scalars = characters.unicodeScalars.makeIterator()
        guard let scalar = scalars.next(), scalars.next() == nil else { return .ignore }
        // Control characters and the private-use range AppKit uses for function keys
        // (NSUpArrowFunctionKey…) reset; the engine would do the same, but routing them
        // here keeps the cursor tracker honest.
        let v = scalar.value
        if v < 0x20 || v == 0x7F || (v >= 0xF700 && v <= 0xF8FF) { return .ignore }
        return .character(scalar)
    }
}
