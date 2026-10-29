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

    static func keys(count: Int) -> [Unicode.Scalar] {
        var keys: [Unicode.Scalar] = []
        keys.reserveCapacity(count + 600)
        while keys.count < count { keys.append(contentsOf: paragraph.unicodeScalars) }
        return keys
    }

    @Test func handleCostPerKey() {
        let keys = PerformanceTests.keys(count: 60_000)
        let clock = ContinuousClock()
        var best = Duration.seconds(1_000)
        var replaces = 0
        for _ in 0..<5 {
            var engine = VietEngine()
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
        print("DAU-PERF handle: \(keys.count) keys, best of 5 = \(nanoseconds / 1e6) ms, \(perKey / 1000) µs/key, \(replaces) replacements")
        #expect(replaces > 0)
        #expect(perKey < 50_000, "handle took \(perKey) ns per key")
    }
}
