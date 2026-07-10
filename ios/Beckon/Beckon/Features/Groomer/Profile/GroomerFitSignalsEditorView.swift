import SwiftUI

struct GroomerFitSignalsEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        let presentation = GroomerFitSignalsWorkspacePresentation(
            selectedCoreFitClaimCount: store.selectedCoreFitClaimCount,
            maximumActiveClaims: GroomerFitClaim.maximumActiveClaims,
            isSaving: store.isSaving,
            isBusy: store.isBusy
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                GroomerFitSignalsSelectionBalanceSection(
                    store: store,
                    presentation: presentation
                )

                ForEach(Self.visibleGroups) { group in
                    GroomerFitSignalGroupSection(
                        group: group,
                        signals: signals(for: group),
                        store: store
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .accessibilityIdentifier("groomer.fit-signals.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Fit Signals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            store.ensureSizeBandFitClaimRange()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GroomerFitSignalsSaveBar(
                store: store,
                presentation: presentation
            )
        }
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerFitClaim.availableSignals.contains { $0.group == group }
        }
    }

    private func signals(for group: PetFitSignal.Group) -> [PetFitSignal] {
        GroomerFitClaim.availableSignals.filter { $0.group == group }
    }
}

private struct GroomerFitSignalsSelectionBalanceSection: View {
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerFitSignalsWorkspacePresentation

    var body: some View {
        GroomerWorkspaceSection(title: "Selection balance") {
            GroomerGroupedSurface {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("Core skills")
                                    .font(DesignTokens.Typography.body.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Text("Coat, handling, and service strengths guide matching.")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(presentation.selectionSummary)
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        ProgressView(
                            value: Double(store.selectedCoreFitClaimCount),
                            total: Double(GroomerFitClaim.maximumActiveClaims)
                        )
                        .tint(DesignTokens.Colors.groomerAccent)
                    }

                    GroomerWorkspaceDivider()

                    GroomerSizeExperienceRangeControl(store: store)
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
    }
}

private struct GroomerSizeExperienceRangeControl: View {
    @Bindable var store: GroomerProfileStore

    private let sizeCodes = CustomerPetSizeCode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Size experience")
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Set the full range you are comfortable grooming.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(store.sizeBandFitClaimRangeTitle)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityIdentifier("groomer.fit-signals.size-range-title")
            }

            GroomerSizeRangeSlider(
                lowerIndex: Binding(
                    get: { store.selectedSizeBandRange.lowerBound },
                    set: { newValue in
                        store.setSizeBandFitClaimRange(
                            lowerIndex: newValue,
                            upperIndex: store.selectedSizeBandRange.upperBound
                        )
                    }
                ),
                upperIndex: Binding(
                    get: { store.selectedSizeBandRange.upperBound },
                    set: { newValue in
                        store.setSizeBandFitClaimRange(
                            lowerIndex: store.selectedSizeBandRange.lowerBound,
                            upperIndex: newValue
                        )
                    }
                ),
                optionCount: sizeCodes.count,
                rangeTitle: store.sizeBandFitClaimRangeTitle
            )

            HStack(spacing: 0) {
                ForEach(sizeCodes) { code in
                    Text(code.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
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
                    .accessibilityLabel("Minimum size")
                    .accessibilityValue(rangeTitle)

                GroomerSizeRangeThumb()
                    .frame(width: hitSize, height: hitSize)
                    .position(x: upperCenterX, y: hitSize / 2)
                    .gesture(upperThumbDrag(trackWidth: trackWidth))
                    .accessibilityLabel("Maximum size")
                    .accessibilityValue(rangeTitle)
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

struct GroomerEvidenceDashboardView: View {
    @Bindable var store: GroomerProfileStore

    private var summaries: [GroomerPetFitEvidenceSummary] {
        store.sortedPetFitEvidenceSummary()
    }

    var body: some View {
        let presentation = GroomerEvidenceWorkspacePresentation(
            signalCount: summaries.count,
            completedBookingCount: summaries.reduce(0) { $0 + $1.completedBookingCount },
            positiveOutcomeCount: summaries.reduce(0) { $0 + $1.positiveReviewOutcomeCount },
            highConfidenceCount: summaries.filter { $0.confidenceTier == .high }.count
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                if presentation.isEmpty {
                    GroomerEvidenceEmptyState()
                        .accessibilityIdentifier("groomer.evidence.empty")
                } else {
                    GroomerEvidenceOverviewSection(presentation: presentation)

                    GroomerWorkspaceSection(title: "Evidence by signal") {
                        GroomerGroupedSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                                    GroomerEvidenceSummaryRow(summary: summary)

                                    if index < summaries.count - 1 {
                                        GroomerWorkspaceDivider(leadingInset: 56)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .accessibilityIdentifier("groomer.evidence.dashboard")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct GroomerEvidenceOverviewSection: View {
    let presentation: GroomerEvidenceWorkspacePresentation

    var body: some View {
        GroomerWorkspaceSection(title: "Evidence overview") {
            GroomerGroupedSurface {
                HStack(spacing: DesignTokens.Spacing.md) {
                    GroomerEvidenceMetric(
                        summary: presentation.completedSummary,
                        label: "Bookings"
                    )
                    GroomerEvidenceMetric(
                        summary: presentation.positiveSummary,
                        label: "Reviews"
                    )
                    GroomerEvidenceMetric(
                        summary: presentation.highConfidenceSummary,
                        label: "Signals"
                    )
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct GroomerEvidenceMetric: View {
    let summary: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(summary)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroomerEvidenceEmptyState: View {
    var body: some View {
        GroomerWorkspaceSection(title: "Evidence overview") {
            GroomerGroupedSurface {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("No evidence yet")
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Completed bookings and structured reviews will appear here over time.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
    }
}

private struct GroomerEvidenceSummaryRow: View {
    let summary: GroomerPetFitEvidenceSummary

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(summary.signal.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)

                Text("\(summary.signal.groupTitle) · \(summary.confidenceTier.title) confidence")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)

                Text("\(summary.completedBookingCount) completed · \(summary.positiveReviewOutcomeCount) positive")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)

                if let updatedAt = summary.evidenceUpdatedAt {
                    Text("Updated \(GroomingRequestDateFormatting.displayString(from: updatedAt))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch summary.signal.group {
        case .coatType:
            "comb"
        case .breedGroup:
            "pawprint.fill"
        case .sizeBand:
            "ruler"
        case .careFlag:
            "heart.fill"
        case .serviceFit:
            "scissors"
        }
    }
}

private struct GroomerFitSignalGroupSection: View {
    let group: PetFitSignal.Group
    let signals: [PetFitSignal]
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusText)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(1)
            }

            GroomerGroupedSurface {
                VStack(spacing: 0) {
                    ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                        GroomerFitSignalRow(
                            signal: signal,
                            isSelected: store.isFitClaimSelected(signal)
                        ) {
                            store.toggleFitClaim(signal)
                        }

                        if index < signals.count - 1 {
                            GroomerWorkspaceDivider(leadingInset: DesignTokens.Spacing.lg)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedCount: Int {
        store.selectedFitClaimCount(in: group)
    }

    private var title: String {
        switch group {
        case .coatType:
            "Coat skills"
        case .breedGroup:
            "Breed groups"
        case .sizeBand:
            "Size experience"
        case .careFlag:
            "Handling needs"
        case .serviceFit:
            "Service strengths"
        }
    }

    private var subtitle: String {
        switch group {
        case .coatType:
            "Coat structures you handle reliably."
        case .breedGroup:
            "Breed contexts retained for matching compatibility."
        case .sizeBand:
            "Body-size experience is set above and does not use core slots."
        case .careFlag:
            "Care situations you accept."
        case .serviceFit:
            "Service work that matches your setup."
        }
    }

    private var statusText: String {
        selectedCount == 1 ? "1 selected" : "\(selectedCount) selected"
    }
}

private struct GroomerFitSignalRow: View {
    let signal: PetFitSignal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(signal.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        isSelected
                            ? DesignTokens.Colors.groomerAccent
                            : DesignTokens.Colors.textTertiary
                    )
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) fit signal")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct GroomerFitSignalsSaveBar: View {
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerFitSignalsWorkspacePresentation

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(presentation.selectionSummary)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(store.sizeBandFitClaimRangeTitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: save) {
                    if presentation.saveActionTitle == "Saving..." {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                            Text(presentation.saveActionTitle)
                        }
                    } else {
                        Label(presentation.saveActionTitle, systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(presentation.isSaveDisabled)
                .accessibilityIdentifier("groomer.fit-signals.save")
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }

    private func save() {
        Task {
            await store.saveFitClaims()
        }
    }
}
