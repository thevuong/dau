import Testing
@testable import DauEngine

@Suite("M0 scaffold")
struct EnginePlaceholderTests {
    @Test("module links and is usable from tests")
    func moduleLinks() {
        #expect(EnginePlaceholder.moduleName.description == "DauEngine")
    }
}
