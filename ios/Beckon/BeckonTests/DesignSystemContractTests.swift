import SwiftUI
import Testing
@testable import Beckon

@MainActor
struct DesignSystemContractTests {
    @Test
    func semanticLayoutMetricsUseTheApprovedGrid() {
        #expect(DesignTokens.Layout.pageHorizontalInset == 20)
        #expect(DesignTokens.Layout.pageTopInset == 24)
        #expect(DesignTokens.Layout.pageBottomInset == 48)
        #expect(DesignTokens.Layout.sectionSpacing == 24)
        #expect(DesignTokens.Layout.sectionContentSpacing == 12)
        #expect(DesignTokens.Layout.surfaceInset == 16)
        #expect(DesignTokens.Layout.rowHorizontalInset == 16)
        #expect(DesignTokens.Layout.rowVerticalInset == 12)
        #expect(DesignTokens.Layout.fieldSpacing == 12)
        #expect(DesignTokens.Layout.actionAreaInset == 12)
        #expect(DesignTokens.Metrics.minimumTouchTarget == 44)
        #expect(DesignTokens.Metrics.fieldHeight == 52)
        #expect(DesignTokens.Metrics.actionHeight == 52)
        #expect(DesignTokens.Metrics.settingsIconSlot == 36)
    }

    @Test
    func legacyCardElevationsAliasTheCanonicalSoftCard() {
        #expect(DesignTokens.Shadows.smallCard.radius == DesignTokens.Shadows.softCard.radius)
        #expect(DesignTokens.Shadows.smallCard.x == DesignTokens.Shadows.softCard.x)
        #expect(DesignTokens.Shadows.smallCard.y == DesignTokens.Shadows.softCard.y)
        #expect(DesignTokens.Shadows.carouselCard.radius == DesignTokens.Shadows.softCard.radius)
        #expect(DesignTokens.Shadows.carouselCard.x == DesignTokens.Shadows.softCard.x)
        #expect(DesignTokens.Shadows.carouselCard.y == DesignTokens.Shadows.softCard.y)
    }

    @Test
    func primaryActionVisualAvailabilityCombinesWithEnvironmentAvailability() {
        let visuallyUnavailable = BeckonPrimaryActionAvailability(
            isEnvironmentEnabled: true,
            isVisuallyEnabled: false
        )
        #expect(visuallyUnavailable.rendersEnabled == false)
        #expect(visuallyUnavailable.acceptsTap == true)

        let environmentUnavailable = BeckonPrimaryActionAvailability(
            isEnvironmentEnabled: false,
            isVisuallyEnabled: true
        )
        #expect(environmentUnavailable.rendersEnabled == false)
        #expect(environmentUnavailable.acceptsTap == false)
    }

    @Test
    func keyboardAwareFormsAlwaysProvideDismissalPaths() {
        #expect(BeckonKeyboardDismissalPolicy.supportsInteractiveScroll)
        #expect(BeckonKeyboardDismissalPolicy.supportsExplicitDoneAction)
    }

    @Test
    func sheetDismissalIsSuspendedOnlyWhileSoftwareKeyboardIsOnScreen() {
        let screen = CGRect(x: 0, y: 0, width: 390, height: 844)

        #expect(BeckonKeyboardPresentationPolicy.preventSheetDismissal(
            keyboardFrame: CGRect(x: 0, y: 500, width: 390, height: 344),
            screenBounds: screen
        ))
        #expect(BeckonKeyboardPresentationPolicy.preventSheetDismissal(
            keyboardFrame: CGRect(x: 120, y: 420, width: 250, height: 220),
            screenBounds: screen
        ))
        #expect(!BeckonKeyboardPresentationPolicy.preventSheetDismissal(
            keyboardFrame: CGRect(x: 0, y: 844, width: 390, height: 0),
            screenBounds: screen
        ))
        #expect(!BeckonKeyboardPresentationPolicy.preventSheetDismissal(
            keyboardFrame: CGRect(x: 0, y: 844, width: 390, height: 344),
            screenBounds: screen
        ))
        #expect(BeckonKeyboardPresentationPolicy.preventSheetDismissal(
            keyboardFrame: CGRect(x: 0, y: 844, width: 390, height: 0),
            screenBounds: screen,
            additionallyPrevented: true
        ))
    }
}
