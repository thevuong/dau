// Builds the temporary app icon for Dấu: "ấ" in Giấy on a Mực plate, the circumflex in the
// letter colour and only the acute in Son (docs/BRAND.md "Biểu tượng", D25).
//
// The letter is outlined: glyph contours are extracted once from Be Vietnam Pro (SIL OFL 1.1)
// into Resources/Brand/app-icon-glyphs.txt, so rendering never needs the font. The font file
// itself is never committed.
//
// TODO(M7): the official icon is built in Icon Composer (Default / Dark / Clear / Tinted
// appearances on macOS 26+) plus an .icns for macOS 14–15; this script is a stand-in.
//
// Usage (normally via scripts/make-app-icon.sh):
//   make-app-icon.swift outline <BeVietnamPro-*.ttf> <glyphs.txt>
//       Extract the contours of "ấ" (a, circumflex, acute) in font units, y up.
//   make-app-icon.swift render <glyphs.txt> <svg-dir> <appiconset-dir> [<preview-dir>]
//       Write the SVG sources (one per size variant), the AppIcon.appiconset PNGs and
//       Contents.json, and optionally icon-512.png + sizes.png for review.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Path model (canvas space: 1024 × 1024, y down, like SVG)

enum Cmd {
    case move(CGPoint)
    case line(CGPoint)
    case quad(CGPoint, CGPoint)            // control, end
    case cubic(CGPoint, CGPoint, CGPoint)  // control 1, control 2, end
    case close
}

typealias Path = [Cmd]

func fmt(_ v: CGFloat) -> String {
    let r = (v * 100).rounded() / 100
    if r == r.rounded() { return String(Int(r)) }
    return String(format: "%.2f", Double(r))
        .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
}

func svgData(_ path: Path) -> String {
    func p(_ q: CGPoint) -> String { "\(fmt(q.x)) \(fmt(q.y))" }
    return path.map { c -> String in
        switch c {
        case .move(let a): return "M\(p(a))"
        case .line(let a): return "L\(p(a))"
        case .quad(let c1, let a): return "Q\(p(c1)) \(p(a))"
        case .cubic(let c1, let c2, let a): return "C\(p(c1)) \(p(c2)) \(p(a))"
        case .close: return "Z"
        }
    }.joined(separator: " ")
}

/// Parses the absolute M/L/Q/C/Z subset written by `svgData` and by `outline`.
func parse(_ d: String) -> Path {
    var tokens: [String] = []
    var cur = ""
    for ch in d {
        if "MLQCZ".contains(ch) {
            if !cur.isEmpty { tokens.append(cur); cur = "" }
            tokens.append(String(ch))
        } else if ch == " " || ch == "," {
            if !cur.isEmpty { tokens.append(cur); cur = "" }
        } else {
            cur.append(ch)
        }
    }
    if !cur.isEmpty { tokens.append(cur) }
    var i = 0
    func num() -> CGFloat {
        defer { i += 1 }
        guard let v = Double(tokens[i]) else { fatalError("bad number \(tokens[i])") }
        return CGFloat(v)
    }
    func pt() -> CGPoint { let x = num(); return CGPoint(x: x, y: num()) }
    var out: Path = []
    while i < tokens.count {
        let op = tokens[i]; i += 1
        switch op {
        case "M": out.append(.move(pt()))
        case "L": out.append(.line(pt()))
        case "Q": let c = pt(); out.append(.quad(c, pt()))
        case "C": let c1 = pt(); let c2 = pt(); out.append(.cubic(c1, c2, pt()))
        case "Z": out.append(.close)
        default: fatalError("unsupported path command \(op)")
        }
    }
    return out
}

func transform(_ path: Path, _ f: (CGPoint) -> CGPoint) -> Path {
    path.map { c in
        switch c {
        case .move(let a): return .move(f(a))
        case .line(let a): return .line(f(a))
        case .quad(let c1, let a): return .quad(f(c1), f(a))
        case .cubic(let c1, let c2, let a): return .cubic(f(c1), f(c2), f(a))
        case .close: return .close
        }
    }
}

func cgPath(_ path: Path) -> CGPath {
    let p = CGMutablePath()
    for c in path {
        switch c {
        case .move(let a): p.move(to: a)
        case .line(let a): p.addLine(to: a)
        case .quad(let c1, let a): p.addQuadCurve(to: a, control: c1)
        case .cubic(let c1, let c2, let a): p.addCurve(to: a, control1: c1, control2: c2)
        case .close: p.closeSubpath()
        }
    }
    return p
}

func bounds(_ path: Path) -> CGRect { cgPath(path).boundingBoxOfPath }

// MARK: - outline: font → glyph contours

func outline(fontURL: URL, out: URL) throws {
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
          let desc = descs.first else { fatalError("cannot read font \(fontURL.path)") }
    let font = CTFontCreateWithFontDescriptor(desc, CGFloat(CTFontGetUnitsPerEm(CTFontCreateWithFontDescriptor(desc, 1, nil))), nil)
    var chars = Array("ấ".utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
          let glyphPath = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
        fatalError("font has no glyph for ấ")
    }
    // Split into contours.
    var contours: [Path] = []
    var cur: Path = []
    glyphPath.applyWithBlock { e in
        let el = e.pointee
        switch el.type {
        case .moveToPoint:
            if !cur.isEmpty { contours.append(cur) }
            cur = [.move(el.points[0])]
        case .addLineToPoint: cur.append(.line(el.points[0]))
        case .addQuadCurveToPoint: cur.append(.quad(el.points[0], el.points[1]))
        case .addCurveToPoint: cur.append(.cubic(el.points[0], el.points[1], el.points[2]))
        case .closeSubpath: cur.append(.close)
        @unknown default: break
        }
    }
    if !cur.isEmpty { contours.append(cur) }

    // Letter body: contours that stay below the top of the x-height overshoot.
    // Marks: the rest; the acute is the mark that sits furthest right (Vietnamese stacking).
    let xHeight = CTFontGetXHeight(font)
    var body: Path = []
    var marks: [Path] = []
    for c in contours {
        if bounds(c).maxY <= xHeight + 40 { body += c } else { marks.append(c) }
    }
    guard marks.count == 2 else { fatalError("expected 2 mark contours, found \(marks.count)") }
    marks.sort { bounds($0).midX < bounds($1).midX }
    let circumflex = marks[0], acute = marks[1]

    let name = CTFontCopyFullName(font) as String
    let version = (CTFontCopyName(font, kCTFontVersionNameKey) as String?) ?? "?"
    let text = """
    # Outlines of "ấ" from \(name) (\(version)), SIL Open Font License 1.1,
    # https://github.com/bettergui/BeVietnamPro (via github.com/google/fonts, ofl/bevietnampro).
    # Font units (\(CTFontGetUnitsPerEm(font))/em), y up, baseline 0. Generated by
    # scripts/make-app-icon.sh outline; the font file is not part of the repo.
    a \(svgData(body))
    circumflex \(svgData(circumflex))
    acute \(svgData(acute))

    """
    try text.write(to: out, atomically: true, encoding: .utf8)
    print("wrote \(out.path)")
}

// MARK: - Geometry

let canvas: CGFloat = 1024
// macOS (Big Sur and later) icon grid: 824 × 824 plate centred on the 1024 canvas,
// continuous ("squircle") corners with radius ≈ 185.4.
let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let plateRadius: CGFloat = 185.4

/// Rounded rect with continuous corners (the iOS 7+/macOS 11+ shape), y down.
/// Control points follow the widely published reconstruction of UIBezierPath's
/// continuous-corner curve; extent of each corner is 1.52866 × radius.
func squircle(_ r: CGRect, radius: CGFloat) -> Path {
    let k = min(radius, min(r.width, r.height) / 2 / 1.52866483)
    func tl(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: r.minX + a * k, y: r.minY + b * k) }
    func tr(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: r.maxX - a * k, y: r.minY + b * k) }
    func br(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: r.maxX - a * k, y: r.maxY - b * k) }
    func bl(_ a: CGFloat, _ b: CGFloat) -> CGPoint { CGPoint(x: r.minX + a * k, y: r.maxY - b * k) }
    typealias F = (CGFloat, CGFloat) -> CGPoint
    // One corner, starting on the horizontal edge and ending on the vertical edge (or the
    // reverse, depending on `f`): the same five segments for every corner.
    func corner(_ f: F, swap: Bool) -> Path {
        func q(_ a: CGFloat, _ b: CGFloat) -> CGPoint { swap ? f(b, a) : f(a, b) }
        return [
            .cubic(q(1.08849323, 0), q(0.86840689, 0), q(0.66993427, 0.06549600)),
            .line(q(0.63149399, 0.07491100)),
            .cubic(q(0.37282392, 0.16905899), q(0.16906013, 0.37282401), q(0.07491176, 0.63149399)),
            .cubic(q(0, 0.86840701), q(0, 1.08849299), q(0, 1.52866483)),
        ]
    }
    var p: Path = [.move(tl(1.52866483, 0)), .line(tr(1.52866483, 0))]
    p += corner(tr, swap: false)
    p.append(.line(br(0, 1.52866483)))
    p += corner(br, swap: true)
    p.append(.line(bl(1.52866483, 0)))
    p += corner(bl, swap: false)
    p.append(.line(tl(0, 1.52866483)))
    p += corner(tl, swap: true)
    p.append(.close)
    return p
}

/// Per-size adjustments. Small icons get thicker marks (BRAND.md: "Ở 16–32 pt tăng độ dày
/// nét dấu"), lifted a little so the circumflex does not merge with the letter, and a
/// slightly larger letter. Values are canvas units (1024 grid).
struct Variant {
    let name: String        // SVG file suffix
    let maxPixels: Int      // used for rendered sizes up to this many pixels
    let markStroke: CGFloat // extra outline width on circumflex and acute (fill colour)
    let letterStroke: CGFloat
    let markLift: CGFloat
    let scale: CGFloat
}

let variants: [Variant] = [
    Variant(name: "16", maxPixels: 16, markStroke: 40, letterStroke: 6, markLift: 72, scale: 1.12),
    Variant(name: "32", maxPixels: 32, markStroke: 26, letterStroke: 0, markLift: 36, scale: 1.05),
    Variant(name: "64", maxPixels: 64, markStroke: 12, letterStroke: 0, markLift: 12, scale: 1.0),
    Variant(name: "", maxPixels: .max, markStroke: 0, letterStroke: 0, markLift: 0, scale: 1.0),
]

func variant(forPixels px: Int) -> Variant { variants.first { px <= $0.maxPixels }! }

struct Colour {
    let hex: String
    var cg: CGColor {
        let v = Int(hex.dropFirst(), radix: 16)!
        return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

// docs/BRAND.md "Màu".
let muc = Colour(hex: "#10285A")   // Mực: plate
let giay = Colour(hex: "#F6F1E7")  // Giấy: letter and circumflex
let son = Colour(hex: "#E0533D")   // Son: acute only

struct Layer {
    let id: String
    let path: Path
    let fill: Colour
    let stroke: CGFloat
}

/// Letter height on the plate: font units → canvas units at the default size.
let baseScale: CGFloat = 0.62

func layers(glyphs: [String: Path], variant v: Variant) -> [Layer] {
    guard let a = glyphs["a"], let circ = glyphs["circumflex"], let acute = glyphs["acute"] else {
        fatalError("glyph file must define a, circumflex and acute")
    }
    let s = baseScale * v.scale
    // Centre the letter body horizontally (the acute hangs to the right, as in text), and
    // centre the whole stack (letter bottom to acute top) vertically, nudged down a touch
    // because the marks are lighter than the letter.
    let body = bounds(a)
    let all = bounds(a + circ + acute).union(bounds(acute).offsetBy(dx: 0, dy: v.markLift / s))
    let cx = plateRect.midX - s * body.midX + 6
    let cy = plateRect.midY + s * all.midY + 12  // canvas y of font baseline
    func place(_ lift: CGFloat) -> (CGPoint) -> CGPoint {
        { CGPoint(x: cx + s * $0.x, y: cy - s * $0.y - lift) }
    }
    return [
        Layer(id: "plate", path: squircle(plateRect, radius: plateRadius), fill: muc, stroke: 0),
        Layer(id: "a", path: transform(a, place(0)), fill: giay, stroke: v.letterStroke),
        Layer(id: "circumflex", path: transform(circ, place(v.markLift)), fill: giay, stroke: v.markStroke),
        Layer(id: "acute", path: transform(acute, place(v.markLift)), fill: son, stroke: v.markStroke),
    ]
}

// Drop shadow under the plate, as on the macOS icon template.
let shadowOffsetY: CGFloat = 10
let shadowBlur: CGFloat = 20
let shadowAlpha: CGFloat = 0.30

// MARK: - SVG

func svg(_ layers: [Layer], variant v: Variant) -> String {
    var lines = [
        #"<?xml version="1.0" encoding="UTF-8"?>"#,
        "<!-- Dấu app icon (temporary, docs/BRAND.md). Generated by scripts/make-app-icon.sh; do not edit by hand. -->",
        "<!-- Letter outlined from Be Vietnam Pro (SIL OFL 1.1); no font needed to render. -->",
        "<!-- TODO(M7): official icon is built in Icon Composer (Default/Dark/Clear/Tinted). -->",
    ]
    if !v.name.isEmpty {
        lines.append("<!-- Size variant for \(v.name) px and below: thicker marks. -->")
    }
    lines += [
        #"<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">"#,
        "  <defs>",
        #"    <filter id="shadow" x="-10%" y="-10%" width="120%" height="125%">"#,
        "      <feDropShadow dx=\"0\" dy=\"\(fmt(shadowOffsetY))\" stdDeviation=\"\(fmt(shadowBlur / 2))\" flood-color=\"#000\" flood-opacity=\"\(fmt(shadowAlpha))\"/>",
        "    </filter>",
        "  </defs>",
    ]
    for l in layers {
        var attrs = "id=\"\(l.id)\" fill=\"\(l.fill.hex)\""
        if l.stroke > 0 {
            attrs += " stroke=\"\(l.fill.hex)\" stroke-width=\"\(fmt(l.stroke))\" stroke-linejoin=\"round\""
        }
        if l.id == "plate" { attrs += " filter=\"url(#shadow)\"" }
        lines.append("  <path \(attrs) d=\"\(svgData(l.path))\"/>")
    }
    lines.append("</svg>")
    return lines.joined(separator: "\n") + "\n"
}

// MARK: - Raster

func render(_ layers: [Layer], pixels px: Int) -> CGImage {
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("cannot create bitmap context")
    }
    let k = CGFloat(px) / canvas
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    // Flip to the SVG coordinate system (y down).
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: k, y: -k)
    for l in layers {
        ctx.saveGState()
        if l.id == "plate" {
            // Shadow offsets are in device space (y up), unaffected by the CTM.
            ctx.setShadow(offset: CGSize(width: 0, height: -shadowOffsetY * k), blur: shadowBlur * k,
                          color: CGColor(gray: 0, alpha: shadowAlpha))
        }
        ctx.addPath(cgPath(l.path))
        ctx.setFillColor(l.fill.cg)
        ctx.fillPath()
        if l.stroke > 0 {
            ctx.addPath(cgPath(l.path))
            ctx.setStrokeColor(l.fill.cg)
            ctx.setLineWidth(l.stroke)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL, dpi: Int = 72) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot write \(url.path)") }
}

/// Review sheet: 16, 32, 64, 128 px at actual size on light and dark backgrounds, then the
/// same images magnified with nearest-neighbour sampling to show the pixels.
func contactSheet(_ images: [(Int, CGImage)]) -> CGImage {
    let pad = 24, magnified = 256
    let width = pad + images.count * (magnified + pad)
    let height = pad + 2 * (128 + pad) + magnified + pad
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // y up: bottom row = magnified, then dark, then light at the top.
    ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.93, blue: 0.94, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let darkY = pad + magnified + pad
    ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1))
    ctx.fill(CGRect(x: 0, y: darkY - pad / 2, width: width, height: 128 + pad))
    let lightY = darkY + 128 + pad
    for (i, (px, img)) in images.enumerated() {
        let x = pad + i * (magnified + pad)
        for y in [lightY, darkY] {
            ctx.draw(img, in: CGRect(x: x + (magnified - px) / 2, y: y + (128 - px) / 2, width: px, height: px))
        }
        ctx.interpolationQuality = .none
        ctx.draw(img, in: CGRect(x: x, y: pad, width: magnified, height: magnified))
        ctx.interpolationQuality = .high
    }
    return ctx.makeImage()!
}

func renderAll(glyphFile: URL, svgDir: URL, iconset: URL, preview: URL?) throws {
    var glyphs: [String: Path] = [:]
    for line in try String(contentsOf: glyphFile, encoding: .utf8).split(separator: "\n") {
        if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
        guard let sp = line.firstIndex(of: " ") else { continue }
        glyphs[String(line[..<sp])] = parse(String(line[line.index(after: sp)...]))
    }

    let fm = FileManager.default
    try fm.createDirectory(at: svgDir, withIntermediateDirectories: true)
    for v in variants {
        let name = v.name.isEmpty ? "AppIcon.svg" : "AppIcon-\(v.name).svg"
        try svg(layers(glyphs: glyphs, variant: v), variant: v)
            .write(to: svgDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        print("wrote \(svgDir.appendingPathComponent(name).path)")
    }

    // macOS app icon slots: 16, 32, 128, 256, 512 pt at 1x and 2x.
    try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
    var entries: [String] = []
    var cache: [Int: CGImage] = [:]
    func image(_ px: Int) -> CGImage {
        if let i = cache[px] { return i }
        let i = render(layers(glyphs: glyphs, variant: variant(forPixels: px)), pixels: px)
        cache[px] = i
        return i
    }
    for pt in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = pt * scale
            let file = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
            writePNG(image(px), to: iconset.appendingPathComponent(file), dpi: 72 * scale)
            entries.append("""
                {
                  "filename" : "\(file)",
                  "idiom" : "mac",
                  "scale" : "\(scale)x",
                  "size" : "\(pt)x\(pt)"
                }
            """)
        }
    }
    let contents = "{\n  \"images\" : [\n" + entries.joined(separator: ",\n") +
        "\n  ],\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n"
    try contents.write(to: iconset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("wrote \(iconset.path)")

    if let preview {
        try fm.createDirectory(at: preview, withIntermediateDirectories: true)
        writePNG(image(512), to: preview.appendingPathComponent("icon-512.png"))
        writePNG(contactSheet([16, 32, 64, 128].map { ($0, image($0)) }),
                 to: preview.appendingPathComponent("sizes.png"))
        print("wrote previews to \(preview.path)")
    }
}

// MARK: - Main

let args = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write(Data("""
    usage: make-app-icon.swift outline <font.ttf> <glyphs.txt>
           make-app-icon.swift render <glyphs.txt> <svg-dir> <appiconset-dir> [<preview-dir>]

    """.utf8))
    exit(2)
}
guard args.count >= 2 else { usage() }
switch args[1] {
case "outline" where args.count == 4:
    try outline(fontURL: URL(fileURLWithPath: args[2]), out: URL(fileURLWithPath: args[3]))
case "render" where args.count == 5 || args.count == 6:
    try renderAll(glyphFile: URL(fileURLWithPath: args[2]),
                  svgDir: URL(fileURLWithPath: args[3], isDirectory: true),
                  iconset: URL(fileURLWithPath: args[4], isDirectory: true),
                  preview: args.count == 6 ? URL(fileURLWithPath: args[5], isDirectory: true) : nil)
default:
    usage()
}
