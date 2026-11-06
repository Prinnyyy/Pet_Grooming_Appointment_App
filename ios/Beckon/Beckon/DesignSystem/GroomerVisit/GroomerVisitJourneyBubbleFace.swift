import SwiftUI

/// The groomerVisit journey's capsule and tail share one bounce. Moving the capsule never moves its pointer.
struct GroomerVisitJourneyBubbleFace<Content: View>: View {
    let face: Color
    let edge: Color
    let shift: CGFloat
    var leadingRoom: CGFloat? = nil
    var trailingRoom: CGFloat? = nil
    var horizontalInset: CGFloat = DesignTokens.Spacing.md
    var edgeWidth: CGFloat = DesignTokens.Ledge.edgeWidth
    @ViewBuilder var content: (TimeInterval) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let shift = self.shift
        let leadingRoom = self.leadingRoom
        let trailingRoom = self.trailingRoom
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            let bounce = abs(sin(t * 3.4)) * 5
            VStack(spacing: 0) {
                content(t)
                    .padding(.horizontal, horizontalInset)
                    .frame(minHeight: 32)
                    .background(face, in: Capsule())
                    .overlay(Capsule().strokeBorder(edge, lineWidth: edgeWidth))
                    .visualEffect { label, geometry in
                        let overflow = trailingRoom.map { max(0, geometry.size.width / 2 - $0) } ?? 0
                        let maxLeftShift = leadingRoom.map { $0 - geometry.size.width / 2 } ?? CGFloat.infinity
                        return label.offset(x: -min(max(shift, overflow), maxLeftShift))
                    }
                ZStack {
                    BeckonBubbleTail().fill(face)
                    BeckonBubbleTail().stroke(edge, style: StrokeStyle(lineWidth: edgeWidth,
                        lineCap: .round, lineJoin: .round))
                }
                .frame(width: 16, height: 8)
                .offset(y: -1)
            }
            .offset(y: -bounce)
        }
    }
}

/// Open triangle: the fill covers the bubble's bottom edge, the stroke only draws the two outer sides.
private nonisolated struct BeckonBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Three dots that jump one after the other: the bubble of something that is waiting for somebody else.
struct GroomerVisitBouncingDots: View {
    let time: TimeInterval
    let color: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(0..<3, id: \.self) { dot in
                Circle().fill(color)
                    .frame(width: 6, height: 6)
                    .offset(y: -3.5 * max(0, sin(time * 6 - Double(dot) * 0.9)))
            }
        }
    }
}
