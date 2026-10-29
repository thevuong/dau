import AppKit
import SwiftUI

/// The system segmented control (NSSegmentedControl), with segments of equal width
/// filling the width it is given. SwiftUI's segmented `Picker` on macOS keeps its
/// intrinsic width and centers itself, whatever frame it gets; the mockup's "Kiểu gõ"
/// control spans the card and "Vị trí dấu thanh" is 220 pt wide.
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
        let control = NSSegmentedControl(labels: options.map(\.1), trackingMode: .selectOne,
                                         target: context.coordinator,
                                         action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        // The system height (24 pt on macOS 27, also for larger control sizes).
        control.controlSize = .large
        control.setAccessibilityLabel(label)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.isEnabled = context.environment.isEnabled
        if let index = options.firstIndex(where: { $0.0 == selection }), control.selectedSegment != index {
            control.selectedSegment = index
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
