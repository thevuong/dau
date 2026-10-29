import AppKit
import Testing

@Suite("KeyRouter")
struct KeyRouterTests {
    private func route(_ keyCode: UInt16, _ characters: String?, _ modifiers: NSEvent.ModifierFlags = []) -> KeyRoute {
        KeyRouter.route(keyCode: keyCode, modifiers: modifiers, characters: characters)
    }

    @Test("letters, digits, space and punctuation go to the engine")
    func characters() {
        #expect(route(0x00, "a") == .character("a"))
        #expect(route(0x00, "A", .shift) == .character("A"))
        #expect(route(0x00, "A", .capsLock) == .character("A"))
        #expect(route(0x12, "1") == .character("1"))
        #expect(route(0x31, " ") == .character(" "))
        #expect(route(0x2B, ",") == .character(","))
        #expect(route(0x21, "[") == .character("["))
    }

    @Test("⌘, ⌃, ⌥ shortcuts only reset (D4)")
    func shortcuts() {
        #expect(route(0x00, "a", .command) == .ignore)
        #expect(route(0x00, "a", .control) == .ignore)
        #expect(route(0x0E, "´", .option) == .ignore)
        #expect(route(0x33, "\u{7F}", .option) == .ignore)
        #expect(route(0x24, "\r", .command) == .ignore)
    }

    @Test("Delete goes to backspace, never to handle as 0x7F")
    func backspace() {
        #expect(route(0x33, "\u{7F}") == .backspace)
        #expect(route(0x33, "\u{7F}", .shift) == .backspace)
    }

    @Test("Return, Tab and keypad Enter end the word and stay with the app")
    func endWord() {
        #expect(route(0x24, "\r") == .endWord)
        #expect(route(0x24, "\r", .shift) == .endWord)
        #expect(route(0x30, "\t") == .endWord)
        #expect(route(0x30, "\u{19}", .shift) == .endWord)
        #expect(route(0x4C, "\u{03}") == .endWord)
    }

    @Test("arrows, Esc, navigation and function keys only reset (D4)")
    func navigation() {
        #expect(route(0x7B, "\u{F702}", [.function, .numericPad]) == .ignore)
        #expect(route(0x7E, "\u{F700}", [.function, .numericPad]) == .ignore)
        #expect(route(0x35, "\u{1B}") == .ignore)
        #expect(route(0x75, "\u{F728}", .function) == .ignore)
        #expect(route(0x73, "\u{F729}", .function) == .ignore)
        // F5 has no dedicated route: its private-use character resets.
        #expect(route(0x60, "\u{F708}", .function) == .ignore)
    }

    @Test("D18: dead keys, empty or multi-character events never reach the engine")
    func malformed() {
        #expect(route(0x00, nil) == .ignore)
        #expect(route(0x00, "") == .ignore)
        #expect(route(0x00, "ab") == .ignore)
        #expect(route(0x00, "\u{0}") == .ignore)
        #expect(route(0xFFFF, "a") == .character("a"))
    }

    @Test("an emoji is one scalar and goes to the engine as a word-ending character")
    func emoji() {
        #expect(route(0x00, "😀") == .character("😀"))
    }
}
