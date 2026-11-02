import SwiftUI

struct GroomerSizeRangeLegend: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let titles: [String]

    var body: some View {
        if typeSize.isAccessibilitySize {
            Text(titles.joined(separator: ", ")).designSupportingText()
        } else {
            HStack(spacing: 0) {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}


/// A slider with two thumbs for a range of sizes (the services' and the fit signals'): drag either, or adjust with VoiceOver.
struct GroomerSizeRangeSlider: View {
    @Binding var lowerIndex: Int
    @Binding var upperIndex: Int
    let optionCount: Int
    let rangeTitle: String
    var accessibilityIdentifier = "groomer.fit-signals.size-range-slider"
    @State private var lowerDragStart: Int?
    @State private var upperDragStart: Int?

    private let thumb = DesignTokens.Metrics.rangeThumb
    private let hit = DesignTokens.Metrics.rangeHit
    private let track = DesignTokens.Metrics.rangeTrack

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - thumb, 1)
            let lowerX = centerX(lowerIndex, width)
            let upperX = centerX(upperIndex, width)
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.Colors.border).frame(width: width, height: track).offset(x: thumb / 2)
                Capsule().fill(DesignTokens.Colors.customerFill).frame(width: max(upperX - lowerX, track), height: track)
                    .offset(x: lowerX)
                ForEach(0..<optionCount, id: \.self) { index in
                    Circle()
                        .fill(index >= lowerIndex && index <= upperIndex ? DesignTokens.Colors.customerDeep
                            : DesignTokens.Colors.textTertiary)
                        .frame(width: track, height: track)
                        .offset(x: centerX(index, width) - track / 2)
                        .accessibilityHidden(true)
                }
                handle(at: lowerX, label: "Minimum size", drag: lowerDrag(width)) {
                    switch $0 {
                    case .increment: lowerIndex = min(lowerIndex + 1, upperIndex)
                    case .decrement: lowerIndex = max(lowerIndex - 1, 0)
                    @unknown default: break
                    }
                }
                handle(at: upperX, label: "Maximum size", drag: upperDrag(width)) {
                    switch $0 {
                    case .increment: upperIndex = min(upperIndex + 1, optionCount - 1)
                    case .decrement: upperIndex = max(upperIndex - 1, lowerIndex)
                    @unknown default: break
                    }
                }
            }
        }
        .frame(height: hit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func handle(at x: CGFloat, label: String, drag: some Gesture,
                        adjust: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        ZStack {
            Circle().fill(DesignTokens.Colors.surface).frame(width: thumb, height: thumb)
            Circle().strokeBorder(DesignTokens.Colors.customerDeep, lineWidth: DesignTokens.Ledge.edgeWidth + 1)
                .frame(width: thumb, height: thumb)
        }
        .frame(width: hit, height: hit)
        .contentShape(Circle())
        .position(x: x, y: hit / 2)
        .gesture(drag)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(rangeTitle)
        .accessibilityAdjustableAction(adjust)
    }

    private func centerX(_ index: Int, _ width: CGFloat) -> CGFloat {
        let last = max(optionCount - 1, 1)
        return thumb / 2 + CGFloat(min(max(index, 0), last)) / CGFloat(last) * width
    }

    private func index(at x: CGFloat, _ width: CGFloat) -> Int {
        let last = max(optionCount - 1, 1)
        return min(max(Int(((x - thumb / 2) / width * CGFloat(last)).rounded()), 0), last)
    }

    private func lowerDrag(_ width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = lowerDragStart ?? lowerIndex
                lowerDragStart = start
                lowerIndex = min(index(at: centerX(start, width) + value.translation.width, width), upperIndex)
            }
            .onEnded { _ in lowerDragStart = nil }
    }

    private func upperDrag(_ width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = upperDragStart ?? upperIndex
                upperDragStart = start
                upperIndex = max(index(at: centerX(start, width) + value.translation.width, width), lowerIndex)
            }
            .onEnded { _ in upperDragStart = nil }
    }
}
