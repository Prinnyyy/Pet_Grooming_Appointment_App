import SwiftUI

/// Brand artwork has its own material and elevation; it is not an actionable card.
struct BeckonBrandBubble: View {
    let isMotionEnabled: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isMotionEnabled)) { context in
            let time = isMotionEnabled ? context.date.timeIntervalSinceReferenceDate : 0
            let lift = isMotionEnabled
                ? sin(time * .pi / 2) * 4
                : 0

            ZStack(alignment: .top) {
                Ellipse()
                    .fill(DesignTokens.BrandIllustration.groundShadow)
                    .frame(width: 92, height: 10)
                    .blur(radius: 5)
                    .scaleEffect(x: 1 + lift / 40, y: 1)
                    .offset(y: 164)

                ZStack {
                    Circle()
                        .fill(DesignTokens.BrandIllustration.body)
                    Circle()
                        .fill(RadialGradient(
                            colors: [DesignTokens.BrandIllustration.highlight, .clear],
                            center: .init(x: 0.28, y: 0.22),
                            startRadius: 0, endRadius: 100
                        ))
                    Text("🐶")
                        .font(.system(size: 62))
                        .offset(y: 3)
                }
                .frame(width: 156, height: 156)
                .offset(y: lift)
            }
            .frame(width: 156, height: 180, alignment: .top)
            .background(alignment: .top) {
                satellites(time: time)
                    .frame(width: 156, height: 156)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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

    private func satellite(size: CGFloat, x: CGFloat, y: CGFloat,
                           time: TimeInterval, period: Double, phase: Double) -> some View {
        let drift = isMotionEnabled ? sin(time * 2 * .pi / period + phase) : 0
        return Circle()
            .fill(DesignTokens.BrandIllustration.satellite)
            .frame(width: size, height: size)
            .offset(x: x + drift * 3, y: y + drift * 7)
    }
}
