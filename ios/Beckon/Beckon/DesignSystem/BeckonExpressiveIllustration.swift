import SwiftUI

// Expressive illustration layer (Tier L only). Like `BeckonBrandBubble` it is decorative material:
// hidden from accessibility, never intercepts touches, and stands still under Reduce Motion or an inactive scene.
// The pup is the only place Groomer coral appears inside Customer UI. Spec: docs/01_product/LIVELY_UI_SPEC.md.

/// Customer hero: related-color gradient with drifting bubbles, a Deep-lipped base, and the pup peeking over the edge.
/// `content` is the hero copy and its primary button; `isExcited` perks the pup while that button is pressed.
struct BeckonLedgeHero<Content: View>: View {
    var isExcited = false
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topTrailing) {
            card.padding(.top, 46)
            pup.padding(.trailing, 22).offset(y: -16)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) { content }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, 26)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(colors: [DesignTokens.Colors.customerFill, DesignTokens.Colors.customerHeroEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    BeckonBubbles()
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.hero, style: .continuous))
            }
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.hero, style: .continuous)
                    .fill(DesignTokens.Colors.customerFillPressed)
                    .offset(y: 7)
            }
            .padding(.bottom, 7)
            .accessibilityElement(children: .contain)
    }

    private var pup: some View {
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused
        return TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: paused)) { context in
            BeckonPup(time: paused ? 0 : context.date.timeIntervalSinceReferenceDate, excited: isExcited)
        }
        .frame(width: 120, height: 92)
        .scaleEffect(0.92, anchor: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A sweep of light across the primary button every few seconds.
struct BeckonShine: View {
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if !BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused {
            TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let progress = min(t.truncatingRemainder(dividingBy: 4.4), 1.4)
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, DesignTokens.Colors.customerHeroBubble, .clear],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(width: 64, height: proxy.size.height * 2)
                        .rotationEffect(.degrees(20))
                        .position(x: -70 + progress * (proxy.size.width + 140), y: proxy.size.height / 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Slow shampoo bubbles drifting up behind the hero copy.
struct BeckonBubbles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private struct Spec { let x: Double; let size: Double; let speed: Double; let phase: Double; let wobble: Double }
    private static let specs: [Spec] = [
        .init(x: 0.08, size: 26, speed: 0.055, phase: 0.10, wobble: 1.3),
        .init(x: 0.22, size: 14, speed: 0.080, phase: 0.55, wobble: 1.9),
        .init(x: 0.40, size: 34, speed: 0.045, phase: 0.80, wobble: 1.1),
        .init(x: 0.57, size: 12, speed: 0.090, phase: 0.30, wobble: 2.2),
        .init(x: 0.71, size: 22, speed: 0.060, phase: 0.65, wobble: 1.6),
        .init(x: 0.86, size: 30, speed: 0.050, phase: 0.05, wobble: 1.2),
        .init(x: 0.95, size: 13, speed: 0.075, phase: 0.45, wobble: 2.0),
    ]

    var body: some View {
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ForEach(Array(Self.specs.enumerated()), id: \.offset) { _, spec in
                    let cycle = (t * spec.speed + spec.phase).truncatingRemainder(dividingBy: 1)
                    let y = proxy.size.height + spec.size - cycle * (proxy.size.height + spec.size * 2)
                    let x = spec.x * proxy.size.width + sin(t * spec.wobble + spec.phase * 9) * 7
                    ZStack(alignment: .topLeading) {
                        Circle().fill(DesignTokens.Colors.customerHeroBubble)
                        Circle().fill(DesignTokens.Colors.surface)
                            .frame(width: spec.size * 0.26, height: spec.size * 0.26)
                            .offset(x: spec.size * 0.2, y: spec.size * 0.18)
                    }
                    .frame(width: spec.size, height: spec.size)
                    .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The Beckon pup: peeks over the hero edge, blinks, and flings its ears when the button is pressed.
struct BeckonPup: View {
    let time: TimeInterval
    let excited: Bool

    var body: some View {
        let bob = sin(time * 2.1) * 2.4
        let blinking = time.truncatingRemainder(dividingBy: 3.7) > 3.52
        let tilt = sin(time * 0.8) * 2.5 + (excited ? -7 : 0)
        let earSwing = sin(time * 3.0) * 3
        let earRest: Double = excited ? 38 : 16
        let hop: CGFloat = excited ? -5 : 0

        ZStack {
            earShape.rotationEffect(.degrees(earRest + earSwing), anchor: .top).position(x: 25, y: 39 + bob * 0.5)
            earShape.rotationEffect(.degrees(-(earRest - earSwing)), anchor: .top).position(x: 95, y: 39 + bob * 0.5)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(DesignTokens.Colors.surface)
                .frame(width: 88, height: 68)
                .position(x: 60, y: 38 + bob)

            Circle().fill(DesignTokens.Colors.customerHeroBubble).frame(width: 28, height: 28)
                .position(x: 40, y: 36 + bob)

            eye.position(x: 41, y: 36 + bob).scaleEffect(y: blinking ? 0.1 : 1)
            eye.position(x: 79, y: 36 + bob).scaleEffect(y: blinking ? 0.1 : 1)

            Circle().fill(DesignTokens.Colors.groomerFill).frame(width: 13, height: 13).position(x: 30, y: 50 + bob)
            Circle().fill(DesignTokens.Colors.groomerFill).frame(width: 13, height: 13).position(x: 90, y: 50 + bob)

            if excited {
                Capsule().fill(DesignTokens.Colors.groomerFill).frame(width: 11, height: 15).position(x: 60, y: 62 + bob)
            }
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(DesignTokens.Colors.customerInk).frame(width: 16, height: 11).position(x: 60, y: 46 + bob)
            Path { path in
                path.move(to: CGPoint(x: 60, y: 51))
                path.addLine(to: CGPoint(x: 60, y: 55))
                path.addQuadCurve(to: CGPoint(x: 51, y: 56), control: CGPoint(x: 56, y: 61))
                path.move(to: CGPoint(x: 60, y: 55))
                path.addQuadCurve(to: CGPoint(x: 69, y: 56), control: CGPoint(x: 64, y: 61))
            }
            .offset(y: bob)
            .stroke(DesignTokens.Colors.customerInk, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

            paw.position(x: 37, y: 80 + hop)
            paw.position(x: 83, y: 80 + hop)
        }
        .frame(width: 120, height: 92)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .animation(.spring(response: 0.28, dampingFraction: 0.5), value: excited)
    }

    private var earShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(DesignTokens.Colors.customerDeep)
            .frame(width: 28, height: 46)
    }

    private var eye: some View {
        ZStack(alignment: .topTrailing) {
            Ellipse().fill(DesignTokens.Colors.customerInk).frame(width: 11, height: 14)
            Circle().fill(DesignTokens.Colors.surface).frame(width: 4, height: 4).offset(x: -1.5, y: 2)
        }
        .frame(width: 11, height: 14)
        .scaleEffect(excited ? 1.15 : 1)
    }

    private var paw: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignTokens.Colors.surface)
                .frame(width: 34, height: 21)
            HStack(spacing: 6) {
                Capsule().fill(DesignTokens.Colors.borderSoft).frame(width: 2.5, height: 8)
                Capsule().fill(DesignTokens.Colors.borderSoft).frame(width: 2.5, height: 8)
            }
            .offset(y: 3)
        }
    }
}

/// Four-point sparkle. Decorative; amber is allowed here because it never encodes state.
struct BeckonSparkle: View {
    let size: CGFloat
    let active: Bool
    let delay: Double

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .black)) // decorative glyph, fixed by design
            .foregroundStyle(DesignTokens.Colors.ratingStar)
            .scaleEffect(active ? 1.25 : 0.55)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(delay), value: active)
            .accessibilityHidden(true)
    }
}

private struct BeckonHopValues {
    var lift = 0.0
    var squash = 1.0
}

/// Pet portrait tile: mint tint, a halo, the species glyph hopping on its own beat. A photo replaces the artwork.
struct BeckonPortrait: View {
    let data: Data?
    let symbol: String
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var halo: Color {
        index.isMultiple(of: 2) ? DesignTokens.Colors.customerFill : DesignTokens.Colors.customerHeroEnd
    }

    var body: some View {
        BeckonModuleImage(data: data) {
            ZStack {
                DesignTokens.Colors.customerTint
                Circle().fill(halo).frame(width: 74, height: 74).offset(y: 4)
                glyph
                sparkle(size: 13, x: -52, y: -30)
                sparkle(size: 9, x: 54, y: -20)
                sparkle(size: 11, x: 46, y: 34)
            }
        }
        .frame(height: 112)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        let base = Image(systemName: symbol)
            .font(.system(size: 40, weight: .bold, design: .rounded)) // decorative glyph, fixed by design
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .offset(y: 3)
        if reduceMotion {
            base
        } else {
            let pause = 2.2 + Double(index) * 0.9
            base.keyframeAnimator(initialValue: BeckonHopValues(), repeating: true) { content, value in
                content
                    .scaleEffect(x: value.squash == 1 ? 1 : 2 - value.squash, y: value.squash, anchor: .bottom)
                    .offset(y: value.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    LinearKeyframe(0, duration: pause)
                    SpringKeyframe(-13, duration: 0.24, spring: .snappy)
                    SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                }
                KeyframeTrack(\.squash) {
                    LinearKeyframe(1, duration: pause - 0.16)
                    CubicKeyframe(0.86, duration: 0.16)
                    CubicKeyframe(1.1, duration: 0.2)
                    SpringKeyframe(1, duration: 0.54, spring: .bouncy)
                }
            }
        }
    }

    private func sparkle(size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .black)) // decorative glyph, fixed by design
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .offset(x: x, y: y)
    }
}
