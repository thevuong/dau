// Builds the temporary app icon for Dấu: "ấ" in Giấy on a Mực plate, the circumflex in the
// letter colour and only the acute in Son (docs/BRAND.md "Biểu tượng", D25).
//
// Geometry follows the canvas mockup "Nhận diện – biểu tượng ứng dụng" (a 100 × 100 design):
//   letter "a"   Be Vietnam Pro Bold (700), size 64, centred on x = 48, baseline y = 80
//   circumflex   stroke M34 35 L47 25 L60 35, width 7, round caps and joins, Giấy
//   acute        stroke M63 24 L73 13, width 7.5, round caps, Son
// The 100 grid is mapped onto the 824 × 824 plate of the macOS icon grid (1024 canvas).
//
// Only the letter comes from the font: its contours are extracted once into
// Resources/Brand/app-icon-glyphs.txt, so rendering never needs the font (never commit the
// font file). The marks are drawn as strokes and converted to outlined paths.
//
// TODO(M7): the official icon is built in Icon Composer (Default / Dark / Clear / Tinted
// appearances on macOS 26+) plus an .icns for macOS 14–15; this script is a stand-in.
//
// Usage (normally via scripts/make-app-icon.sh):
//   make-app-icon.swift outline <BeVietnamPro-Bold.ttf> <glyphs.txt>
//       Extract the contours and advance width of "a" in font units, y up.
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

/// Parses the absolute M/L/Q/C/Z subset written by `svgData`.
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

func path(_ cg: CGPath) -> Path {
    var out: Path = []
    cg.applyWithBlock { e in
        let el = e.pointee
        switch el.type {
        case .moveToPoint: out.append(.move(el.points[0]))
        case .addLineToPoint: out.append(.line(el.points[0]))
        case .addQuadCurveToPoint: out.append(.quad(el.points[0], el.points[1]))
        case .addCurveToPoint: out.append(.cubic(el.points[0], el.points[1], el.points[2]))
        case .closeSubpath: out.append(.close)
        @unknown default: break
        }
    }
    return out
}

func bounds(_ path: Path) -> CGRect { cgPath(path).boundingBoxOfPath }

// MARK: - outline: font → glyph contours

func outline(fontURL: URL, out: URL) throws {
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
          let desc = descs.first else { fatalError("cannot read font \(fontURL.path)") }
    let upm = CGFloat(CTFontGetUnitsPerEm(CTFontCreateWithFontDescriptor(desc, 1, nil)))
    let font = CTFontCreateWithFontDescriptor(desc, upm, nil)  // 1 point = 1 font unit
    var chars = Array("a".utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count),
          let glyphPath = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
        fatalError("font has no glyph for a")
    }
    let advance = CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, nil, 1)
    let name = CTFontCopyFullName(font) as String
    let version = (CTFontCopyName(font, kCTFontVersionNameKey) as String?) ?? "?"
    let text = """
    # Outline of "a" from \(name) (\(version)), SIL Open Font License 1.1,
    # https://github.com/bettergui/BeVietnamPro (via github.com/google/fonts, ofl/bevietnampro).
    # Font units (\(Int(upm))/em), y up, baseline 0. Generated by
    # scripts/make-app-icon.sh outline; the font file is not part of the repo.
    em \(fmt(upm))
    advance \(fmt(advance))
    a \(svgData(path(glyphPath)))

    """
    try text.write(to: out, atomically: true, encoding: .utf8)
    print("wrote \(out.path)")
}

// MARK: - Geometry

let canvas: CGFloat = 1024
// macOS (Big Sur and later) icon grid: 824 × 824 plate centred on the 1024 canvas,
// continuous ("squircle") corners with radius ≈ 185.4 (mockup: rx 22.4 on 100 ≈ 184.6).
let plateRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let plateRadius: CGFloat = 185.4

/// Mockup 100 × 100 design space → canvas.
let grid = plateRect.width / 100
func fromGrid(_ p: CGPoint) -> CGPoint {
    CGPoint(x: plateRect.minX + grid * p.x, y: plateRect.minY + grid * p.y)
}

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
    // One corner, from one edge to the next; `swap` mirrors the corner for the corners that
    // start on a vertical edge.
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

/// Per-size adjustments. Small icons get thicker marks on the same centre lines
/// (BRAND.md: "Ở 16–32 pt tăng độ dày nét dấu") and a slightly larger letter, scaled about
/// the top of its x-height so the gap under the circumflex stays. Widths in grid units.
struct Variant {
    let name: String          // SVG file suffix
    let maxPixels: Int        // used for rendered sizes up to this many pixels
    let circumflexWidth: CGFloat
    let acuteWidth: CGFloat
    let letterScale: CGFloat
}

let variants: [Variant] = [
    Variant(name: "16", maxPixels: 16, circumflexWidth: 10, acuteWidth: 10.5, letterScale: 1.06),
    Variant(name: "32", maxPixels: 32, circumflexWidth: 8.5, acuteWidth: 9, letterScale: 1.03),
    Variant(name: "64", maxPixels: 64, circumflexWidth: 7.6, acuteWidth: 8.1, letterScale: 1.0),
    Variant(name: "", maxPixels: .max, circumflexWidth: 7, acuteWidth: 7.5, letterScale: 1.0),
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
}

struct Glyph {
    let em: CGFloat
    let advance: CGFloat
    let a: Path
}

// Mockup letter placement (grid units).
let letterSize: CGFloat = 64
let letterCentreX: CGFloat = 48
let letterBaseline: CGFloat = 80

/// Outlines a round-capped polyline given in grid units.
func outlinedStroke(_ points: [CGPoint], width: CGFloat) -> Path {
    let line = CGMutablePath()
    line.addLines(between: points.map(fromGrid))
    return path(line.copy(strokingWithWidth: width * grid, lineCap: .round, lineJoin: .round, miterLimit: 10))
}

func layers(glyph g: Glyph, variant v: Variant) -> [Layer] {
    // SVG text-anchor="middle" centres the advance box on x.
    let k = letterSize / g.em
    let originX = letterCentreX - k * g.advance / 2
    let top = bounds(g.a).maxY  // top of the x-height (font units)
    let anchor = CGPoint(x: letterCentreX, y: letterBaseline - k * top)
    let a = transform(g.a) { p in
        let m = CGPoint(x: originX + k * p.x, y: letterBaseline - k * p.y)
        return fromGrid(CGPoint(x: anchor.x + (m.x - anchor.x) * v.letterScale,
                                y: anchor.y + (m.y - anchor.y) * v.letterScale))
    }
    return [
        Layer(id: "plate", path: squircle(plateRect, radius: plateRadius), fill: muc),
        Layer(id: "a", path: a, fill: giay),
        Layer(id: "circumflex",
              path: outlinedStroke([CGPoint(x: 34, y: 35), CGPoint(x: 47, y: 25), CGPoint(x: 60, y: 35)],
                                   width: v.circumflexWidth),
              fill: giay),
        Layer(id: "acute",
              path: outlinedStroke([CGPoint(x: 63, y: 24), CGPoint(x: 73, y: 13)], width: v.acuteWidth),
              fill: son),
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
        "<!-- Letter outlined from Be Vietnam Pro Bold (SIL OFL 1.1), marks are outlined strokes; no font needed. -->",
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
        if l.id == "plate" { attrs += " filter=\"url(#shadow)\"" }
        lines.append("  <path \(attrs) d=\"\(svgData(l.path))\"/>")
    }
    lines.append("</svg>")
    return lines.joined(separator: "\n") + "\n"
}

// MARK: - Raster

func bitmap(_ w: Int, _ h: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("cannot create bitmap context")
    }
    return ctx
}

func render(_ layers: [Layer], pixels px: Int) -> CGImage {
    let ctx = bitmap(px, px)
    let k = CGFloat(px) / canvas
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
    let ctx = bitmap(width, height)
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

func loadGlyph(_ url: URL) throws -> Glyph {
    var fields: [String: String] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
        guard let sp = line.firstIndex(of: " ") else { continue }
        fields[String(line[..<sp])] = String(line[line.index(after: sp)...])
    }
    guard let em = fields["em"].flatMap(Double.init), let adv = fields["advance"].flatMap(Double.init),
          let a = fields["a"] else { fatalError("glyph file must define em, advance and a") }
    return Glyph(em: CGFloat(em), advance: CGFloat(adv), a: parse(a))
}

func renderAll(glyphFile: URL, svgDir: URL, iconset: URL, preview: URL?) throws {
    let glyph = try loadGlyph(glyphFile)
    let fm = FileManager.default
    try fm.createDirectory(at: svgDir, withIntermediateDirectories: true)
    for v in variants {
        let name = v.name.isEmpty ? "AppIcon.svg" : "AppIcon-\(v.name).svg"
        try svg(layers(glyph: glyph, variant: v), variant: v)
            .write(to: svgDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        print("wrote \(svgDir.appendingPathComponent(name).path)")
    }

    // macOS app icon slots: 16, 32, 128, 256, 512 pt at 1x and 2x.
    try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
    var entries: [String] = []
    var cache: [Int: CGImage] = [:]
    func image(_ px: Int) -> CGImage {
        if let i = cache[px] { return i }
        let i = render(layers(glyph: glyph, variant: variant(forPixels: px)), pixels: px)
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
