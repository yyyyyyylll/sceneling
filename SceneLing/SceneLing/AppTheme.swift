import SwiftUI

struct AppTheme {
    struct Colors {
        // Figma Design Palette - Pink Theme
        static let primary = Color(red: 0.60, green: 0.06, blue: 0.98) // Purple accent
        static let secondary = Color(red: 0.68, green: 0.28, blue: 1) // Light purple
        static let accent = Color(red: 0.99, green: 0.39, blue: 0.71) // Pink
        static let background = Color(red: 0.99, green: 0.95, blue: 0.97) // Light pink background
        static let surface = Color.white.opacity(0.80) // Semi-transparent white
        static let surfaceSolid = Color.white

        static let textPrimary = Color(red: 0.04, green: 0.04, blue: 0.04) // Near black
        static let textSecondary = Color(red: 0.44, green: 0.44, blue: 0.51) // Gray

        struct Pastels {
            static let pink = Color(red: 0.99, green: 0.39, blue: 0.71)
            static let blue = Color(red: 0.32, green: 0.64, blue: 1)
            static let purple = Color(red: 0.76, green: 0.48, blue: 1)
            static let yellow = Color(hex: "FDFD96")
        }

        // Shadow colors
        static let buttonShadow = Color(red: 0.85, green: 0.70, blue: 1).opacity(0.50)
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
        .system(size: 12, weight: .medium, design: .rounded) // Was 13
    }
}
