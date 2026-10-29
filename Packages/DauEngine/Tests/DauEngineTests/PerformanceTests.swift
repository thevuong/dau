import Testing
import DauEngine

/// Group 7 — cost of `handle` per key on a long mixed Vietnamese/English text.
/// Run `swift test -c release --filter Performance` for release numbers; the bound
/// below is loose so debug builds pass too.
@Suite("7. Hiệu năng", .serialized)
struct PerformanceTests {
    static let paragraph = """
        Trong khi ddos, nhuwngx nguwowif daan toocj Vieetj Nam vaanx giuwx gifn truyeenf thoongs \
        vawn hoas. Hoom nay trowif ddepj quas, chungs tooi ddi chowi coong vieen vaf awn kem. \
        Muoons gox tieengs Vieetj nhanh thif phair luyeenj taapj thuwowngf xuyeen; khuyeen, \
        nguyeenx, quaanf, quoocs, giuwax, gioongs, nghieeng, khoer, thuowr, huowu, ruowuj. \
        The quick brown fox jumps over the lazy dog: windows, Hasaki, test, carr, sexx, email! \
        Backspace⌫⌫ (ddaay laf ⌫ thuwr) 2024 vaf h2o.

        """

    static let vniParagraph = """
        Trong khi d9o1, nhu7ng4 ngu7o7i2 da6n to6c5 Vie6t5 Nam va6n4 giu7 gi4n truye6n2 tho6ng1 \
        va8n hoa1. Ho6m nay tro7i2 d9ep5 qua1, chu1ng to6i d9i cho7i co6ng vie6n va2 a8n kem. \
        Muo6n1 go4 tie6ng1 Vie6t5 nhanh thi2 pha3i luye6n5 ta6p5 thu7o7ng2 xuye6n; khuye6n, \
        nguye6n4, qua6n2, quo6c1, giu7a4, gio6ng1, nghie6ng, khoe3, thuo73, huo7u, ruou75. \
        The quick brown fox jumps over the lazy dog: windows, Hasaki, a11, mp3, Win10, email! \
        Backspace⌫⌫ (d9a6y la2 ⌫ thu73) 2024 va2 h2o.

        """

    static func keys(count: Int, from paragraph: String = paragraph) -> [Unicode.Scalar] {
        var keys: [Unicode.Scalar] = []
        keys.reserveCapacity(count + 600)
        while keys.count < count { keys.append(contentsOf: paragraph.unicodeScalars) }
        return keys
    }

    @Test func handleCostPerKey() {
        measure("Telex", PerformanceTests.keys(count: 60_000), EngineOptions())
    }

    @Test func handleCostPerKeyVNI() {
        measure("VNI", PerformanceTests.keys(count: 60_000, from: PerformanceTests.vniParagraph), vni)
    }

    func measure(_ name: String, _ keys: [Unicode.Scalar], _ options: EngineOptions) {
        let clock = ContinuousClock()
        var best = Duration.seconds(1_000)
        var replaces = 0
        for _ in 0..<5 {
            var engine = VietEngine(options: options)
            var replacesThisRun = 0
            let elapsed = clock.measure {
                for key in keys {
                    let action: Action
                    if key == "⌫" {
                        action = engine.backspace()
                    } else {
                        action = engine.handle(key)
                    }
                    if case .replace = action { replacesThisRun += 1 }
                }
            }
            replaces = replacesThisRun
            if elapsed < best { best = elapsed }
        }
        let nanoseconds = Double(best.components.seconds) * 1e9 + Double(best.components.attoseconds) / 1e9
        let perKey = nanoseconds / Double(keys.count)
        print("DAU-PERF handle \(name): \(keys.count) keys, best of 5 = \(nanoseconds / 1e6) ms, \(perKey / 1000) µs/key, \(replaces) replacements")
        #expect(replaces > 0)
        #expect(perKey < 50_000, "handle took \(perKey) ns per key")
    }
}
