import AppKit
import SwiftUI

/// The system segmented control (NSSegmentedControl), with segments of equal width
/// filling the width it is given, and a neutral selected segment as in the mockup.
///
/// - Width: SwiftUI's segmented `Picker` on macOS keeps its intrinsic width and
///   centers itself whatever frame it gets; the mockup's "Kiểu gõ" spans the card.
/// - Selection: in an active window macOS fills the selected segment with the accent
///   color; the mockup shows it neutral (light: white, dark: #636366). The bezel is
///   set to `controlColor` (white in light mode, white at 25 % in dark mode, which
///   over the track gives that gray). AppKit picks the text color of a tinted segment
///   itself, so segment titles are drawn as images: semibold `labelColor` for the
///   selected one, regular template text for the others (AppKit tints it). The image
///   descriptions carry the titles for VoiceOver.
struct SegmentedPicker<Value: Hashable>: NSViewRepresentable {
    let label: String
    let options: [(Value, String)]
    @Binding var selection: Value

    init(_ label: String, selection: Binding<Value>, options: [(Value, String)]) {
        self.label = label
        self._selection = selection
        self.options = options
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: options.map { _ in "" }, trackingMode: .selectOne,
                                         target: context.coordinator,
                                         action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.selectedSegmentBezelColor = .controlColor
        control.setAccessibilityLabel(label)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.isEnabled = context.environment.isEnabled
        let selected = options.firstIndex(where: { $0.0 == selection }) ?? -1
        if control.selectedSegment != selected { control.selectedSegment = selected }
        for (index, option) in options.enumerated() {
            control.setImage(SegmentTitle.image(option.1, selected: index == selected), forSegment: index)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsic.width, height: intrinsic.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: SegmentedPicker

        init(parent: SegmentedPicker) { self.parent = parent }

        @objc func changed(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard parent.options.indices.contains(index) else { return }
            parent.selection = parent.options[index].0
        }
    }
}

/// A segment title as an image: 13 pt, semibold `labelColor` when selected (drawn at
/// display time, so it follows the appearance), regular template text otherwise.
enum SegmentTitle {
    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor static func image(_ title: String, selected: Bool) -> NSImage {
        let key = "\(selected ? 1 : 0)\(title)"
        if let image = cache[key] { return image }
        let font = NSFont.systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
        let size = (title as NSString).size(withAttributes: [.font: font])
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
            (title as NSString).draw(in: rect, withAttributes: [
                .font: font,
                .foregroundColor: selected ? NSColor.labelColor : NSColor.black,
            ])
            return true
        }
        image.isTemplate = !selected
        image.accessibilityDescription = title
        cache[key] = image
        return image
    }
}
