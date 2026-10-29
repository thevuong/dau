import AppKit
import SwiftUI

/// The system search field (NSSearchField) at a fixed width. SwiftUI's `.searchable`
/// only places one field per column and sizes it itself; the mockup has a 180 pt field
/// beside the + button in the Apps header and one inside the add-rule sheet.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.setAccessibilityLabel(prompt)
        field.sendsSearchStringImmediately = true
        // Mockup: 28 pt tall pill.
        field.controlSize = .large
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed(_:))
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        context.coordinator.text = $text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        @objc func changed(_ sender: NSSearchField) {
            text.wrappedValue = sender.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField {
                text.wrappedValue = field.stringValue
            }
        }
    }
}
