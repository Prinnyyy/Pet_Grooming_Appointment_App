import SwiftUI


enum BeckonJourneyNodeState { case done, current, upcoming }


struct BeckonJourneyStop: Equatable {
    let title: String
    let systemImage: String

    static let posted = BeckonJourneyStop(title: "Posted", systemImage: "paperplane.fill")
    static let offers = BeckonJourneyStop(title: "Offers", systemImage: "tag.fill")
    static let booked = BeckonJourneyStop(title: "Booked", systemImage: "calendar")
    /// Everything after the service is one stop: the groomer finishes, then the owner leaves a review. It is done only once the review
    /// is in, and a reviewed grooming has left the card row for History, so on a card it is always ahead or in progress.
    static let finished = BeckonJourneyStop(title: "Finished", systemImage: "sparkles")

    /// A request's three moments (the request detail page), and the whole grooming: the same path goes on after Booked, so a
    /// request that gets booked keeps its card and lights up more nodes.
    static let requestPath = [posted, offers, booked]
    static let groomingPath = [posted, offers, booked, finished]
}


/// A path of stops (three, or four for a whole grooming). The stop in progress pulses and carries a speech bubble that bounces.
/// Purely visual: the owning card exposes one combined VoiceOver label, so this is hidden from accessibility.
/// Stage is never conveyed by color or motion alone: every node has a glyph and a label (A11Y-R3, R9).
struct BeckonJourney: View {
    /// The bubble: what it says and which stop it sits over.
    struct Bubble: Equatable {
        let kind: BeckonJourneyCallout.Kind
        let column: Int
    }

    let stops: [BeckonJourneyStop]
    /// Stops behind: the stop at this index is the one in progress, and `stops.count` means all are done.
    let current: Int
    /// How full the line after each stop is (one fewer than the stops).
    let fills: [Double]
    var bubble: Bubble?
    /// The stop that throws sparkles (a booking that has just been made).
    var celebratingColumn: Int?
    /// A request's own path, 1 = posted, 2 = offers, 3 = booked (the request detail page).
    init(stage: Int, offerCount: Int?) {
        let stage = min(max(stage, 1), 3)
        stops = BeckonJourneyStop.requestPath
        current = stage >= 3 ? 3 : 1
        fills = stage >= 3 ? [1, 1] : (stage == 2 ? [1, 0.35] : [0.55, 0])
        switch stage {
        case 1: bubble = Bubble(kind: .waiting, column: 1)
        case 2: bubble = Bubble(kind: .offers(offerCount), column: 1)
        default: bubble = Bubble(kind: .booked, column: 2)
        }
        celebratingColumn = stage >= 3 ? 2 : nil
    }

    init(stops: [BeckonJourneyStop], current: Int, fills: [Double], bubble: Bubble? = nil, celebratingColumn: Int? = nil) {
        self.stops = stops
        self.current = current
        self.fills = fills
        self.bubble = bubble
        self.celebratingColumn = celebratingColumn
    }

    /// Four stops share a card's width, so they are a little smaller than the three of the request page.
    private var nodeSize: CGFloat {
        stops.count > 3 ? DesignTokens.Metrics.journeyNodeMedium : DesignTokens.Metrics.journeyNode
    }

    private func state(of column: Int) -> BeckonJourneyNodeState {
        column < current ? .done : (column == current ? .current : .upcoming)
    }

    /// How much of the line half-way to the next stop (`side` 0) or half-way from the one before (`side` 1) is filled: each stop
    /// draws the half of the line on either side of itself and covers the middle.
    private func halfFill(column: Int, leading: Bool) -> Double {
        let segment = leading ? column - 1 : column
        guard segment >= 0, segment < fills.count else { return 0 }
        let fill = fills[segment]
        return leading ? max(fill * 2 - 1, 0) : min(fill * 2, 1)
    }

    /// Four stops share the width of a card, so the bubble over an end stop slides toward the middle to stay inside it.
    private func bubbleShift(column: Int, kind: BeckonJourneyCallout.Kind) -> CGFloat {
        guard stops.count > 3 else { return 0 }
        if column == 0 { return -26 }
        guard column == stops.count - 1 else { return 0 }
        // The longest bubble needs more room than the others; a short one slid that far would leave its tail beyond its edge.
        return kind == .confirmOutcome ? 40 : 26
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<stops.count, id: \.self) { column in
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ZStack(alignment: .top) {
                        HStack(spacing: 0) {
                            BeckonJourneyConnector(fill: halfFill(column: column, leading: true), isDrawn: column > 0)
                            BeckonJourneyConnector(fill: halfFill(column: column, leading: false), isDrawn: column < stops.count - 1)
                        }
                        .padding(.top, (nodeSize - 9) / 2)
                        BeckonJourneyNode(state: state(of: column), systemImage: stops[column].systemImage,
                            celebrates: celebratingColumn == column, size: nodeSize)
                            .overlay(alignment: .top) {
                                if let bubble, bubble.column == column {
                                    // The tail stays over the stop whatever the bubble does.
                                    BeckonJourneyCallout(kind: bubble.kind, shift: bubbleShift(column: column, kind: bubble.kind))
                                        .offset(y: -48).fixedSize()
                                }
                            }
                    }
                    Text(stops[column].title)
                        .font(state(of: column) == .upcoming
                            ? DesignTokens.Typography.Expressive.labelMuted : DesignTokens.Typography.Expressive.label)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(state(of: column) == .upcoming
                            ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // Headroom for the callout above the current node.
        .padding(.top, 48)
        // Glyph-like labels whose full text lives in the card's combined label may be capped (spec section 8); four of them side by
        // side are capped one step lower so they stay clear of each other.
        .dynamicTypeSize(...(stops.count > 3 ? DynamicTypeSize.xLarge : DynamicTypeSize.xxxLarge))
        .beckonAnimation(DesignTokens.Motion.settle, value: fills.map { Int($0 * 100) } + [current])
        .accessibilityHidden(true)
    }
}


/// The half of the line on one side of a stop: grey, with the mint part growing from the left.
private struct BeckonJourneyConnector: View {
    let fill: Double
    let isDrawn: Bool

    var body: some View {
        // The line is 9 points thick; the journey puts it level with the middle of the stops.
        Group {
            if isDrawn {
                ZStack(alignment: .leading) {
                    Rectangle().fill(DesignTokens.Colors.borderSoft)
                    Rectangle().fill(DesignTokens.Colors.customerFill)
                        .scaleEffect(x: max(fill, 0.0001), y: 1, anchor: .leading)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 9)
    }
}


private struct BeckonJourneyNode: View {
    let state: BeckonJourneyNodeState
    let systemImage: String
    let celebrates: Bool
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

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
                .font(.system(size: size * 0.42, weight: .black, design: .rounded)) // decorative glyph, fixed by design
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
    enum Kind: Equatable { case waiting, offers(Int?), booked, countdown(String), confirmOutcome, review }
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
        case .countdown(let text):
            Label(text, systemImage: "clock.fill")
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(DesignTokens.Colors.customerInk)
        case .confirmOutcome:
            Label("Confirm outcome", systemImage: "checkmark.circle.fill")
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(DesignTokens.Colors.statusWarningText)
        case .review:
            Label("Rate it!", systemImage: "star.fill")
                .font(DesignTokens.Typography.Expressive.caption)
                .foregroundStyle(DesignTokens.Colors.statusWarningText)
        }
    }

    private var face: Color {
        switch kind {
        case .waiting: DesignTokens.Colors.surface
        case .offers, .confirmOutcome, .review: DesignTokens.Colors.statusWarningFill
        case .booked: DesignTokens.Colors.statusSuccessFill
        case .countdown: DesignTokens.Colors.customerTint
        }
    }

    private var edge: Color {
        switch kind {
        case .waiting: DesignTokens.Colors.border
        case .offers, .confirmOutcome, .review: DesignTokens.Colors.statusWarningBorder
        case .booked: DesignTokens.Colors.statusSuccessBorder
        case .countdown: DesignTokens.Colors.customerFill
        }
    }
}
