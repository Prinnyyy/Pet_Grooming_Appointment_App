import Foundation
import Testing
@testable import Beckon

struct DesignTokenAccessibilityTests {
    @Test
    func customerPaletteUsesApprovedDisplayP3Values() {
        #expect(DesignTokens.DisplayP3Hex.customerAccent == 0x93CEC2)
        #expect(DesignTokens.DisplayP3Hex.customerAccentSoft == 0xB0D8D9)
        #expect(DesignTokens.DisplayP3Hex.customerAccentSubtle == 0xB5DCD9)
        #expect(DesignTokens.DisplayP3Hex.customerAccentStrong == 0x518B7F)
    }

    @Test
    func globalPrimaryTextAndUnchangedSemanticColorsUseApprovedValues() {
        #expect(DesignTokens.ColorHex.textPrimary == 0x333333)
        #expect(DesignTokens.ColorHex.groomerAccent == 0xFF9A8B)
        #expect(DesignTokens.ColorHex.groomerAccentDark == 0xF58575)
        #expect(DesignTokens.ColorHex.success == 0x6CBF84)
        #expect(DesignTokens.ColorHex.warning == 0xF2B84B)
        #expect(DesignTokens.ColorHex.error == 0xE56B6F)
    }

    @Test
    func legacyCustomerPaletteNamesAliasApprovedSemanticRoles() {
        #expect(
            DesignTokens.DisplayP3Hex.customerHeroBackgroundStart ==
                DesignTokens.DisplayP3Hex.customerAccent
        )
        #expect(
            DesignTokens.DisplayP3Hex.customerHeroBackgroundEnd ==
                DesignTokens.DisplayP3Hex.customerAccentSoft
        )
        #expect(
            DesignTokens.DisplayP3Hex.customerHeroBubble ==
                DesignTokens.DisplayP3Hex.customerAccentSubtle
        )
    }

    @Test
    func semanticTextColorsMeetContrastOnSurface() {
        let requiredRatio = 4.5
        let surface = DesignTokens.ColorHex.surface
        let textColors = [
            DesignTokens.ColorHex.textPrimary,
            DesignTokens.ColorHex.textSecondary,
            DesignTokens.ColorHex.textTertiary,
        ]

        for textColor in textColors {
            #expect(Self.contrastRatio(textColor, surface) >= requiredRatio)
        }
    }

    @Test
    func customerPrimaryButtonTextMeetsContrastOnApprovedGradient() {
        let requiredRatio = 4.5
        let foreground = DesignTokens.ColorHex.textPrimary
        let brandBackgrounds = [
            DesignTokens.DisplayP3Hex.customerAccent,
            DesignTokens.DisplayP3Hex.customerAccentSoft,
        ]

        for background in brandBackgrounds {
            #expect(Self.contrastRatio(foreground, background) >= requiredRatio)
        }
    }

    @Test
    func customerStrongAccentMeetsNonTextContrastOnSurface() {
        #expect(
            Self.contrastRatio(
                DesignTokens.DisplayP3Hex.customerAccentStrong,
                DesignTokens.ColorHex.surface
            ) >= 3
        )
    }

    @Test
    func groomerPrimaryButtonForegroundMeetsContrastOnGroomerBackgrounds() {
        let requiredRatio = 4.5
        let foreground = DesignTokens.ColorHex.groomerOnAccent
        let brandBackgrounds = [
            DesignTokens.ColorHex.groomerAccent,
            DesignTokens.ColorHex.groomerAccentDark,
        ]

        for background in brandBackgrounds {
            #expect(Self.contrastRatio(foreground, background) >= requiredRatio)
        }
    }

    @Test
    func statusTextColorsMeetAAOnSurface() {
        for color in [
            DesignTokens.ColorHex.successText,
            DesignTokens.ColorHex.warningText,
            DesignTokens.ColorHex.errorText,
        ] {
            #expect(Self.contrastRatio(color, DesignTokens.ColorHex.surface) >= 4.5)
        }
    }

    private static func contrastRatio(_ firstHex: UInt, _ secondHex: UInt) -> Double {
        let first = relativeLuminance(firstHex)
        let second = relativeLuminance(secondHex)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ hex: UInt) -> Double {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255

        let linearRed = linearized(red)
        let linearGreen = linearized(green)
        let linearBlue = linearized(blue)
        return 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
    }

    private static func linearized(_ component: Double) -> Double {
        if component <= 0.03928 {
            return component / 12.92
        }

        return pow((component + 0.055) / 1.055, 2.4)
    }
}
