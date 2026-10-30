// Checks the captures written by `Dau --capture-window` (see run.sh, docs/UI-CHECKS.md).
// Window 820×600 pt, captures @2x, frames in top-left window points.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sections = ["typing", "smart", "apps", "updates"]
let modes = ["light", "dark"]
let styles = ["WhenScrolling", "Always", "Automatic"]
let scrolls = ["0", "60"]
let W: CGFloat = 820, H: CGFloat = 600

typealias Frames = [String: CGRect]
struct Pixel { var r, g, b: Double
    func distance(_ o: Pixel) -> Double { max(abs(r - o.r), abs(g - o.g), abs(b - o.b)) }
}

func loadFrames(_ dir: URL) -> [String: Frames] {
    guard let data = try? Data(contentsOf: dir.appendingPathComponent("frames.json")),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: [Double]]] else { return [:] }
    var out: [String: Frames] = [:]
    for (key, entries) in json where !key.hasPrefix("colors") {
        var frames: Frames = [:]
        for (name, v) in entries where v.count == 4 { frames[name] = CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
        out[key] = frames
    }
    return out
}

func image(_ url: URL) -> NSBitmapImageRep? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return NSBitmapImageRep(data: data)
}

func pixel(_ rep: NSBitmapImageRep, _ x: CGFloat, _ y: CGFloat) -> Pixel {
    let scale = CGFloat(rep.pixelsWide) / W
    var p = [Int](repeating: 0, count: 4)
    rep.getPixel(&p, atX: min(max(Int(x * scale), 0), rep.pixelsWide - 1),
                 y: min(max(Int(y * scale), 0), rep.pixelsHigh - 1))
    return Pixel(r: Double(p[0]), g: Double(p[1]), b: Double(p[2]))
}

var failures: [String] = []
var results: [(String, String, [String: Bool])] = []   // run, mode, check → pass
func fail(_ s: String) { failures.append(s) }

for style in styles {
    for scroll in scrolls {
        let run = "\(style)-\(scroll)"
        let dir = root.appendingPathComponent(run)
        let frames = loadFrames(dir)
        for mode in modes {
            var checks: [String: Bool] = ["a": true, "b": true, "c": true, "d": true, "e": true]
            func bad(_ check: String, _ message: String) { checks[check] = false; fail("\(run) \(mode) (\(check)) \(message)") }

            // (a) Same frames in every section. Positions (x, y) must be equal; widths
            // may differ only by the legacy scroll bar's width, and only on a section
            // that shows one (its clip view is narrower than its scroll view).
            let legacyWidth = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
            func room(_ section: String) -> CGFloat? {
                guard let f = frames["\(section)-\(mode)"], let sv = f["scrollView"], let clip = f["clip"] else { return nil }
                return sv.width - clip.width
            }
            for section in sections {
                if let r = room(section), abs(r) > 0.5, abs(r - legacyWidth) > 0.5 {
                    bad("a", "\(section) scroll bar takes \(r) pt, not the legacy width \(legacyWidth)")
                }
            }
            func same(_ name: String, width: Bool, y: Bool = true) {
                var values: [String] = []
                for section in sections {
                    guard let r = frames["\(section)-\(mode)"]?[name] else { continue }
                    let w = width ? r.width + (room(section) ?? 0) : 0
                    values.append("\(r.minX),\(y ? r.minY : 0),\(w)")
                }
                if values.count != sections.count { bad("a", "\(name) missing"); return }
                if Set(values).count > 1 { bad("a", "\(name) differs (x, y, width + scroll bar): \(values)") }
            }
            same("content", width: true)
            // The first card's y depends on whether the page starts with a group title.
            same("firstCard", width: true, y: false)
            same("title", width: false)
            same("close", width: false)
            if Set(sections.compactMap { frames["\($0)-\(mode)"]?["close"] }).count > 1 { bad("a", "close size differs") }

            for section in sections {
                let key = "\(section)-\(mode)"
                guard let f = frames[key], let rep = image(dir.appendingPathComponent("\(key).png")) else {
                    bad("a", "\(key) capture missing"); continue
                }
                let scroller = f["scroller"].flatMap { $0.width > 0 ? $0 : nil }
                // Page color: left padding of the content, above the rounded corners.
                let low = H - 40
                let page = pixel(rep, 226, low)

                // (b) Page background and the header separator reach the right edge (or
                // the system scroll bar, which then sits at the edge).
                let edgeX = (scroller.map { $0.minX <= W - 10 && $0.maxY > low } ?? false) ? scroller!.minX - 2 : W - 2
                if page.distance(pixel(rep, edgeX, low)) > 6 {
                    bad("b", "\(key) page color stops before the right edge (x \(edgeX))")
                }
                if let s = scroller, s.maxX < W - 0.5 {
                    bad("b", "\(key) scroll bar ends at \(s.maxX), not at the window edge")
                }
                func separatorRow(_ x: CGFloat) -> Int? {
                    let above = pixel(rep, x, 46)
                    var best: (Int, Double)?
                    for half in 96...112 {   // y 48–56 pt in half points
                        let d = pixel(rep, x, CGFloat(half) / 2).distance(above)
                        if d > (best?.1 ?? 3) { best = (half, d) }
                    }
                    return best?.0
                }
                let midRow = separatorRow(600), edgeRow = separatorRow(W - 3)
                if midRow == nil || edgeRow == nil || abs((midRow ?? 0) - (edgeRow ?? 0)) > 1 {
                    bad("b", "\(key) header separator does not reach the right edge (\(String(describing: midRow)) vs \(String(describing: edgeRow)))")
                }

                // (c) No strip of another color at the right edge, except the scroll bar.
                var stray = 0
                for x in stride(from: W - 24, to: W, by: 1) {
                    for y in stride(from: 64, to: H - 40, by: 16) {
                        if let s = scroller, s.insetBy(dx: -1, dy: -1).contains(CGPoint(x: x, y: y)) { continue }
                        if pixel(rep, x, y).distance(page) > 6 { stray += 1 }
                    }
                }
                if stray > 0 { bad("c", "\(key) \(stray) right-edge samples differ from the page color") }

                // (d) Scrolled: the header looks as when not scrolled; scroll bar inside
                // the window right below the header.
                if scroll != "0", section == "updates" {
                    if let base = image(root.appendingPathComponent("\(style)-0/\(key).png")) {
                        var diff = 0.0, n = 0.0
                        for x in stride(from: CGFloat(390), to: 540, by: 6) {
                            for y in stride(from: CGFloat(6), to: 46, by: 4) {
                                diff += pixel(rep, x, y).distance(pixel(base, x, y)); n += 1
                            }
                        }
                        if diff / n > 4 { bad("d", "\(key) content shows through the header (mean diff \(Int(diff / n)))") }
                    }
                    if let s = scroller {
                        if s.maxX > W + 0.5 || s.minX < 700 || s.minY < 51 { bad("d", "\(key) scroll bar at \(s)") }
                    } else {
                        bad("d", "\(key) no scroll bar")
                    }
                }

                // (e) Traffic lights, title, Apps search field and + button.
                if f["close"] != CGRect(x: 19, y: 19, width: 14, height: 14) { bad("e", "\(key) close at \(String(describing: f["close"]))") }
                // The toolbar places the title and the header controls, and the exact spot moves
                // between macOS updates (27.0: title x 245, search x 556; 27.2: 241 and 548).
                // Check a band and the relations instead; the same-across-sections check above
                // still catches a shift when switching sections.
                if let t = f["title"], t.minX < 236 || t.minX > 250 || abs(t.minY - 16.5) > 1 { bad("e", "\(key) title at \(t)") }
                if section == "apps" {
                    guard let s = f["headerSearch"], let a = f["headerAdd"] else { bad("e", "\(key) header controls missing"); continue }
                    if abs(s.width - 200) > 1 || s.minX < (f["title"]?.maxX ?? 0) + 40 { bad("e", "\(key) search at \(s)") }
                    if a.minX < s.maxX + 8 || a.maxX > W - 20 { bad("e", "\(key) + at \(a), search ends \(s.maxX)") }
                }
            }
            results.append((run, mode, checks))
        }
    }
}

// Summary grid: one row per run, light then dark of each section, quarter size.
let cellW = 410, cellH = 300
let rows = styles.count * scrolls.count, cols = sections.count * modes.count
if let grid = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cellW * cols, pixelsHigh: cellH * rows,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: grid)
    for (r, run) in styles.flatMap({ s in scrolls.map { "\(s)-\($0)" } }).enumerated() {
        for (c, item) in modes.flatMap({ m in sections.map { ($0, m) } }).enumerated() {
            let url = root.appendingPathComponent("\(run)/\(item.0)-\(item.1).png")
            NSImage(contentsOf: url)?.draw(in: CGRect(x: c * cellW, y: (rows - 1 - r) * cellH, width: cellW, height: cellH))
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try? grid.representation(using: .png, properties: [:])?.write(to: root.appendingPathComponent("matrix-grid.png"))
}

print("run | mode | a frames | b to edge | c no strip | d scrolled | e positions")
for (run, mode, c) in results {
    print(([run, mode] + ["a", "b", "c", "d", "e"].map { c[$0]! ? "ok" : "FAIL" }).joined(separator: " | "))
}
failures.forEach { print("FAIL", $0) }
print(failures.isEmpty ? "All UI checks passed." : "\(failures.count) check(s) failed.")
exit(failures.isEmpty ? 0 : 1)
