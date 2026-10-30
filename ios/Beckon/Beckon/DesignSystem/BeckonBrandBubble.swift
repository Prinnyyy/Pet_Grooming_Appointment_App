//  brand artwork (S-085). The landing's orb, drawn in the customer style: a mint disc with the Home hero's gradient and
// an opaque lip (never a blur), the drawn Beckon pup in it (the one character of the app, not an emoji), and shampoo bubbles drifting
// around it like the ones in the Home hero. Stores and fixtures stay shared.
import SwiftUI


/// The brand lockup: the orb with the pup, "Beckon", and the line under it. The landing and the launch scene (design) show the same
/// one in the same place, so the app opens on it and the landing is the launch scene with its two buttons added.
struct BeckonLockup: View {
    var hasEntered = true
    var isExcited = false
    /// The words arrive as the first block of the page (the landing); the launch scene has them from its first frame.
    var dealsInWords = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            BeckonBrandBubble(isMotionEnabled: !reduceMotion && scenePhase == .active,
                hasEntered: hasEntered || reduceMotion, isExcited: isExcited)

            words.modifier(LockupEntrance(deals: dealsInWords))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var words: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("Beckon")
                .font(DesignTokens.Typography.Expressive.display)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text("Pet groomers at your beck and call.")
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 310)
        }
    }

    private struct LockupEntrance: ViewModifier {
        let deals: Bool

        func body(content: Content) -> some View {
            if deals { content.beckonEntrance(0) } else { content }
        }
    }
}


/// Brand artwork has its own material; it is not an actionable card.
struct BeckonBrandBubble: View {
    let isMotionEnabled: Bool
    var hasEntered = true
    /// The pup flings its ears: while the call to action is pressed, and for a beat when the orb lands.
    var isExcited = false
    @State private var hasLanded = false

    private let diameter: CGFloat = 176
    private let lip: CGFloat = 8
    /// The bubbles' places were set around a 156 pt orb; they widen with it.
    private let spread: CGFloat = 1.1

    var body: some View {
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: !isMotionEnabled)) { context in
            let time = isMotionEnabled ? context.date.timeIntervalSinceReferenceDate : 0
            let lift = isMotionEnabled ? sin(time * .pi / 2) * 4 : 0

            orb(time: time)
                .offset(y: lift)
                .scaleEffect(hasEntered ? 1 : 0.82)
                .offset(y: hasEntered ? 0 : -420)
                .opacity(hasEntered ? 1 : 0)
                .frame(width: diameter, height: diameter + lip + 12, alignment: .top)
                .background(alignment: .top) {
                    satellites(time: time)
                        .frame(width: diameter, height: diameter)
                }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: hasEntered && isMotionEnabled) {
            hasLanded = false
            guard hasEntered, isMotionEnabled else { return }
            do {
                try await Task.sleep(for: .milliseconds(420))
                hasLanded = true
                try await Task.sleep(for: .milliseconds(850))
                hasLanded = false
            } catch { hasLanded = false }
        }
    }

    private func orb(time: TimeInterval) -> some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.customerFillPressed)
                .offset(y: lip)
            Circle()
                .fill(LinearGradient(
                    colors: [DesignTokens.Colors.customerFill, DesignTokens.Colors.customerHeroEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(RadialGradient(
                    colors: [DesignTokens.BrandIllustration.highlight, .clear],
                    center: .init(x: 0.28, y: 0.22),
                    startRadius: 0, endRadius: 100))
            BeckonPup(time: time, excited: isExcited || hasLanded)
                .frame(width: 120, height: 92)
                .scaleEffect(1.26)
                .offset(y: 2)
        }
        .frame(width: diameter, height: diameter)
    }

    private func satellites(time: TimeInterval) -> some View {
        ZStack {
            satellite(size: 16, x: -118, y: -44, time: time, period: 6, phase: 0)
            satellite(size: 22, x: 118, y: -24, time: time, period: 7, phase: 1)
            satellite(size: 12, x: -130, y: 58, time: time, period: 6.4, phase: 2)
            satellite(size: 18, x: 130, y: 74, time: time, period: 7.2, phase: 3)
            satellite(size: 10, x: 60, y: -108, time: time, period: 5.6, phase: 4)
            satellite(size: 26, x: -100, y: 112, time: time, period: 8, phase: 5)
            satellite(size: 9, x: 0, y: -124, time: time, period: 6.2, phase: 6)
        }
    }

    /// A shampoo bubble: the same two-circle drawing as the Home hero's, in the quiet tint a wash can hold.
    private func satellite(size: CGFloat, x: CGFloat, y: CGFloat,
                           time: TimeInterval, period: Double, phase: Double) -> some View {
        let drift = isMotionEnabled ? sin(time * 2 * .pi / period + phase) : 0
        return ZStack(alignment: .topLeading) {
            Circle().fill(DesignTokens.BrandIllustration.satellite)
            Circle().fill(DesignTokens.Colors.surface)
                .frame(width: size * 0.26, height: size * 0.26)
                .offset(x: size * 0.2, y: size * 0.18)
        }
        .frame(width: size, height: size)
        .offset(x: x * spread + drift * 3, y: y * spread + drift * 7)
    }
}
