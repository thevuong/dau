import AppKit
import SwiftUI

/// Hides the window's own title text: each page shows its title in its header, at
/// the same place in every section. The title stays set, so the Window menu, Mission
/// Control and VoiceOver still read it.
struct HiddenWindowTitle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TitleHidingView() }
    func updateNSView(_ view: NSView, context: Context) {
        (view as? TitleHidingView)?.apply()
    }

    final class TitleHidingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            window?.titleVisibility = .hidden
        }
    }
}
