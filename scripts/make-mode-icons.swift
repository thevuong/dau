// Draws the temporary input mode icon "V" (Dấu – Tiếng Việt, the only mode since D2 of
// 30/10/2026) for the input source menu: a monochrome template image, a filled rounded
// badge with the letter cut out
// (docs/BRAND.md, "Biểu tượng thanh menu"). Letters are stroked paths, not a font, so
// no font license is involved.
//
// TODO(M7): replace with the official identity files (BRAND.md "File cần xuất").
//
// Usage: scripts/make-mode-icons.sh (wraps this script and tiffutil).
//        swift scripts/make-mode-icons.swift <output-dir>  → V.png, V@2x.png

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

/// Canvas in points. Measured 30/10/2026 on a Retina menu bar (macOS 27.2): the system's
/// "A" badge of U.S. is 44 × 32 px, i.e. 22 × 16 pt, so the icon uses the same canvas.
let canvasWidth = 22, canvasHeight = 16

/// Draws in a 22×16 pt space, origin bottom-left: a filled rounded badge with the letter
/// cut out, the same shape and size the system uses for its own input sources (the "A"
/// of U.S.), so the template image reads like them in light and dark menu bars.
func draw(_ letter: Character, in ctx: CGContext) {
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 0.5, y: 0.5, width: 21, height: 15),
                       cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.fillPath()

    // The letter is erased from the badge (transparent), not drawn on top of it.
    ctx.setBlendMode(.clear)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setLineWidth(2.0)
    ctx.setLineJoin(.miter)
    let path = CGMutablePath()
    switch letter {
    case "V":
        ctx.setLineCap(.butt)
        path.move(to: CGPoint(x: 7.3, y: 12.4))
        path.addLine(to: CGPoint(x: 11.0, y: 3.6))
        path.addLine(to: CGPoint(x: 14.7, y: 12.4))
    default:
        fatalError("unknown letter")
    }
    ctx.addPath(path)
    ctx.strokePath()
}

func writePNG(_ letter: Character, scale: Int, name: String) throws {
    guard let ctx = CGContext(data: nil, width: canvasWidth * scale, height: canvasHeight * scale,
                              bitsPerComponent: 8, bytesPerRow: 0,
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

for letter: Character in ["V"] {
    try writePNG(letter, scale: 1, name: "\(letter).png")
    try writePNG(letter, scale: 2, name: "\(letter)@2x.png")
}
