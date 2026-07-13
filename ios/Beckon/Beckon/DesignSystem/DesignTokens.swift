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

    nonisolated enum ColorHex {
        static let appBackground: UInt = 0xFAF7F2
        static let surface: UInt = 0xFFFFFF
        static let border: UInt = 0xE8E2D8
        static let borderSoft: UInt = 0xEFEAE1
        static let textPrimary: UInt = 0x232323
        static let textSecondary: UInt = 0x6F767E
        static let textTertiary: UInt = 0x69717A
        static let customerPrimary: UInt = 0x7ECFC0
        static let customerPrimaryDark: UInt = 0x5FBFAE
        static let customerOnAccent: UInt = 0x12463F
        static let groomerAccent: UInt = 0xFF9A8B
        static let groomerAccentDark: UInt = 0xF58575
        static let groomerOnAccent: UInt = 0x642620
        static let success: UInt = 0x6CBF84
        static let warning: UInt = 0xF2B84B
        static let error: UInt = 0xE56B6F
        static let successText: UInt = 0x37744E
        static let warningText: UInt = 0x8F6800
        static let errorText: UInt = 0xB4474C
        static let notificationUnread: UInt = 0xFF3B30
    }

    enum Colors {
        static let appBackground = Color(hex: ColorHex.appBackground)
        static let surface = Color(hex: ColorHex.surface)
        static let surfaceRaised = Color(hex: ColorHex.surface)
        static let border = Color(hex: ColorHex.border)
        static let borderSoft = Color(hex: ColorHex.borderSoft)
        static let divider = borderSoft
        static let textPrimary = Color(hex: ColorHex.textPrimary)
        static let textSecondary = Color(hex: ColorHex.textSecondary)
        static let textTertiary = Color(hex: ColorHex.textTertiary)
        static let customerPrimary = Color(hex: ColorHex.customerPrimary)
        static let customerPrimaryDark = Color(hex: ColorHex.customerPrimaryDark)
        static let customerOnAccent = Color(hex: ColorHex.customerOnAccent)
        static let customerPrimaryPressed = customerPrimaryDark
        static let groomerAccent = Color(hex: ColorHex.groomerAccent)
        static let groomerAccentDark = Color(hex: ColorHex.groomerAccentDark)
        static let groomerOnAccent = Color(hex: ColorHex.groomerOnAccent)
        static let groomerAccentPressed = groomerAccentDark
        static let success = Color(hex: ColorHex.success)
        static let warning = Color(hex: ColorHex.warning)
        static let error = Color(hex: ColorHex.error)
        static let successText = Color(hex: ColorHex.successText)
        static let warningText = Color(hex: ColorHex.warningText)
        static let errorText = Color(hex: ColorHex.errorText)
        static let notificationUnread = Color(hex: ColorHex.notificationUnread)
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

    enum Layout {
        static let pageHorizontalInset: CGFloat = 20
        static let pageTopInset: CGFloat = 24
        static let pageBottomInset: CGFloat = 48
        static let sectionSpacing: CGFloat = 24
        static let sectionContentSpacing: CGFloat = 12
        static let surfaceInset: CGFloat = 16
        static let rowHorizontalInset: CGFloat = 16
        static let rowVerticalInset: CGFloat = 12
        static let fieldSpacing: CGFloat = 12
        static let actionAreaInset: CGFloat = 12
        static let stationaryActionContentClearance: CGFloat = 124
    }

    enum Metrics {
        static let minimumTouchTarget: CGFloat = 44
        static let fieldHeight: CGFloat = 52
        static let actionHeight: CGFloat = 52
        static let settingsIconSlot: CGFloat = 36
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
            radius: 8,
            x: 0,
            y: 4,
            spread: 0
        )
        static let smallCard = softCard
        static let carouselCard = softCard
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
        static let pageTitle = Font.largeTitle.weight(.bold)
        static let sectionTitle = Font.title2.weight(.bold)
        static let cardTitle = Font.title3.weight(.bold)
        static let body = Font.body
        static let supporting = Font.subheadline
        static let fieldLabel = Font.subheadline.weight(.semibold)
        static let status = Font.caption.weight(.semibold)
        static let action = Font.headline.weight(.semibold)

        // Compatibility names remain until the source audit reports zero usage.
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let headline = Font.headline.weight(.bold)
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
