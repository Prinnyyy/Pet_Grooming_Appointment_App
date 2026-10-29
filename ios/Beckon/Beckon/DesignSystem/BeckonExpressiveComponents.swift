import SwiftUI


// Expressive (Tier L/M) building blocks. Spec: docs/01_product/LIVELY_UI_SPEC.md.
// Customer-side expression only; Tier C screens keep the existing calm primitives.

/// Section heading: mint icon tile + heavy rounded title + optional count. Exposes the header trait (A11Y-R6).
struct BeckonLedgeHeading: View {
    let title: String
    let systemImage: String
    var count: Int?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)
                .beckonLedge(.pill)
                .accessibilityHidden(true)
            Text(title)
                .font(DesignTokens.Typography.Expressive.section)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let count, count > 0 {
                Text("\(count)")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(DesignTokens.Colors.customerTint, in: Capsule())
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
    }
}


/// Small informational capsule. Not interactive.
struct BeckonMetaChip: View {
    let text: String
    let systemImage: String
    var onTint = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs + 1) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.micro)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
            Text(text)
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, DesignTokens.Spacing.xs + 1)
        .background(onTint ? DesignTokens.Colors.surface : DesignTokens.Colors.customerTint, in: Capsule())
    }
}


/// Unread count badge. Count text is surface on the unread dot color (approved pair, see ACCESSIBILITY_RULES.md).
struct BeckonUnreadCountBadge: View {
    let count: Int
    let isShown: Bool

    var body: some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(DesignTokens.Typography.Expressive.caption)
            .foregroundStyle(DesignTokens.Colors.surface)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(DesignTokens.Colors.unreadDot, in: Capsule())
            .overlay(Capsule().strokeBorder(DesignTokens.Colors.appBackground, lineWidth: DesignTokens.Ledge.edgeWidth))
            .scaleEffect(isShown ? 1 : 0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}


/// Empty or informational note on the card surface.
struct BeckonLedgeNote: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignIconDisc(systemImage: systemImage, size: .touch, font: DesignTokens.Typography.Expressive.glyph)
            Text(text)
                .designSupportingText()
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.md + 2)
        .beckonLedge(.card)
    }
}


/// Label of the primary hero button: scissors glyph + title, stacked at accessibility sizes, with a periodic shine.
struct BeckonLedgePrimaryLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
            Text(title)
                .font(DesignTokens.Typography.Expressive.headline)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, typeSize.isAccessibilitySize ? DesignTokens.Spacing.md : 0)
        .overlay { BeckonShine(radius: DesignTokens.CornerRadius.ledgeButton) }
    }
}


/// Calendar tile: mint month band over a bordered day number. Inline tile, so border only, no ledge.
/// Glyph-like: its text is also in the card's own time summary, so Dynamic Type is capped to keep the tile intact.
struct BeckonDateTile: View {
    let month: String
    let day: String

    var body: some View {
        VStack(spacing: 0) {
            Text(month)
                .font(DesignTokens.Typography.Expressive.micro)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(DesignTokens.Colors.customerFill)
            Text(day)
                .font(DesignTokens.Typography.Expressive.hero)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(minWidth: 62)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous)
            .strokeBorder(DesignTokens.Colors.border, lineWidth: DesignTokens.Ledge.edgeWidth))
        .accessibilityHidden(true)
    }
}


/// Top strip of a booking card: alarm glyph (rings every few seconds), countdown, trailing value.
struct BeckonCountdownStrip: View {
    let title: String
    let trailing: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let still = reduceMotion
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))) {
            Image(systemName: "alarm.fill")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { content, angle in
                    content.rotationEffect(.degrees(still ? 0 : angle))
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0, duration: 2.6)
                        CubicKeyframe(-16, duration: 0.07)
                        CubicKeyframe(16, duration: 0.1)
                        CubicKeyframe(-12, duration: 0.1)
                        CubicKeyframe(12, duration: 0.1)
                        CubicKeyframe(0, duration: 0.08)
                    }
                }
                .accessibilityHidden(true)
            Text(title).font(DesignTokens.Typography.Expressive.emphasis)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(trailing).font(DesignTokens.Typography.Expressive.emphasis)
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, typeSize.isAccessibilitySize ? DesignTokens.Spacing.sm : 0)
        .frame(minHeight: 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.customerFill)
    }
}


/// Greeting hand that waves a few times when the page first appears. Decorative; amber never encodes state.
struct BeckonWaveHand: View {
    @Environment(\.beckonEntranceReplay) private var replay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waveUp = false
    @State private var playedReplay: Int?

    var body: some View {
        Image(systemName: "hand.wave.fill")
            .font(DesignTokens.Typography.Expressive.glyphLarge)
            .foregroundStyle(DesignTokens.Colors.ratingStar)
            .rotationEffect(.degrees(waveUp ? 18 : -12), anchor: .bottomTrailing)
            .accessibilityHidden(true)
            .task(id: replay) {
                guard playedReplay != replay else { return }
                playedReplay = replay
                waveUp = false
                guard !reduceMotion else { return }
                try? await Task.sleep(for: .milliseconds(700))
                for _ in 0..<3 {
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.26)) { waveUp = true }
                    try? await Task.sleep(for: .milliseconds(260))
                    withAnimation(.easeInOut(duration: 0.26)) { waveUp = false }
                    try? await Task.sleep(for: .milliseconds(260))
                }
            }
    }
}


/// Label of a dashed "add" slot: a plus that turns on its own beat, and a caption.
struct BeckonLedgeAddSlot: View {
    let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let still = reduceMotion
        VStack(spacing: DesignTokens.Spacing.md) {
            DesignIconDisc(systemImage: "plus", size: .large, font: DesignTokens.Typography.Expressive.section, isDecorative: false)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { content, angle in
                    content.rotationEffect(.degrees(still ? 0 : angle))
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0, duration: 3.6)
                        SpringKeyframe(90, duration: 0.55, spring: .bouncy)
                        LinearKeyframe(90, duration: 2.4)
                        SpringKeyframe(180, duration: 0.55, spring: .bouncy)
                        LinearKeyframe(180, duration: 0.01)
                    }
                }
                .accessibilityHidden(true)
            Text(title)
                .font(DesignTokens.Typography.Expressive.headline)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        // Fills whatever size the caller gives it; the pet carousel passes the pet card size.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


/// The page background by role: the mint wash for a customer, the plain page colour for a groomer.
struct BeckonRoleBackdrop: View {
    let role: UserRole

    var body: some View {
        if role == .customer {
            BeckonExpressiveBackdrop()
        } else {
            DesignTokens.Colors.appBackground
                .ignoresSafeArea()
        }
    }
}


/// Soft mint wash behind an expressive page; fades into the warm page color.
struct BeckonExpressiveBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
                startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
            DesignTokens.Colors.appBackground
        }
        .ignoresSafeArea()
    }
}
