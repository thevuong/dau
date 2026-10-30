import Foundation
import Testing
@testable import DauShared

@Suite("Input method quit request (D7, D16)")
struct InputMethodLifecycleTests {
    @Test("the name derives from the bundle ID, so it survives upgrades (D37)")
    func name() {
        #expect(InputMethodLifecycle.quitNotificationName(inputMethodBundleID: "com.codefastlabs.dau.inputmethod.Dau")
                == "com.codefastlabs.dau.inputmethod.Dau.quitRequested")
    }

    @Test("a posted request reaches the observer of that bundle ID only")
    func observe() throws {
        let id = "dau.tests.im." + UUID().uuidString
        let heard = DispatchSemaphore(value: 0)
        let other = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "dau.tests.quit")
        let observer = try #require(InputMethodLifecycle.observeQuitRequests(inputMethodBundleID: id, on: queue) {
            heard.signal()
        })
        let otherObserver = try #require(InputMethodLifecycle.observeQuitRequests(inputMethodBundleID: id + ".other", on: queue) {
            other.signal()
        })
        InputMethodLifecycle.requestQuit(inputMethodBundleID: id)
        #expect(heard.wait(timeout: .now() + 2) == .success)
        #expect(other.wait(timeout: .now() + 0.3) == .timedOut)
        withExtendedLifetime((observer, otherObserver)) {}
    }
}
