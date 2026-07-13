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
}
