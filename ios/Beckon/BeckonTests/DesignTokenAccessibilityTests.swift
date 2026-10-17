import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Beckon

@MainActor
struct DesignTokenAccessibilityTests {
    @Test
    func semanticPaletteUsesApprovedSRGBValues() {
        #expect(DesignTokens.ColorHex.appBackground == 0xFAF7F2)
        #expect(DesignTokens.ColorHex.surface == 0xFFFFFF)
        #expect(DesignTokens.ColorHex.border == 0xE8E2D8)
        #expect(DesignTokens.ColorHex.borderSoft == 0xECE6DC)
        #expect(DesignTokens.ColorHex.textPrimary == 0x2E2A26)
        #expect(DesignTokens.ColorHex.textSecondary == 0x625B53)
        #expect(DesignTokens.ColorHex.textTertiary == 0x756D65)
        #expect(DesignTokens.ColorHex.placeholderFill == 0xF1ECE4)
        #expect(DesignTokens.ColorHex.iconTileFill == 0xF3EEE7)
        #expect(DesignTokens.ColorHex.ratingStar == 0xF2B84B)
        #expect(DesignTokens.ColorHex.unreadDot == 0xB3203F)
        #expect(DesignTokens.ColorHex.customerFill == 0x81D0C2)
        #expect(DesignTokens.ColorHex.customerFillPressed == 0x73BEB1)
        #expect(DesignTokens.ColorHex.customerInk == 0x0F3D35)
        #expect(DesignTokens.ColorHex.customerDeep == 0x1E6E5F)
        #expect(DesignTokens.ColorHex.customerTint == 0xE3F5F2)
        #expect(DesignTokens.ColorHex.groomerFill == 0xFF9A8B)
        #expect(DesignTokens.ColorHex.groomerFillPressed == 0xFF8A79)
        #expect(DesignTokens.ColorHex.groomerInk == 0x4A1C14)
        #expect(DesignTokens.ColorHex.groomerDeep == 0xB23A2B)
        #expect(DesignTokens.ColorHex.groomerTint == 0xFFEDE9)
        #expect(DesignTokens.ColorHex.customerHeroEnd == 0xA4DDD3)
        #expect(DesignTokens.ColorHex.customerHeroBubble == 0xBAE5DD)
        #expect(DesignTokens.ColorHex.customerHeroDecoration == 0x6CB6A9)
        #expect(DesignTokens.ColorHex.statusSuccessText == 0x276B2B)
        #expect(DesignTokens.ColorHex.statusSuccessFill == 0xE6F2E6)
        #expect(DesignTokens.ColorHex.statusSuccessBorder == 0xCFE5CF)
        #expect(DesignTokens.ColorHex.statusWarningText == 0x8A5A00)
        #expect(DesignTokens.ColorHex.statusWarningFill == 0xFBF0D9)
        #expect(DesignTokens.ColorHex.statusWarningBorder == 0xF2DFB5)
        #expect(DesignTokens.ColorHex.statusErrorText == 0xB3203F)
        #expect(DesignTokens.ColorHex.statusErrorFill == 0xFBE8EC)
        #expect(DesignTokens.ColorHex.statusErrorBorder == 0xF0C9D1)
        #expect(DesignTokens.ColorHex.statusInfoText == 0x2F5F8A)
        #expect(DesignTokens.ColorHex.statusInfoFill == 0xE7EFF7)
        #expect(DesignTokens.ColorHex.statusInfoBorder == 0xCFDDEC)
        #expect(DesignTokens.ColorHex.statusNeutralText == 0x625B53)
        #expect(DesignTokens.ColorHex.statusNeutralFill == 0xF3EEE7)
        #expect(DesignTokens.ColorHex.statusNeutralBorder == 0xE8E2D8)
    }

    @Test
    func warmNeutralHierarchyAndCardElevationMatchTheAdoptedPalette() {
        #expect(Self.relativeLuminance(DesignTokens.ColorHex.textTertiary)
            > Self.relativeLuminance(DesignTokens.ColorHex.textSecondary))
        #expect(DesignTokens.Shadows.softCard.radius == 2)
        #expect(DesignTokens.Shadows.softCard.x == 0)
        #expect(DesignTokens.Shadows.softCard.y == 1)
        #expect(abs(UIColor(DesignTokens.Shadows.softCard.color).cgColor.alpha - 0.06) < 0.00000001)
    }

    @Test
    func rolePairsMeetAAAndWhiteOnLightFillsIsRejected() {
        for (fill, pressed, ink, deep, tint) in [
            (DesignTokens.ColorHex.customerFill, DesignTokens.ColorHex.customerFillPressed,
             DesignTokens.ColorHex.customerInk, DesignTokens.ColorHex.customerDeep, DesignTokens.ColorHex.customerTint),
            (DesignTokens.ColorHex.groomerFill, DesignTokens.ColorHex.groomerFillPressed,
             DesignTokens.ColorHex.groomerInk, DesignTokens.ColorHex.groomerDeep, DesignTokens.ColorHex.groomerTint),
        ] {
            for background in [fill, pressed] {
                #expect(Self.contrastRatio(ink, background) >= 4.5)
                #expect(Self.contrastRatio(DesignTokens.ColorHex.surface, background) < 3)
            }
            for background in [DesignTokens.ColorHex.surface, DesignTokens.ColorHex.appBackground, tint] {
                #expect(Self.contrastRatio(deep, background) >= 4.5)
            }
        }
    }

    @Test
    func statusPairsMeetAA() {
        for (text, fill) in [
            (DesignTokens.ColorHex.statusSuccessText, DesignTokens.ColorHex.statusSuccessFill),
            (DesignTokens.ColorHex.statusWarningText, DesignTokens.ColorHex.statusWarningFill),
            (DesignTokens.ColorHex.statusErrorText, DesignTokens.ColorHex.statusErrorFill),
            (DesignTokens.ColorHex.statusInfoText, DesignTokens.ColorHex.statusInfoFill),
            (DesignTokens.ColorHex.statusNeutralText, DesignTokens.ColorHex.statusNeutralFill),
        ] {
            #expect(Self.contrastRatio(text, fill) >= 4.5)
            #expect(Self.contrastRatio(text, DesignTokens.ColorHex.surface) >= 4.5)
        }
    }

    @Test
    func textHierarchyMeetsAAOnBothPageAndSurface() {
        for text in [DesignTokens.ColorHex.textPrimary, DesignTokens.ColorHex.textSecondary,
                     DesignTokens.ColorHex.textTertiary] {
            for background in [DesignTokens.ColorHex.surface, DesignTokens.ColorHex.appBackground] {
                #expect(Self.contrastRatio(text, background) >= 4.5)
            }
        }
        for background in [DesignTokens.ColorHex.customerFill, DesignTokens.ColorHex.customerHeroEnd,
                           DesignTokens.ColorHex.surface] {
            #expect(Self.contrastRatio(DesignTokens.ColorHex.customerInk, background) >= 4.5)
        }
    }

    @Test
    func sRGBMintPreservesThePreviousDisplayP3Fill() throws {
        let previous = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
            components: [0x93 / 255.0, 0xCE / 255.0, 0xC2 / 255.0, 1])!
        let sRGB = try #require(previous.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .relativeColorimetric, options: nil)?.components)
        let current = try #require(UIColor(DesignTokens.Colors.customerFill).cgColor
            .converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .relativeColorimetric, options: nil)?.components)
        for index in 0..<3 { #expect(abs(sRGB[index] - current[index]) < 2 / 255.0) }
    }


    private static func contrastRatio(_ firstHex: UInt, _ secondHex: UInt) -> Double {
        let first = relativeLuminance(firstHex)
        let second = relativeLuminance(secondHex)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func relativeLuminance(_ hex: UInt) -> Double {
        let red = linearized(Double((hex >> 16) & 0xFF) / 255)
        let green = linearized(Double((hex >> 8) & 0xFF) / 255)
        let blue = linearized(Double(hex & 0xFF) / 255)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private static func linearized(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
