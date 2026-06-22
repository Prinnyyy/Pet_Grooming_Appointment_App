import SwiftUI

enum DesignTokens {
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        // SwiftUI shadow has no direct spread parameter; this preserves CSS source evidence for later primitives.
        let spread: CGFloat
    }

    enum Colors {
        static let appBackground = Color(hex: 0xFAF7F2)
        static let surface = Color(hex: 0xFFFFFF)
        static let surfaceRaised = Color(hex: 0xFFFFFF)
        static let border = Color(hex: 0xE8E2D8)
        static let borderSoft = Color(hex: 0xEFEAE1)
        static let divider = borderSoft
        static let textPrimary = Color(hex: 0x232323)
        static let textSecondary = Color(hex: 0x6F767E)
        static let textTertiary = Color(hex: 0x9AA0A6)
        static let customerPrimary = Color(hex: 0x7ECFC0)
        static let customerPrimaryDark = Color(hex: 0x5FBFAE)
        static let customerPrimaryPressed = customerPrimaryDark
        static let groomerAccent = Color(hex: 0xFF9A8B)
        static let groomerAccentDark = Color(hex: 0xF58575)
        static let groomerAccentPressed = groomerAccentDark
        static let success = Color(hex: 0x6CBF84)
        static let warning = Color(hex: 0xF2B84B)
        static let error = Color(hex: 0xE56B6F)

        static let background = appBackground
        static let primaryText = textPrimary
        static let secondaryText = textSecondary
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let screenHorizontal: CGFloat = 20
        static let screenHorizontalLarge: CGFloat = 24

        static let standard = lg
        static let large = xl
    }

    enum CornerRadius {
        static let card: CGFloat = 24
        static let button: CGFloat = 18
        static let input: CGFloat = 16
        static let bottomSheet: CGFloat = 28
    }

    enum Shapes {
        static let chip = Capsule()
        static let circular = Circle()
    }

    enum Shadows {
        static let softCard = ShadowStyle(
            color: Color(hex: 0x232323, opacity: 0.05),
            radius: 22,
            x: 0,
            y: 8,
            spread: 0
        )
        static let smallCard = ShadowStyle(
            color: Color(hex: 0x232323, opacity: 0.05),
            radius: 16,
            x: 0,
            y: 6,
            spread: 0
        )
        static let primaryAction = ShadowStyle(
            color: Color(hex: 0x7ECFC0, opacity: 0.55),
            radius: 28,
            x: 0,
            y: 14,
            spread: -8
        )
        static let groomerAction = ShadowStyle(
            color: Color(hex: 0xFF9A8B, opacity: 0.5),
            radius: 28,
            x: 0,
            y: 14,
            spread: -8
        )
    }

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let headline = Font.headline.weight(.bold)
        static let body = Font.body
        static let caption = Font.caption.weight(.medium)
    }
}

private extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
