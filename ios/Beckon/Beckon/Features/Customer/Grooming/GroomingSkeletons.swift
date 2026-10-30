// What the Grooming screens look like while they wait for their data (design). Each skeleton keeps the real container (the ledge
// card, its fixed height, its padding, the real stage names of the path) and replaces only what comes from data with bars, so the
// placeholder and the page it stands for are the same size and nothing moves when the data arrives.
import SwiftUI


/// The four-stop path as bars: a disc for each stop on one line, a short bar under it for the stage name. The same room as the path
/// (the headroom of the bubble, the size of the nodes), so the real path takes its place.
struct GroomingPathSkeleton: View {
    private let stops = BeckonJourneyStop.groomingPath.count
    private var nodeSize: CGFloat { DesignTokens.Metrics.journeyNodeMedium }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<stops, id: \.self) { column in
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ZStack(alignment: .top) {
                        HStack(spacing: 0) {
                            connector(isDrawn: column > 0)
                            connector(isDrawn: column < stops - 1)
                        }
                        .padding(.top, (nodeSize - DesignTokens.Metrics.groomingPathConnector) / 2)
                        DesignSkeletonDisc()
                            .frame(width: nodeSize, height: nodeSize)
                    }
                    DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.label)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, DesignTokens.Metrics.groomingPathHeadroom)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func connector(isDrawn: Bool) -> some View {
        Group {
            if isDrawn { Rectangle().fill(DesignTokens.Colors.skeleton) } else { Color.clear }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.Metrics.groomingPathConnector)
        .accessibilityHidden(true)
    }
}


/// The History row as bars (a disc and a line); History is a page of its own, so it waits with the rest.
struct GroomingHistoryRowSkeleton: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
            DesignSkeletonLine(width: 0.3, font: DesignTokens.Typography.Expressive.emphasis)
        }
        .designSkeleton(label: nil)
        .padding(DesignTokens.Spacing.md)
        .beckonLedge(.card)
    }
}


/// The card of one grooming, waiting: the avatar and two lines, two facts, the path as bars, the button.
struct GroomingCardSkeleton: View {
    var style: GroomingCard.Style = .full
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var scaledFullHeight = DesignTokens.Metrics.groomingCardHeight
    @ScaledMetric(relativeTo: .body) private var scaledGlanceHeight = DesignTokens.Metrics.groomingGlanceCardHeight

    /// The card's own rule (`GroomingCard.height`): the same height, so the real card takes the place exactly.
    private var height: CGFloat? {
        guard !typeSize.isAccessibilitySize else { return nil }
        return style == .full
            ? max(scaledFullHeight, DesignTokens.Metrics.groomingCardHeight)
            : max(scaledGlanceHeight, DesignTokens.Metrics.groomingGlanceCardHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                identity
                if style == .full {
                    facts
                    Spacer(minLength: 0)
                }
                GroomingPathSkeleton()
                    .padding(.top, style == .glance ? DesignTokens.Spacing.sm : DesignTokens.Spacing.none)
                if style == .glance { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if style == .full {
                Spacer(minLength: DesignTokens.Spacing.xs)
                DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                    .frame(height: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                HStack(spacing: DesignTokens.Spacing.xl) {
                    DesignSkeletonLine(width: 0.7)
                    DesignSkeletonLine(width: 0.7)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
        }
        .designSkeleton(label: "Loading your grooming")
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .beckonLedge(.card)
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.groomingPetAvatar, height: DesignTokens.Metrics.groomingPetAvatar)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.62, font: DesignTokens.Typography.Expressive.headline)
                DesignSkeletonLine(width: 0.42)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            DesignSkeletonLine(width: 0.5)
            DesignSkeletonLine(width: 0.68)
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }
}


/// The Grooming detail while the grooming is being found: the hero (who and when, the path as bars) and two cards.
struct GroomingDetailSkeleton: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    DesignSkeletonDisc()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.headline)
                        DesignSkeletonLine(width: 0.4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroomingPathSkeleton()
            }
            .designSkeleton(label: "Loading your grooming")
            .designCardBody()

            section(lines: [0.8, 0.55])
            section(lines: [0.7, 0.6, 0.45])
        }
    }

    /// A heading and a card of lines: whatever the stage turns out to need under the hero takes this place.
    private func section(lines: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            DesignSkeletonLine(width: 0.34, font: DesignTokens.Typography.Expressive.emphasis)
                .designSkeleton(label: nil)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, width in
                    DesignSkeletonLine(width: width)
                }
            }
            .designSkeleton(label: nil)
            .designCardBody()
        }
    }
}


/// The slot of "needs you" under the hero while a booking's service and time-change records are still being read: a slim card, so
/// a card that turns out to be needed takes this place instead of pushing the page down, and one that is not needed folds away.
struct GroomingNeedsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.emphasis)
            DesignSkeletonLine(width: 0.75)
        }
        .designSkeleton(label: "Checking this appointment")
        .designCardBody()
    }
}
