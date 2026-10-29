// Small helper for scripts/selftest-app-group.sh.
//
//   input-source current          prints the ID of the selected keyboard input source
//   input-source select <ID>      selects an input source that is ALREADY enabled
//   input-source enabled <prefix> prints enabled, selectable sources whose ID starts with prefix
//
// It never enables, disables, adds or removes an input source (N4): `select` refuses a
// source that is not enabled and select-capable. The self test uses it only to reselect
// Dấu (so macOS launches the input method) and to give back the source that was selected
// before.
import Carbon
import Foundation

func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
}

func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let raw = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue())
}

/// Enabled, select-capable sources (TISCreateInputSourceList with includeAllInstalled
/// false lists enabled sources only).
func enabledSources() -> [TISInputSource] {
    let filter = [kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
        return []
    }
    return list.filter { boolProperty($0, kTISPropertyInputSourceIsEnabled) }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "current":
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let id = stringProperty(source, kTISPropertyInputSourceID) else {
        fail("no current input source")
    }
    print(id)

case "enabled":
    let prefix = arguments.count > 1 ? arguments[1] : ""
    for source in enabledSources() {
        if let id = stringProperty(source, kTISPropertyInputSourceID), id.hasPrefix(prefix) {
            print(id)
        }
    }

case "select":
    guard arguments.count > 1 else { fail("usage: input-source select <ID>", code: 2) }
    let wanted = arguments[1]
    guard let source = enabledSources().first(where: {
        stringProperty($0, kTISPropertyInputSourceID) == wanted
    }) else {
        fail("\(wanted) is not an enabled, selectable input source; not touching it (N4)")
    }
    let status = TISSelectInputSource(source)
    guard status == noErr else { fail("TISSelectInputSource(\(wanted)) failed: \(status)") }

default:
    fail("usage: input-source current | enabled <prefix> | select <ID>", code: 2)
}
