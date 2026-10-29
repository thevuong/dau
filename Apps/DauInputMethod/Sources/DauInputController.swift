import AppKit
import InputMethodKit
import DauEngine
import DauShared

/// One instance per client (text field). M0 scaffold: every key passes through to the app.
/// imk-dev wires VietEngine in M2 (one engine per controller, no global state).
///
/// The Objective-C name is pinned so Info.plist `InputMethodServerControllerClass`
/// does not depend on the Swift module name.
@objc(DauInputController)
final class DauInputController: IMKInputController {
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // D18: event may be nil or malformed; never crash on IMK input.
        false
    }
}
