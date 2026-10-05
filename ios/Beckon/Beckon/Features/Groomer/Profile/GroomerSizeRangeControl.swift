import SwiftUI

struct GroomerSizeRangeLegend: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let titles: [String]

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(titles.joined(separator: ", "))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 0) {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct GroomerSizeRangeSlider: View {
    @Binding var lowerIndex: Int
    @Binding var upperIndex: Int
    let optionCount: Int
    let rangeTitle: String
    var accessibilityIdentifier = "groomer.fit-signals.size-range-slider"

    @State private var lowerDragStartIndex: Int?
    @State private var upperDragStartIndex: Int?

    private let thumbSize: CGFloat = 30
    private let hitSize: CGFloat = 48
    private let trackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width - thumbSize, 1)
            let lowerCenterX = centerX(for: lowerIndex, trackWidth: trackWidth)
            let upperCenterX = centerX(for: upperIndex, trackWidth: trackWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignTokens.Colors.borderSoft)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: thumbSize / 2)

                Capsule()
                    .fill(DesignTokens.Colors.groomerAccent)
                    .frame(
                        width: max(upperCenterX - lowerCenterX, trackHeight),
                        height: trackHeight
                    )
                    .offset(x: lowerCenterX)

                ForEach(0..<optionCount, id: \.self) { index in
                    Circle()
                        .fill(
                            index >= lowerIndex && index <= upperIndex
                                ? DesignTokens.Colors.groomerAccentDark
                                : DesignTokens.Colors.textTertiary.opacity(0.45)
                        )
                        .frame(width: 6, height: 6)
                        .offset(
                            x: centerX(for: index, trackWidth: trackWidth) - 3,
                            y: 0
                        )
                        .accessibilityHidden(true)
                }

                GroomerSizeRangeThumb()
                    .frame(width: hitSize, height: hitSize)
                    .position(x: lowerCenterX, y: hitSize / 2)
                    .gesture(lowerThumbDrag(trackWidth: trackWidth))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Minimum size")
                    .accessibilityValue(rangeTitle)
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: lowerIndex = min(lowerIndex + 1, upperIndex)
                        case .decrement: lowerIndex = max(lowerIndex - 1, 0)
                        @unknown default: break
                        }
                    }

                GroomerSizeRangeThumb()
                    .frame(width: hitSize, height: hitSize)
                    .position(x: upperCenterX, y: hitSize / 2)
                    .gesture(upperThumbDrag(trackWidth: trackWidth))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Maximum size")
                    .accessibilityValue(rangeTitle)
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: upperIndex = min(upperIndex + 1, optionCount - 1)
                        case .decrement: upperIndex = max(upperIndex - 1, lowerIndex)
                        @unknown default: break
                        }
                    }
            }
        }
        .frame(height: hitSize)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func centerX(for index: Int, trackWidth: CGFloat) -> CGFloat {
        let maximumIndex = max(optionCount - 1, 1)
        let clampedIndex = min(max(index, 0), maximumIndex)
        return thumbSize / 2 + CGFloat(clampedIndex) / CGFloat(maximumIndex) * trackWidth
    }

    private func index(for centerX: CGFloat, trackWidth: CGFloat) -> Int {
        let maximumIndex = max(optionCount - 1, 1)
        let normalized = (centerX - thumbSize / 2) / trackWidth
        return min(max(Int((normalized * CGFloat(maximumIndex)).rounded()), 0), maximumIndex)
    }

    private func lowerThumbDrag(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let startIndex = lowerDragStartIndex ?? lowerIndex
                lowerDragStartIndex = startIndex
                let startX = centerX(for: startIndex, trackWidth: trackWidth)
                let proposedIndex = index(
                    for: startX + value.translation.width,
                    trackWidth: trackWidth
                )
                lowerIndex = min(proposedIndex, upperIndex)
            }
            .onEnded { _ in
                lowerDragStartIndex = nil
            }
    }

    private func upperThumbDrag(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let startIndex = upperDragStartIndex ?? upperIndex
                upperDragStartIndex = startIndex
                let startX = centerX(for: startIndex, trackWidth: trackWidth)
                let proposedIndex = index(
                    for: startX + value.translation.width,
                    trackWidth: trackWidth
                )
                upperIndex = max(proposedIndex, lowerIndex)
            }
            .onEnded { _ in
                upperDragStartIndex = nil
            }
    }
}

private struct GroomerSizeRangeThumb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.surface)
                .frame(width: 30, height: 30)
                .beckonShadow(DesignTokens.Shadows.smallCard)

            Circle()
                .stroke(DesignTokens.Colors.groomerAccent, lineWidth: 3)
                .frame(width: 30, height: 30)

            Capsule()
                .fill(DesignTokens.Colors.groomerAccentDark)
                .frame(width: 4, height: 14)
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }
}
