import SwiftUI

struct AppTheme {
    struct Colors {
        // Warm Coral Theme
        static let primary100 = Color(hex: "FF7F50") // Coral orange
        static let primary200 = Color(hex: "dd6236") // Darker orange
        static let primary300 = Color(hex: "8f1e00") // Dark red/brown

        static let accent100 = Color(hex: "8B4513") // Saddle brown
        static let accent200 = Color(hex: "ffd299") // Light peach

        static let text100 = Color(hex: "000000") // Black
        static let text200 = Color(hex: "2c2c2c") // Dark gray

        static let bg100 = Color(hex: "F7EEDD") // Cream/beige
        static let bg200 = Color(hex: "ede4d3") // Slightly darker cream
        static let bg300 = Color(hex: "c4bcab") // Grayish beige

        // Convenience aliases for backward compatibility
        static let primary = primary100
        static let secondary = primary200
        static let accent = accent100
        static let background = bg100
        static let surface = bg200.opacity(0.80)
        static let surfaceSolid = bg200

        static let textPrimary = text100
        static let textSecondary = text200

        struct Pastels {
            static let coral = Color(hex: "FF7F50")
            static let peach = Color(hex: "ffd299")
            static let cream = Color(hex: "F7EEDD")
            static let brown = Color(hex: "8B4513")
        }

        // Shadow colors
        static let buttonShadow = primary200.opacity(0.40)
        static let cardShadow = Color.black.opacity(0.10)
    }
    
    struct CornerRadius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    struct Shadows {
        static func card(color: Color = Colors.textPrimary.opacity(0.05)) -> some ViewModifier {
            ShadowModifier(color: color, radius: 6, y: 3)
        }
        
        static func button(color: Color) -> some ViewModifier {
            ShadowModifier(color: color.opacity(0.3), radius: 6, y: 3)
        }
    }
}

// MARK: - Helper Modifiers
struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
    
    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: 0, y: y)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Font Extension for "Rounded" look (Smaller sizes)
extension Font {
    static func appTitle() -> Font {
        .system(size: 28, weight: .bold, design: .rounded) // Was 34
    }
    
    static func appHeadline() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded) // Was 24
    }
    
    static func appBody() -> Font {
        .system(size: 16, weight: .regular, design: .rounded) // Was 17
    }
    
    static func appCaption() -> Font {
        .system(size: 14, weight: .medium, design: .rounded)
    }
}
