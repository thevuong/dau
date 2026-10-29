import AppKit
import SwiftUI

/// The four sections of the Settings window (docs/UI.md).
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case typing
    case smart
    case apps
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typing: String(localized: "Gõ phím")
        case .smart: String(localized: "Thông minh")
        case .apps: String(localized: "Ứng dụng")
        case .updates: String(localized: "Cập nhật & hỗ trợ")
        }
    }

    var symbol: String {
        switch self {
        case .typing: "keyboard"
        case .smart: "wand.and.stars"
        case .apps: "square.grid.2x2"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }

    /// Words the sidebar search matches, besides the title: the labels of the settings
    /// in the section.
    var keywords: [String] {
        switch self {
        case .typing:
            [String(localized: "Xem trước"), String(localized: "Kiểu gõ"), "Telex", "VNI",
             String(localized: "Telex đơn giản"), String(localized: "Vị trí dấu thanh"),
             String(localized: "Kiểu mới"), String(localized: "Kiểu cũ"),
             String(localized: "Bỏ dấu tự do"), String(localized: "Phím tắt nguồn nhập liệu"),
             String(localized: "Chuyển Tiếng Việt ↔ Tiếng Anh")]
        case .smart:
            [String(localized: "Gõ lẫn từ nước ngoài"),
             String(localized: "Tự khôi phục từ không phải tiếng Việt"),
             String(localized: "Sửa từ đã gõ"), String(localized: "Thêm dấu cho từ đã gõ"),
             String(localized: "Nâng cao"), String(localized: "Gõ tắt phụ âm"),
             String(localized: "Cho phép phụ âm z, f, w, j")]
        case .apps:
            [String(localized: "Mặc định"), String(localized: "Nhớ chế độ theo từng ứng dụng"),
             String(localized: "Quy tắc riêng"), String(localized: "Gạch chân"),
             String(localized: "Tiếng Việt"), String(localized: "Tiếng Anh")]
        case .updates:
            [String(localized: "Phiên bản"), String(localized: "Kiểm tra ngay"),
             String(localized: "Tự động kiểm tra bản mới"), String(localized: "Tự động tải và cài"),
             String(localized: "Kênh phát hành"), String(localized: "Beta"),
             String(localized: "Báo lỗi…"), String(localized: "Quay về bản trước"),
             String(localized: "Gỡ cài đặt…"), String(localized: "Quyền riêng tư")]
        }
    }

    /// Case- and diacritic-insensitive match, so "go phim" finds "Gõ phím".
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return ([title] + keywords).contains { $0.localizedStandardContains(query) }
    }
}

/// Sidebar icon, drawn after the mockup's SVG (canvas artboards "Settings…"): a 22 pt
/// tile with radius 6 in the mockup's color, and a 14 pt line glyph (viewBox 24,
/// white stroke 2, round caps and joins, no fill). It is an illustration, like the
/// icons of System Settings, so it uses the mockup's exact colors. Drawn into a
/// non-template image so the sidebar's vibrancy does not wash it out. Decorative; the
/// label beside it carries the meaning.
struct SectionIcon: View {
    let section: SettingsSection

    var body: some View {
        Image(nsImage: SectionIcon.tile(section))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }

    @MainActor private static var cache: [SettingsSection: NSImage] = [:]

    @MainActor static func tile(_ section: SettingsSection) -> NSImage {
        if let image = cache[section] { return image }
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: true) { rect in
            section.tileColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            // The 24-unit glyph scaled to 14 pt, centered.
            let k = 14.0 / 24.0
            let glyph = section.glyph
            glyph.transform(using: AffineTransform(m11: k, m12: 0, m21: 0, m22: k, tX: 4, tY: 4))
            glyph.lineWidth = 2 * 14.0 / 24.0
            glyph.lineCapStyle = .round
            glyph.lineJoinStyle = .round
            NSColor.white.setStroke()
            glyph.stroke()
            return true
        }
        image.isTemplate = false
        cache[section] = image
        return image
    }
}

extension SettingsSection {
    /// Tile colors from the mockup (#0A64D8, #7A3FD1, #C2410C, #1F7A4D).
    var tileColor: NSColor {
        switch self {
        case .typing: NSColor(srgbRed: 0x0A / 255, green: 0x64 / 255, blue: 0xD8 / 255, alpha: 1)
        case .smart: NSColor(srgbRed: 0x7A / 255, green: 0x3F / 255, blue: 0xD1 / 255, alpha: 1)
        case .apps: NSColor(srgbRed: 0xC2 / 255, green: 0x41 / 255, blue: 0x0C / 255, alpha: 1)
        case .updates: NSColor(srgbRed: 0x1F / 255, green: 0x7A / 255, blue: 0x4D / 255, alpha: 1)
        }
    }

    /// The mockup's SVG paths, in its 24-unit viewBox (y down).
    var glyph: NSBezierPath {
        let p = NSBezierPath()
        func poly(_ points: [(CGFloat, CGFloat)], close: Bool = true) {
            p.move(to: NSPoint(x: points[0].0, y: points[0].1))
            for pt in points.dropFirst() { p.line(to: NSPoint(x: pt.0, y: pt.1)) }
            if close { p.close() }
        }
        func dot(_ x: CGFloat, _ y: CGFloat) { poly([(x, y), (x + 0.01, y)], close: false) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            p.append(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r))
        }
        switch self {
        case .typing:
            // rect x2.5 y6 w19 h12 rx3; M6.5 10h.01 M10 10h.01 M13.5 10h.01 M17 10h.01 M8 14h8
            rect(2.5, 6, 19, 12, 3)
            dot(6.5, 10); dot(10, 10); dot(13.5, 10); dot(17, 10)
            poly([(8, 14), (16, 14)], close: false)
        case .smart:
            // M12 3l1.9 4.8L19 9.5l-5.1 1.7L12 16l-1.9-4.8L5 9.5l5.1-1.7z
            poly([(12, 3), (13.9, 7.8), (19, 9.5), (13.9, 11.2), (12, 16), (10.1, 11.2), (5, 9.5), (10.1, 7.8)])
            // M18.5 15.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z
            poly([(18.5, 15.5), (19.2, 17.3), (21, 18), (19.2, 18.7), (18.5, 20.5), (17.8, 18.7), (16, 18), (17.8, 17.3)])
        case .apps:
            for (x, y) in [(4.0, 4.0), (13.5, 4.0), (4.0, 13.5), (13.5, 13.5)] { rect(x, y, 6.5, 6.5, 1.8) }
        case .updates:
            // M20 12a8 8 0 1 1-2.4-5.7: the large clockwise arc of the circle at (12,12), r 8
            // (y down), from (20,12) to (17.6,6.3).
            p.move(to: NSPoint(x: 20, y: 12))
            let end = atan2(6.3 - 12, 17.6 - 12) * 180 / .pi + 360
            p.appendArc(withCenter: NSPoint(x: 12, y: 12), radius: 8, startAngle: 0, endAngle: end, clockwise: false)
            // M20 4.5v4h-4
            poly([(20, 4.5), (20, 8.5), (16, 8.5)], close: false)
        }
        return p
    }
}
