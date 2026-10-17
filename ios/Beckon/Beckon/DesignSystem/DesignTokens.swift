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

    nonisolated enum Palette {
        static let mintFill: UInt = 0x81D0C2
        static let mintFillPressed: UInt = 0x73BEB1
        static let mintInk: UInt = 0x0F3D35
        static let mintDeep: UInt = 0x1E6E5F
        static let mintTint: UInt = 0xE3F5F2
        static let mintHeroEnd: UInt = 0xA4DDD3
        static let mintHeroBubble: UInt = 0xBAE5DD
        static let mintHeroDecoration: UInt = 0x6CB6A9
        static let coralFill: UInt = 0xFF9A8B
        static let coralFillPressed: UInt = 0xFF8A79
        static let coralInk: UInt = 0x4A1C14
        static let coralDeep: UInt = 0xB23A2B
        static let coralTint: UInt = 0xFFEDE9
        static let warmBackground: UInt = 0xFAF7F2
        static let white: UInt = 0xFFFFFF
        static let warmBorder: UInt = 0xE8E2D8
        static let warmDivider: UInt = 0xECE6DC
        static let warmPrimary: UInt = 0x2E2A26
        static let warmSecondary: UInt = 0x625B53
        static let warmTertiary: UInt = 0x756D65
        static let warmPlaceholder: UInt = 0xF1ECE4
        static let warmIconTile: UInt = 0xF3EEE7
        static let successText: UInt = 0x276B2B
        static let successFill: UInt = 0xE6F2E6
        static let successBorder: UInt = 0xCFE5CF
        static let warningText: UInt = 0x8A5A00
        static let warningFill: UInt = 0xFBF0D9
        static let warningBorder: UInt = 0xF2DFB5
        static let errorText: UInt = 0xB3203F
        static let errorFill: UInt = 0xFBE8EC
        static let errorBorder: UInt = 0xF0C9D1
        static let infoText: UInt = 0x2F5F8A
        static let infoFill: UInt = 0xE7EFF7
        static let infoBorder: UInt = 0xCFDDEC
        static let ratingStar: UInt = 0xF2B84B
    }

    nonisolated enum ColorHex {
        static let appBackground = Palette.warmBackground
        static let surface = Palette.white
        static let border = Palette.warmBorder
        static let borderSoft = Palette.warmDivider
        static let textPrimary = Palette.warmPrimary
        static let textSecondary = Palette.warmSecondary
        static let textTertiary = Palette.warmTertiary
        static let placeholderFill = Palette.warmPlaceholder
        static let iconTileFill = Palette.warmIconTile
        static let ratingStar = Palette.ratingStar
        static let unreadDot = Palette.errorText
        static let customerFill = Palette.mintFill
        static let customerFillPressed = Palette.mintFillPressed
        static let customerInk = Palette.mintInk
        static let customerDeep = Palette.mintDeep
        static let customerTint = Palette.mintTint
        static let groomerFill = Palette.coralFill
        static let groomerFillPressed = Palette.coralFillPressed
        static let groomerInk = Palette.coralInk
        static let groomerDeep = Palette.coralDeep
        static let groomerTint = Palette.coralTint
        static let customerHeroEnd = Palette.mintHeroEnd
        static let customerHeroBubble = Palette.mintHeroBubble
        static let customerHeroDecoration = Palette.mintHeroDecoration
        static let statusSuccessText = Palette.successText
        static let statusSuccessFill = Palette.successFill
        static let statusSuccessBorder = Palette.successBorder
        static let statusWarningText = Palette.warningText
        static let statusWarningFill = Palette.warningFill
        static let statusWarningBorder = Palette.warningBorder
        static let statusErrorText = Palette.errorText
        static let statusErrorFill = Palette.errorFill
        static let statusErrorBorder = Palette.errorBorder
        static let statusInfoText = Palette.infoText
        static let statusInfoFill = Palette.infoFill
        static let statusInfoBorder = Palette.infoBorder
        static let statusNeutralText = Palette.warmSecondary
        static let statusNeutralFill = Palette.warmIconTile
        static let statusNeutralBorder = Palette.warmBorder

    }

    enum Colors {
        static let appBackground = Color(hex: ColorHex.appBackground)
        static let surface = Color(hex: ColorHex.surface)
        static let border = Color(hex: ColorHex.border)
        static let borderSoft = Color(hex: ColorHex.borderSoft)
        static let textPrimary = Color(hex: ColorHex.textPrimary)
        static let textSecondary = Color(hex: ColorHex.textSecondary)
        static let textTertiary = Color(hex: ColorHex.textTertiary)
        static let placeholderFill = Color(hex: ColorHex.placeholderFill)
        static let iconTileFill = Color(hex: ColorHex.iconTileFill)
        static let ratingStar = Color(hex: ColorHex.ratingStar)
        static let unreadDot = Color(hex: ColorHex.unreadDot)
        static let customerFill = Color(hex: ColorHex.customerFill)
        static let customerFillPressed = Color(hex: ColorHex.customerFillPressed)
        static let customerInk = Color(hex: ColorHex.customerInk)
        static let customerDeep = Color(hex: ColorHex.customerDeep)
        static let customerTint = Color(hex: ColorHex.customerTint)
        static let groomerFill = Color(hex: ColorHex.groomerFill)
        static let groomerFillPressed = Color(hex: ColorHex.groomerFillPressed)
        static let groomerInk = Color(hex: ColorHex.groomerInk)
        static let groomerDeep = Color(hex: ColorHex.groomerDeep)
        static let groomerTint = Color(hex: ColorHex.groomerTint)
        static let customerHeroEnd = Color(hex: ColorHex.customerHeroEnd)
        static let customerHeroBubble = Color(hex: ColorHex.customerHeroBubble)
        static let customerHeroDecoration = Color(hex: ColorHex.customerHeroDecoration)
        static let statusSuccessText = Color(hex: ColorHex.statusSuccessText)
        static let statusSuccessFill = Color(hex: ColorHex.statusSuccessFill)
        static let statusSuccessBorder = Color(hex: ColorHex.statusSuccessBorder)
        static let statusWarningText = Color(hex: ColorHex.statusWarningText)
        static let statusWarningFill = Color(hex: ColorHex.statusWarningFill)
        static let statusWarningBorder = Color(hex: ColorHex.statusWarningBorder)
        static let statusErrorText = Color(hex: ColorHex.statusErrorText)
        static let statusErrorFill = Color(hex: ColorHex.statusErrorFill)
        static let statusErrorBorder = Color(hex: ColorHex.statusErrorBorder)
        static let statusInfoText = Color(hex: ColorHex.statusInfoText)
        static let statusInfoFill = Color(hex: ColorHex.statusInfoFill)
        static let statusInfoBorder = Color(hex: ColorHex.statusInfoBorder)
        static let statusNeutralText = Color(hex: ColorHex.statusNeutralText)
        static let statusNeutralFill = Color(hex: ColorHex.statusNeutralFill)
        static let statusNeutralBorder = Color(hex: ColorHex.statusNeutralBorder)
        static let surfaceRaised = surface
        static let divider = borderSoft

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
            color: Color(hex: ColorHex.textPrimary, opacity: 0.06),
            radius: 2,
            x: 0,
            y: 1,
            spread: 0
        )
        static let smallCard = softCard
        static let carouselCard = softCard
    }

    enum Typography {
        static let pageTitle = Font.largeTitle.weight(.bold)
        static let featureTitle = Font.title.weight(.bold)
        static let sectionTitle = Font.title2.weight(.bold)
        static let cardTitle = Font.title3.weight(.bold)
        static let body = Font.body
        static let supporting = Font.subheadline
        static let fieldLabel = Font.subheadline.weight(.semibold)
        static let status = Font.caption.weight(.semibold)
        static let action = Font.headline.weight(.semibold)
        static let prominentAction = Font.title3.weight(.semibold)

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
