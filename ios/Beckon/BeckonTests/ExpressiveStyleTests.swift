import Foundation
import Testing
@testable import Beckon

// Executable half of docs/01_product/LIVELY_UI_SPEC.md (D-063).

@MainActor
struct ExpressiveTokenTests {
    private struct Pair {
        let name: String
        let foreground: UInt
        let background: UInt
        /// 4.5 for text, 3.0 for meaningful graphics.
        let minimum: Double
    }

    private static func luminance(_ hex: UInt) -> Double {
        func channel(_ value: UInt) -> Double {
            let s = Double(value & 0xFF) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16) + 0.7152 * channel(hex >> 8) + 0.0722 * channel(hex)
    }

    private static func ratio(_ a: UInt, _ b: UInt) -> Double {
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Every foreground/background pair the expressive kit puts text or meaningful graphics on.
    /// Adding a combination to the kit means adding a row here.
    private static let pairs: [Pair] = {
        typealias H = DesignTokens.ColorHex
        return [
            Pair(name: "Ink on Fill: pill, countdown strip, done node, hero start", foreground: H.customerInk, background: H.customerFill, minimum: 4.5),
            Pair(name: "Ink on Hero end", foreground: H.customerInk, background: H.customerHeroEnd, minimum: 4.5),
            Pair(name: "Ink on Hero bubble: copy over drifting bubbles", foreground: H.customerInk, background: H.customerHeroBubble, minimum: 4.5),
            Pair(name: "Ink on Tint: chips", foreground: H.customerInk, background: H.customerTint, minimum: 4.5),
            Pair(name: "Ink on surface: bell glyph, primary label", foreground: H.customerInk, background: H.surface, minimum: 4.5),
            Pair(name: "Deep on surface: current node, scissors glyph", foreground: H.customerDeep, background: H.surface, minimum: 4.5),
            Pair(name: "Deep on Tint: count pill, chevron chip", foreground: H.customerDeep, background: H.customerTint, minimum: 4.5),
            Pair(name: "Deep ledge against Fill face (graphic)", foreground: H.customerDeep, background: H.customerFill, minimum: 3.0),
            Pair(name: "Primary text on surface", foreground: H.textPrimary, background: H.surface, minimum: 4.5),
            Pair(name: "Primary text on page", foreground: H.textPrimary, background: H.appBackground, minimum: 4.5),
            Pair(name: "Secondary text on surface", foreground: H.textSecondary, background: H.surface, minimum: 4.5),
            Pair(name: "Secondary text on page", foreground: H.textSecondary, background: H.appBackground, minimum: 4.5),
            Pair(name: "Tertiary text on page: Add pet, upcoming labels", foreground: H.textTertiary, background: H.appBackground, minimum: 4.5),
            Pair(name: "Tertiary glyph on placeholder: upcoming node (graphic)", foreground: H.textTertiary, background: H.placeholderFill, minimum: 3.0),
            Pair(name: "Warning text on warning Fill: offers callout", foreground: H.statusWarningText, background: H.statusWarningFill, minimum: 4.5),
            Pair(name: "Success text on success Fill: booked callout", foreground: H.statusSuccessText, background: H.statusSuccessFill, minimum: 4.5),
            Pair(name: "Unread count: surface on unread dot", foreground: H.surface, background: H.unreadDot, minimum: 4.5),
            Pair(name: "Unread dot against page (graphic)", foreground: H.unreadDot, background: H.appBackground, minimum: 3.0),
        ]
    }()

    @Test
    func everyDeclaredPairMeetsItsFloor() {
        for pair in Self.pairs {
            let ratio = Self.ratio(pair.foreground, pair.background)
            #expect(ratio >= pair.minimum, "\(pair.name) is \(ratio), needs \(pair.minimum)")
        }
    }

    @Test
    func whiteIsNeverUsedOnLightRoleFills() {
        typealias H = DesignTokens.ColorHex
        for fill in [H.customerFill, H.customerFillPressed, H.customerHeroEnd, H.groomerFill, H.groomerFillPressed] {
            #expect(Self.ratio(H.surface, fill) < 3)
        }
    }

    @Test
    func ledgeAndMotionTokensMatchTheSpec() {
        #expect(DesignTokens.Ledge.button == 6)
        #expect(DesignTokens.Ledge.card == 5)
        #expect(DesignTokens.Ledge.control == 4)
        #expect(DesignTokens.Ledge.pill == 3)
        #expect(DesignTokens.Ledge.edgeWidth == 2)
        #expect(DesignTokens.CornerRadius.hero == 30)
        #expect(DesignTokens.CornerRadius.ledgeButton == 20)
        #expect(DesignTokens.CornerRadius.inset == 18)
        #expect(DesignTokens.CornerRadius.pill == 14)
        #expect(DesignTokens.Metrics.ledgeRoundControl >= DesignTokens.Metrics.minimumTouchTarget)
        #expect(DesignTokens.Metrics.ledgePrimaryButtonHeight >= DesignTokens.Metrics.minimumTouchTarget)
        #expect(DesignTokens.Motion.stepEntrance.beat == 0.045)
        #expect(DesignTokens.Motion.detailEntrance.beat == 0.085)
        #expect(DesignTokens.Motion.listEntrance.beat == 0.055)
        for family in [DesignTokens.Motion.stepEntrance, DesignTokens.Motion.detailEntrance, DesignTokens.Motion.listEntrance] {
            #expect(Double(family.maxBeats) * family.beat <= 0.35)
        }
    }

    @Test
    func surfacesHaveAVisibleLedgeAndNeverUseABlur() {
        for surface in [BeckonLedgeSurface.card, .round, .primary, .pill, .dashed] {
            #expect(surface.depth >= DesignTokens.Ledge.pill)
            #expect(surface.depth <= DesignTokens.Ledge.button)
            #expect(surface.radius > 0)
        }
        #expect(BeckonLedgeSurface.dashed.isDashed)
        #expect(!BeckonLedgeSurface.card.isDashed)
    }
}

@MainActor
struct BeckonBookingCountdownTests {
    private let now = ISO8601DateFormatter().date(from: "2026-10-23T20:00:00Z")! // 1:00 PM in Los Angeles

    private func booking(start: String, zone: String? = "America/Los_Angeles") -> Booking {
        BookingsStoreTests.booking(scheduledStart: start, scheduledEnd: start, serviceTimeZoneIdentifier: zone)
    }

    @Test
    func labelsCalendarDaysInTheServiceTimeZone() {
        // 8 PM on Oct 23 in Los Angeles is already Oct 24 in UTC; the booking's zone decides.
        #expect(BeckonBookingCountdown.label(for: booking(start: "2026-10-24T03:00:00Z"), now: now) == "Today")
        #expect(BeckonBookingCountdown.label(for: booking(start: "2026-10-24T03:00:00Z", zone: "UTC"), now: now) == "Tomorrow")
        #expect(BeckonBookingCountdown.label(for: booking(start: "2026-10-24T19:00:00Z"), now: now) == "Tomorrow")
        #expect(BeckonBookingCountdown.label(for: booking(start: "2026-10-26T19:00:00Z"), now: now) == "In 3 days")
    }

    @Test
    func pastDaysAndUnparseableStartsHaveNoCountdown() {
        #expect(BeckonBookingCountdown.label(for: booking(start: "2026-10-22T19:00:00Z"), now: now) == nil)
        #expect(BeckonBookingCountdown.label(for: booking(start: "not a date"), now: now) == nil)
        #expect(BeckonBookingCountdown.dateParts(for: booking(start: "not a date")) == nil)
    }

    @Test
    func datePartsUseTheServiceTimeZone() throws {
        let la = try #require(BeckonBookingCountdown.dateParts(for: booking(start: "2026-10-24T03:00:00Z")))
        #expect(la.month == "OCT" && la.day == "23")
        let utc = try #require(BeckonBookingCountdown.dateParts(for: booking(start: "2026-10-24T03:00:00Z", zone: "UTC")))
        #expect(utc.month == "OCT" && utc.day == "24")
    }
}
