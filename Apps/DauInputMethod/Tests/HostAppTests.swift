import Foundation
import Testing

@Suite("HostApp (input menu › Cài đặt Dấu…)")
struct HostAppTests {
    @Test("the app an input method bundle is nested in")
    func enclosingApp() {
        let nested = URL(fileURLWithPath: "/Applications/Dau.app/Contents/Library/Input Methods/DauInputMethod.app")
        #expect(HostApp.enclosingApp(of: nested)?.path == "/Applications/Dau.app")
    }

    @Test("an installed copy is not nested in any app")
    func installedCopy() {
        let installed = URL(fileURLWithPath: "/Users/someone/Library/Input Methods/DauInputMethod.app")
        #expect(HostApp.enclosingApp(of: installed) == nil)
        #expect(HostApp.enclosingApp(of: URL(fileURLWithPath: "/DauInputMethod.app")) == nil)
    }
}

@Suite("HostApp choice among copies")
struct HostAppChoiceTests {
    @Test("an Applications folder wins over build folders")
    func preferApplications() {
        let build = URL(fileURLWithPath: "/Users/someone/dau/build/DerivedData/Build/Products/Debug/Dau.app")
        let installed = URL(fileURLWithPath: "/Applications/Dau.app")
        #expect(HostApp.preferred([build, installed]) == installed)
        #expect(HostApp.preferred([build]) == build)
        #expect(HostApp.preferred([]) == nil)
    }

    @Test("versions match only when both parts are known and equal")
    func versions() {
        typealias V = HostApp.Version
        #expect(V(short: "0.1.0", build: "1") == V(short: "0.1.0", build: "1"))
        #expect(V(short: "0.1.0", build: "1") != V(short: "0.1.0", build: "2"))
        #expect(V(short: "0.1.0", build: "1") != V(short: "0.2.0", build: "1"))
        #expect(V(short: nil, build: nil) != V(short: nil, build: nil))
    }
}
