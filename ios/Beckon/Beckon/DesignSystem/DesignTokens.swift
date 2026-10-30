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
        // The scene behind Home's greeting (design): sky, two ranges of mountains, a lawn.
        static let sceneSkyTop: UInt = 0xD6EEEA
        static let sceneSkyHorizon: UInt = 0xEAF7F3
        static let sceneMountainFar: UInt = 0xCDE8E8
        static let sceneMountainNear: UInt = 0xB9DFDB
        static let sceneLawn: UInt = 0xB1E0C5
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
        static let sceneSkyTop = Palette.sceneSkyTop
        static let sceneSkyHorizon = Palette.sceneSkyHorizon
        static let sceneMountainFar = Palette.sceneMountainFar
        static let sceneMountainNear = Palette.sceneMountainNear
        static let sceneLawn = Palette.sceneLawn
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
        /// A placeholder bar of a page that is loading, and the light that sweeps over it (design).
        static let skeleton = Color(hex: ColorHex.customerTint)
        /// A bar on the page itself (the mint wash at the top is as light as `skeleton`, so it would vanish there).
        static let skeletonOnPage = Color(hex: ColorHex.customerHeroBubble)
        static let skeletonSweep = Color(hex: ColorHex.surface, opacity: 0.85)
        static let groomerFill = Color(hex: ColorHex.groomerFill)
        static let groomerFillPressed = Color(hex: ColorHex.groomerFillPressed)
        static let groomerInk = Color(hex: ColorHex.groomerInk)
        static let groomerDeep = Color(hex: ColorHex.groomerDeep)
        static let groomerTint = Color(hex: ColorHex.groomerTint)
        static let customerHeroEnd = Color(hex: ColorHex.customerHeroEnd)
        static let customerHeroBubble = Color(hex: ColorHex.customerHeroBubble)
        static let customerHeroDecoration = Color(hex: ColorHex.customerHeroDecoration)
        static let sceneSkyTop = Color(hex: ColorHex.sceneSkyTop)
        static let sceneSkyHorizon = Color(hex: ColorHex.sceneSkyHorizon)
        static let sceneMountainFar = Color(hex: ColorHex.sceneMountainFar)
        static let sceneMountainNear = Color(hex: ColorHex.sceneMountainNear)
        static let sceneLawn = Color(hex: ColorHex.sceneLawn)
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
        /// What a dialog dims the page with: the warm ink, not black, so the page stays warm underneath. The one place a
        /// translucent fill is allowed, because dimming is what a scrim is.
        static let scrim = Color(hex: ColorHex.textPrimary, opacity: 0.46)

    }

    // Decorative material, not a control surface or an informational foreground.
    enum BrandIllustration {
        static let body = Colors.customerFill
        static let highlight = Color(hex: ColorHex.surface, opacity: 0.42)
        static let satellite = Color(hex: ColorHex.customerFill, opacity: 0.28)
    }

    enum Spacing {
        static let none: CGFloat = 0
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
        static let messageGlyphTopInset: CGFloat = 2
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
        /// The row of a tab's big title (Grooming, Messages, Account): as tall as the tallest thing that can stand in it (the New Request
        /// pill), so that the title and what is under it are at the same height on every tab (design).
        static let homeTitleSize: CGFloat = 46
        // Adopted Home greeting only: a single decorative title may shrink before wrapping.
        static let homeTitleMinimumScale: CGFloat = 0.5
        static let launchBottomReserve = ledgePrimaryButtonHeight * 2 + Spacing.xl
        static let groomingPathHeadroom: CGFloat = 48
        static let groomingPathConnector: CGFloat = 9
        static let groomingPetAvatar: CGFloat = 48
        static let tabTitleRowHeight: CGFloat = 52
        static let fieldHeight: CGFloat = 52
        static let actionHeight: CGFloat = 52
        static let settingsIconSlot: CGFloat = 36
        // Expressive (Lively) surfaces; see docs/01_product/LIVELY_UI_SPEC.md.
        static let ledgeRoundControl: CGFloat = 54
        static let ledgeIconTile: CGFloat = 34
        /// The large tinted disc (the Home add slot); `ledgeIconTile` and `minimumTouchTarget` are the other two sizes.
        static let iconDiscLarge: CGFloat = 60
        static let ledgePrimaryButtonHeight: CGFloat = 58
        static let journeyNode: CGFloat = 42
        /// The same path with four stops (a whole grooming) is a little smaller so four fit the width of a card.
        static let journeyNodeMedium: CGFloat = 40
        /// Sideways rows of cards (`BeckonPeekCarousel`): the first `carouselPeek` points of the next card always show, so the
        /// row reads as something to swipe; `carouselCardMinimumWidth` is the floor of a card on a small phone.
        static let carouselPeek: CGFloat = 44
        static let carouselCardMinimumWidth: CGFloat = 140
        /// Home pet card and its add slot: one size whatever the pet's data (the width is the carousel's). Height scales with
        /// Dynamic Type.
        static let petCardWidth: CGFloat = 176
        static let petCardHeight: CGFloat = 240
        /// The grooming cards (Grooming tab, Home): one height for every card of a row, whatever the request or booking, so a longer
        /// or shorter one never makes a card taller than its neighbour. `groomingCardHeight` is the full card (who and when, facts,
        /// path, button, quiet actions), `groomingGlanceCardHeight` Home's (who and when, path). Both scale with Dynamic Type; accessibility sizes stack
        /// natural-height cards.
        static let groomingCardHeight: CGFloat = 384
        static let groomingGlanceCardHeight: CGFloat = 212
        /// Widest a dialog (alert or modal) grows; on a phone it is the screen minus the gutters.
        static let dialogMaxWidth: CGFloat = 360
    }

    enum CornerRadius {
        static let messageBubble: CGFloat = 22
        static let card: CGFloat = 24
        static let button: CGFloat = 18
        static let input: CGFloat = 16
        static let bottomSheet: CGFloat = 28
        // Expressive (Lively) surfaces.
        static let hero: CGFloat = 30
        static let ledgeButton: CGFloat = 20
        /// Tiles and portraits nested inside a card.
        static let inset: CGFloat = 18
        static let pill: CGFloat = 14
        /// Large enough to clamp a ledge control to a circle.
        static let round: CGFloat = 99
    }

    /// Height of the opaque ledge under an expressive surface. A lip, never a blur or glow.
    enum Ledge {
        static let button: CGFloat = 6
        static let card: CGFloat = 5
        static let control: CGFloat = 4
        static let pill: CGFloat = 3
        static let edgeWidth: CGFloat = 2
        static let dashedEdgeWidth: CGFloat = 2.5
        static let dash: [CGFloat] = [7, 6]
    }

    /// Springs and timings for expressive (Tier L/M) motion. Reduce Motion collapses all of them to `reduced`.
    enum Motion {
        /// Face sinks into its lip, then springs back with overshoot.
        static let press = Animation.spring(response: 0.26, dampingFraction: 0.46)
        /// Progress and stage changes.
        static let settle = Animation.spring(response: 0.6, dampingFraction: 0.62)
        /// State flips on a node or badge.
        static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.5)
        /// Content swaps.
        static let swap = Animation.spring(response: 0.45, dampingFraction: 0.7)
        /// A button turning into another look (white card to mint pill, a pill to a round control): the face, its corners, its lip and its
        /// edge stretch from one to the other with a little overshoot, instead of one fading out as the other fades in (S-066).
        static let morph = Animation.spring(response: 0.42, dampingFraction: 0.64)
        static let reduced = Animation.easeOut(duration: 0.15)
        /// A dialog drops in with a little overshoot and leaves quickly; the page behind it is not worth waiting for.
        static let dialogEnter = Animation.spring(response: 0.42, dampingFraction: 0.66)
        static let dialogExit = Animation.easeIn(duration: 0.16)
        /// How long a finger must stay on a button before it sinks and buzzes. A touch that turns into a scroll cancels
        /// well inside this, so scrolling over cards and pills stays quiet.
        static let pressSettleMilliseconds = 80

        /// How a family of pages arrives. Every block of a page lands one `beat` after the one above it (the first block, the
        /// leader, lands with more bounce), travelling `travel` points from where it settles, so all pages of a family keep
        /// one tempo. Springs overshoot on purpose: the page is dealt, not faded in.
        struct Entrance {
            /// Seconds between two blocks.
            let beat: Double
            /// Blocks past this many all land together with the last one, so a long page never trickles.
            let maxBeats: Int
            /// Points a block starts away from its place (up from below, or in from the side along a journey).
            let travel: CGFloat
            let scale: CGFloat
            let leaderScale: CGFloat
            /// Degrees a block starts turned; the sign alternates block by block. Zero keeps a page upright.
            let tilt: Double
            let spring: Animation
            let leaderSpring: Animation
        }

        /// A journey of steps (request wizard, pet form): blocks slide in from the side the person is heading to, with a lean.
        /// Quicker than the other two on purpose (S-039): a person taps Continue again and again, and each step is dealt for only
        /// about a third of a second before the next tap can come.
        static let stepEntrance = Entrance(beat: 0.045, maxBeats: 6, travel: 36, scale: 0.94, leaderScale: 0.88, tilt: 1.8,
            spring: .spring(response: 0.4, dampingFraction: 0.6), leaderSpring: .spring(response: 0.44, dampingFraction: 0.54))
        /// A detail page (request, booking, groomer): the hero lands first, the rest rises under it, upright and a touch slower.
        static let detailEntrance = Entrance(beat: 0.085, maxBeats: 4, travel: 30, scale: 0.94, leaderScale: 0.88, tilt: 0,
            spring: .spring(response: 0.52, dampingFraction: 0.62), leaderSpring: .spring(response: 0.58, dampingFraction: 0.52))
        /// A tab root or a list: cards are dealt quickly, a small lean on each.
        static let listEntrance = Entrance(beat: 0.055, maxBeats: 6, travel: 24, scale: 0.96, leaderScale: 0.9, tilt: 1.0,
            spring: .spring(response: 0.46, dampingFraction: 0.62), leaderSpring: .spring(response: 0.52, dampingFraction: 0.54))
        /// The primary action leans in a little after a page lands.
        static let bumpScale: CGFloat = 0.92
        /// The current node of a step path while a flow moves along it.
        static let currentNodeScale: CGFloat = 1.14
        /// Decorative loops redraw at this rate.
        static let idleFrame = 1.0 / 30
        /// A placeholder turning into what it stood for: the same place, a plain cross-fade, no travel (design).
        static let reveal = Animation.easeInOut(duration: 0.32)
        /// The light across a loading page takes this long from one edge to the other and rests a moment.
        static let skeletonPeriod = 1.6
        /// Data that arrives sooner than this never shows a placeholder; one that was shown stays at least `skeletonMinimum`.
        static let skeletonShowDelay = 0.15
        static let skeletonMinimum = 0.45
        static let launchMinimum: Double = 0.7
        static let pullRefreshMinimum = 1.0
    }

    enum Shapes {
        static let chip = Capsule()
        static let circular = Circle()
    }

    enum Shadows {
        static let brandBubble = ShadowStyle(
            color: Color(hex: ColorHex.textPrimary, opacity: 0.20),
            radius: 12,
            x: 0,
            y: 8,
            spread: 0
        )
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

        /// SF Rounded roles for expressive (Tier L/M) screens. Still semantic text styles, so Dynamic Type applies.
        enum Expressive {
            static func homeGreeting(size: CGFloat) -> Font {
                .system(size: size, weight: .black, design: .rounded)
            }
            static let display = Font.system(.largeTitle, design: .rounded, weight: .black)
            static let hero = Font.system(.title, design: .rounded, weight: .black)
            static let section = Font.system(.title2, design: .rounded, weight: .black)
            static let title = Font.system(.title3, design: .rounded, weight: .black)
            static let headline = Font.system(.headline, design: .rounded, weight: .black)
            static let body = Font.system(.callout, design: .rounded, weight: .semibold)
            static let supporting = Font.system(.subheadline, design: .rounded, weight: .semibold)
            static let emphasis = Font.system(.subheadline, design: .rounded, weight: .black)
            static let label = Font.system(.footnote, design: .rounded, weight: .black)
            static let labelMuted = Font.system(.footnote, design: .rounded, weight: .bold)
            static let caption = Font.system(.caption, design: .rounded, weight: .black)
            static let chip = Font.system(.caption, design: .rounded, weight: .bold)
            static let micro = Font.system(.caption2, design: .rounded, weight: .black)
            static let glyph = Font.system(.title3, design: .rounded, weight: .bold)
            static let glyphLarge = Font.system(.title, design: .rounded, weight: .bold)
            // Decorative artwork and ticks scale with their fixed drawing, not text content.
            static let workPlaceholder = Font.system(size: 72, weight: .bold, design: .rounded)
            static let workSparkle = Font.system(size: 22, weight: .bold, design: .rounded)
            static let timelineGlyph = Font.system(size: 12, weight: .black, design: .rounded)
            static let selectionGlyph = Font.system(size: 13, weight: .black, design: .rounded)
        }

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
