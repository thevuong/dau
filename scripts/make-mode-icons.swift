// Draws the temporary input mode icons "V" (Tiếng Việt) and "E" (Tiếng Anh) for the
// input source menu: monochrome template images, a letter inside a rounded frame
// (docs/BRAND.md, "Biểu tượng thanh menu"). Letters are stroked paths, not a font, so
// no font license is involved.
//
// TODO(M7): replace with the official identity files (BRAND.md "File cần xuất").
//
// Usage: scripts/make-mode-icons.sh (wraps this script and tiffutil).
//        swift scripts/make-mode-icons.swift <output-dir>  → V.png, V@2x.png, E.png, E@2x.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-mode-icons.swift <output-dir>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)

/// Draws in a 16×16 pt space, origin bottom-left.
func draw(_ letter: Character, in ctx: CGContext) {
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(1.2)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 1.6, y: 1.6, width: 12.8, height: 12.8),
                       cornerWidth: 3, cornerHeight: 3, transform: nil))
    ctx.strokePath()

    ctx.setLineWidth(1.6)
    ctx.setLineJoin(.miter)
    let path = CGMutablePath()
    switch letter {
    case "V":
        ctx.setLineCap(.butt)
        path.move(to: CGPoint(x: 5.0, y: 11.6))
        path.addLine(to: CGPoint(x: 8.0, y: 4.4))
        path.addLine(to: CGPoint(x: 11.0, y: 11.6))
    case "E":
        ctx.setLineCap(.square)
        path.move(to: CGPoint(x: 10.4, y: 11.2))
        path.addLine(to: CGPoint(x: 5.8, y: 11.2))
        path.addLine(to: CGPoint(x: 5.8, y: 4.8))
        path.addLine(to: CGPoint(x: 10.4, y: 4.8))
        path.move(to: CGPoint(x: 5.8, y: 8.0))
        path.addLine(to: CGPoint(x: 9.8, y: 8.0))
    default:
        fatalError("unknown letter")
    }
    ctx.addPath(path)
    ctx.strokePath()
}

func writePNG(_ letter: Character, scale: Int, name: String) throws {
    let px = 16 * scale
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "icons", code: 1)
    }
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    draw(letter, in: ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(outDir.appendingPathComponent(name) as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "icons", code: 2)
    }
    let dpi = 72 * scale
    CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "icons", code: 3) }
}

for letter: Character in ["V", "E"] {
    try writePNG(letter, scale: 1, name: "\(letter).png")
    try writePNG(letter, scale: 2, name: "\(letter)@2x.png")
}
