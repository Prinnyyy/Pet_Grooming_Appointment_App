import SwiftUI

enum BeckonJourneyNodeState { case done, current, upcoming }

/// Posted → Offers → Booked as a path. The current node pulses and carries a speech bubble.
/// Purely visual: the owning card exposes one combined VoiceOver label, so this is hidden from accessibility.
/// Stage is never conveyed by color or motion alone: every node has a glyph and a label (A11Y-R3, R9).
struct BeckonJourney: View {
    /// 1 = posted, 2 = offers, 3 = booked.
    let stage: Int
    let offerCount: Int?

    private let labels = ["Posted", "Offers", "Booked"]
    private let icons = ["paperplane.fill", "tag.fill", "calendar"]

    private var states: [BeckonJourneyNodeState] {
        stage >= 3 ? [.done, .done, .done] : [.done, .current, .upcoming]
    }

    private var fills: [Double] {
        switch stage {
        case 3...: [1, 1]
        case 2: [1, 0.35]
        default: [0.55, 0]
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                BeckonJourneyConnector(fill: fills[0])
                BeckonJourneyConnector(fill: fills[1])
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<3, id: \.self) { column in
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        BeckonJourneyNode(state: states[column], systemImage: icons[column],
                            celebrates: stage >= 3 && column == 2)
                            .overlay(alignment: .top) {
                                if let callout = callout(column: column) {
                                    callout.offset(y: -48).fixedSize()
                                }
                            }
                        Text(labels[column])
                            .font(states[column] == .upcoming
                                ? DesignTokens.Typography.Expressive.labelMuted : DesignTokens.Typography.Expressive.label)
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(states[column] == .upcoming
                                ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary)
                    }
                    .frame(width: 64)
                    if column < 2 { Spacer(minLength: 0) }
                }
            }
        }
        // Headroom for the callout above the current node.
        .padding(.top, 48)
        // Glyph-like labels whose full text lives in the card's combined label may be capped (spec section 8).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .beckonAnimation(DesignTokens.Motion.settle, value: stage)
        .accessibilityHidden(true)
    }

    private func callout(column: Int) -> BeckonJourneyCallout? {
        switch (min(stage, 3), column) {
        case (1, 1): BeckonJourneyCallout(kind: .waiting, shift: 0)
        case (2, 1): BeckonJourneyCallout(kind: .offers(offerCount), shift: 0)
        case (3, 2): BeckonJourneyCallout(kind: .booked, shift: 26)
        default: nil
        }
    }
}

private struct BeckonJourneyConnector: View {
    let fill: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(DesignTokens.Colors.borderSoft)
            Capsule().fill(DesignTokens.Colors.customerFill)
                .scaleEffect(x: max(fill, 0.0001), y: 1, anchor: .leading)
        }
        .frame(height: 9)
    }
}

private struct BeckonJourneyNode: View {
    let state: BeckonJourneyNodeState
    let systemImage: String
    let celebrates: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let size = DesignTokens.Metrics.journeyNode

    var body: some View {
        ZStack {
            if state == .current && !reduceMotion {
                Circle()
                    .strokeBorder(DesignTokens.Colors.customerFill, lineWidth: 4)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.75 : 1)
                    .opacity(pulse ? 0 : 0.9)
            }
            Image(systemName: state == .done ? "checkmark" : systemImage)
                .font(.system(size: 17, weight: .black, design: .rounded)) // decorative glyph, fixed by design
                .foregroundStyle(foreground)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background(face, in: Circle())
                .overlay { if state == .current { Circle().strokeBorder(DesignTokens.Colors.customerDeep, lineWidth: 3) } }
                .background(Circle().fill(lip).offset(y: DesignTokens.Ledge.control))
                .scaleEffect(state == .current ? 1.08 : 1)

            if celebrates && !reduceMotion {
                BeckonSparkle(size: 14, active: pulse, delay: 0.0).offset(x: -30, y: -20)
                BeckonSparkle(size: 11, active: pulse, delay: 0.25).offset(x: 32, y: -16)
                BeckonSparkle(size: 9, active: pulse, delay: 0.5).offset(x: 26, y: 24)
            }
        }
        .frame(width: size, height: size + DesignTokens.Ledge.control)
        .beckonAnimation(DesignTokens.Motion.bounce, value: state)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private var face: Color {
        switch state {
        case .done: DesignTokens.Colors.customerFill
        case .current: DesignTokens.Colors.surface
        case .upcoming: DesignTokens.Colors.placeholderFill
        }
    }

    private var lip: Color {
        switch state {
        case .done, .current: DesignTokens.Colors.customerDeep
        case .upcoming: DesignTokens.Colors.border
        }
    }

    private var foreground: Color {
        switch state {
        case .done: DesignTokens.Colors.customerInk
        case .current: DesignTokens.Colors.customerDeep
        case .upcoming: DesignTokens.Colors.textTertiary
        }
    }
}

/// Open triangle: the fill covers the bubble's bottom edge, the stroke only draws the two outer sides.
private struct BeckonBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Speech bubble over the current node. Status colors only (warning = needs you, success = done); always icon + text.
struct BeckonJourneyCallout: View {
    enum Kind { case waiting, offers(Int?), booked }
    let kind: Kind
    /// Slides the bubble sideways while the tail stays over the node.
    let shift: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused
        TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            let bounce = abs(sin(t * 3.4)) * 5
            VStack(spacing: 0) {
                content(time: t)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .frame(minHeight: 32)
                    .background(face, in: Capsule())
                    .overlay(Capsule().strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth))
                    .offset(x: -shift)
                ZStack {
                    BeckonBubbleTail().fill(face)
                    BeckonBubbleTail().stroke(edge, style: StrokeStyle(lineWidth: DesignTokens.Ledge.edgeWidth,
                        lineCap: .round, lineJoin: .round))
                }
                .frame(width: 16, height: 8)
                .offset(y: -1)
            }
            .offset(y: -bounce)
        }
    }

    @ViewBuilder
    private func content(time: TimeInterval) -> some View {
        switch kind {
        case .waiting:
            HStack(spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(0..<3, id: \.self) { dot in
                        Circle().fill(DesignTokens.Colors.customerDeep)
                            .frame(width: 6, height: 6)
                            .offset(y: -3.5 * max(0, sin(time * 6 - Double(dot) * 0.9)))
                    }
                }
                Text("Finding groomers")
                    .font(DesignTokens.Typography.Expressive.caption)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
            }
        case .offers(let count):
            Label(count.map { "\($0) offer\($0 == 1 ? "" : "s")!" } ?? "Offers ready!", systemImage: "tag.fill")
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(DesignTokens.Colors.statusWarningText)
        case .booked:
            Label("Booked!", systemImage: "checkmark.seal.fill")
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(DesignTokens.Colors.statusSuccessText)
        }
    }

    private var face: Color {
        switch kind {
        case .waiting: DesignTokens.Colors.surface
        case .offers: DesignTokens.Colors.statusWarningFill
        case .booked: DesignTokens.Colors.statusSuccessFill
        }
    }

    private var edge: Color {
        switch kind {
        case .waiting: DesignTokens.Colors.border
        case .offers: DesignTokens.Colors.statusWarningBorder
        case .booked: DesignTokens.Colors.statusSuccessBorder
        }
    }
}
