import Testing
@testable import DauShared

@Suite("M0 scaffold")
struct SharedPlaceholderTests {
    @Test("module links and exposes the App Group Info.plist key")
    func moduleLinks() {
        #expect(SharedPlaceholder.appGroupInfoKey == "DauAppGroupIdentifier")
    }
}
