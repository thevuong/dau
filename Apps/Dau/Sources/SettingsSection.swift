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

    /// Sidebar icon colors from UI.md, as system colors (D9).
    var color: Color {
        switch self {
        case .typing: .blue
        case .smart: .purple
        case .apps: .orange
        case .updates: .green
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

/// Sidebar icon: white SF Symbol on a rounded square of the section color, like System
/// Settings. Decorative; the label beside it carries the meaning.
struct SectionIcon: View {
    let section: SettingsSection

    var body: some View {
        Image(systemName: section.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(section.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}
