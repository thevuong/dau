// Saves and restores the general pasteboard, every item and every type, so the typing
// self test can read text through ⌘C without losing what the user had copied.
//
//   clipboard save <file>      writes the pasteboard to <file> (property list)
//   clipboard restore <file>   puts it back, then deletes <file>
//   clipboard text             prints the pasteboard's plain text (UTF-8)
import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let pasteboard = NSPasteboard.general
let arguments = Array(CommandLine.arguments.dropFirst())

switch (arguments.first, arguments.count) {
case ("save"?, 2):
    // [[type: data]] — one dictionary per pasteboard item.
    let items: [[String: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
        var types: [String: Data] = [:]
        for type in item.types {
            if let data = item.data(forType: type) { types[type.rawValue] = data }
        }
        return types
    }
    do {
        let data = try PropertyListSerialization.data(fromPropertyList: items, format: .binary, options: 0)
        try data.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
    } catch {
        fail("cannot save the clipboard: \(error)")
    }

case ("restore"?, 2):
    let url = URL(fileURLWithPath: arguments[1])
    guard let data = try? Data(contentsOf: url),
          let items = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Data]] else {
        fail("cannot read \(arguments[1])")
    }
    pasteboard.clearContents()
    let restored: [NSPasteboardItem] = items.map { types in
        let item = NSPasteboardItem()
        for (type, value) in types { item.setData(value, forType: NSPasteboard.PasteboardType(type)) }
        return item
    }
    if !restored.isEmpty, !pasteboard.writeObjects(restored) { fail("cannot restore the clipboard") }
    try? FileManager.default.removeItem(at: url)

case ("text"?, 1):
    print(pasteboard.string(forType: .string) ?? "", terminator: "")

default:
    fail("usage: clipboard save <file> | restore <file> | text")
}
