import SwiftUI

struct GroomerFitSignalsEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var successNoticeMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                BeckonSectionHeader(
                    "Fit Signals",
                    subtitle: "Keep your core skills focused while size experience stays separate."
                )

                GroomerFitSignalOverviewCard(store: store)

                if let errorMessage = store.errorMessage {
                    BeckonErrorBanner(
                        title: "Fit Signals Could Not Be Saved",
                        message: errorMessage
                    )
                    .accessibilityIdentifier("groomer.fit-signals.error")
                }

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
            .padding(.bottom, 156)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Fit Signals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.ensureSizeBandFitClaimRange()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if let successNoticeMessage {
                    BeckonBottomPromptStack(
                        topPadding: 0,
                        bottomPadding: 0,
                        animationValue: successNoticeMessage
                    ) {
                        BeckonNoticeToast(message: successNoticeMessage)
                    }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: successNoticeMessage) {
                            await dismissSuccessNotice(successNoticeMessage)
                        }
                }

                GroomerFitSignalsSaveBar(store: store) { message in
                    withAnimation(.easeInOut(duration: 0.24)) {
                        successNoticeMessage = message
                    }
                    guard store.noticeMessage == message else { return }
                    store.noticeMessage = nil
                }
            }
        }
        .accessibilityIdentifier("groomer.fit-signals.edit")
    }

    private func dismissSuccessNotice(_ message: String) async {
        try? await Task.sleep(
            nanoseconds: BeckonFeedbackCenter.noticeDismissDelayNanoseconds
        )
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard successNoticeMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                successNoticeMessage = nil
            }
        }
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerFitClaim.availableSignals.contains(where: {
                $0.group == group
            })
        }
    }

    private func signals(for group: PetFitSignal.Group) -> [PetFitSignal] {
        GroomerFitClaim.availableSignals.filter { $0.group == group }
    }
}

private struct GroomerFitSignalOverviewCard: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.Colors.groomerAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Selection Balance")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Core skills drive starter matching. Size bands add experience context without using that limit.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                        Text("Core Skills")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer(minLength: DesignTokens.Spacing.md)

                        Text("\(store.selectedCoreFitClaimCount)/\(GroomerFitClaim.maximumActiveClaims)")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    ProgressView(
                        value: Double(store.selectedCoreFitClaimCount),
                        total: Double(GroomerFitClaim.maximumActiveClaims)
                    )
                    .tint(DesignTokens.Colors.groomerAccent)

                    Text("Coat, handling, and service strengths")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                GroomerSizeExperienceRangeControl(store: store)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GroomerSizeExperienceRangeControl: View {
    @Bindable var store: GroomerProfileStore

    private let sizeCodes = CustomerPetSizeCode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Size Experience")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Acceptable pet size range")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(store.sizeBandFitClaimRangeTitle)
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                BeckonSectionHeader(
                    "Evidence Dashboard",
                    subtitle: "Completed bookings and structured reviews by pet-fit signal."
                ) {
                    BeckonStatusChip(
                        "\(summaries.count) signal\(summaries.count == 1 ? "" : "s")",
                        systemImage: "sparkles",
                        tone: .groomer
                    )
                }

                GroomerEvidenceDashboardSummaryCard(summaries: summaries)

                if summaries.isEmpty {
                    BeckonEmptyState(
                        title: "No Evidence Yet",
                        message: "Completed bookings and structured reviews will appear here as they accumulate.",
                        systemImage: "chart.bar.xaxis",
                        accent: .groomer
                    )
                    .accessibilityIdentifier("groomer.evidence.empty")
                } else {
                    ForEach(summaries) { summary in
                        GroomerEvidenceSummaryRow(summary: summary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.evidence.dashboard")
    }
}

private struct GroomerEvidenceDashboardSummaryCard: View {
    let summaries: [GroomerPetFitEvidenceSummary]

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 48, height: 48)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Evidence Summary")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Aggregate counts from completed care history")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    GroomerEvidenceMetricView(
                        value: totalCompletedBookings,
                        label: "Completed"
                    )

                    GroomerEvidenceMetricView(
                        value: totalPositiveOutcomes,
                        label: "Positive"
                    )

                    GroomerEvidenceMetricView(
                        value: highConfidenceCount,
                        label: "High Tier"
                    )
                }
            }
        }
    }

    private var totalCompletedBookings: Int {
        summaries.reduce(0) { $0 + $1.completedBookingCount }
    }

    private var totalPositiveOutcomes: Int {
        summaries.reduce(0) { $0 + $1.positiveReviewOutcomeCount }
    }

    private var highConfidenceCount: Int {
        summaries.filter { $0.confidenceTier == .high }.count
    }
}

private struct GroomerEvidenceMetricView: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(value.formatted())
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroomerEvidenceSummaryRow: View {
    let summary: GroomerPetFitEvidenceSummary

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 46, height: 46)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(summary.signal.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(summary.signal.groupTitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BeckonStatusChip(
                        "\(summary.confidenceTier.title) confidence",
                        systemImage: confidenceIconName,
                        tone: confidenceTone
                    )
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    GroomerEvidenceCountLine(
                        title: "Completed bookings",
                        value: summary.completedBookingCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Positive review outcomes",
                        value: summary.positiveReviewOutcomeCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Negative review outcomes",
                        value: summary.negativeReviewOutcomeCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Structured review outcomes",
                        value: summary.structuredReviewOutcomeCount
                    )
                }

                if let updatedAt = summary.evidenceUpdatedAt {
                    Text("Updated \(GroomingRequestDateFormatting.displayString(from: updatedAt))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        }
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

    private var confidenceIconName: String {
        switch summary.confidenceTier {
        case .high:
            "checkmark.seal.fill"
        case .medium:
            "checkmark.circle.fill"
        case .low:
            "circle"
        }
    }

    private var confidenceTone: BeckonStatusChip.Tone {
        switch summary.confidenceTier {
        case .high:
            .success
        case .medium:
            .groomer
        case .low:
            .neutral
        }
    }
}

private struct GroomerEvidenceCountLine: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value.formatted())
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
    }
}

private struct GroomerFitSignalGroupSection: View {
    let group: PetFitSignal.Group
    let signals: [PetFitSignal]
    @Bindable var store: GroomerProfileStore

    var body: some View {
        BeckonCard(padding: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 42, height: 42)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BeckonStatusChip(
                        statusText,
                        systemImage: statusIconName,
                        tone: group == .sizeBand ? .neutral : .groomer
                    )
                }

                VStack(spacing: 0) {
                    ForEach(signals) { signal in
                        GroomerFitSignalRow(
                            signal: signal,
                            isSelected: store.isFitClaimSelected(signal)
                        ) {
                            store.toggleFitClaim(signal)
                        }

                        if signal.id != signals.last?.id {
                            Divider()
                                .padding(.leading, DesignTokens.Spacing.sm)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var selectedCount: Int {
        store.selectedFitClaimCount(in: group)
    }

    private var title: String {
        switch group {
        case .coatType:
            "Coat Skills"
        case .breedGroup:
            "Breed Groups"
        case .sizeBand:
            "Size Experience"
        case .careFlag:
            "Handling Needs"
        case .serviceFit:
            "Service Strengths"
        }
    }

    private var subtitle: String {
        switch group {
        case .coatType:
            "Coat structures you handle reliably."
        case .breedGroup:
            "Breed contexts kept for compatibility."
        case .sizeBand:
            "Body-size ranges you are comfortable grooming. These do not use core skill slots."
        case .careFlag:
            "Care situations you accept."
        case .serviceFit:
            "Service work that matches your setup."
        }
    }

    private var statusText: String {
        if group == .sizeBand {
            return selectedCount == 1 ? "1 extra" : "\(selectedCount) extra"
        }
        return selectedCount == 1 ? "1 selected" : "\(selectedCount) selected"
    }

    private var statusIconName: String {
        group == .sizeBand ? "plus.circle" : "checkmark.circle"
    }

    private var iconName: String {
        switch group {
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

private struct GroomerFitSignalRow: View {
    let signal: PetFitSignal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(signal.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? DesignTokens.Colors.groomerAccent
                            : DesignTokens.Colors.textTertiary
                    )
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) fit signal")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct GroomerFitSignalsSaveBar: View {
    @Bindable var store: GroomerProfileStore
    let onSaved: (String) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("\(store.selectedCoreFitClaimCount)/\(GroomerFitClaim.maximumActiveClaims) core skills")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(sizeBandSummaryText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        if let noticeMessage = await store.saveFitClaims() {
                            onSaved(noticeMessage)
                        }
                    }
                } label: {
                    if store.isSaving {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                            Text("Saving...")
                        }
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.fit-signals.save")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background {
            Rectangle()
                .fill(DesignTokens.Colors.surfaceRaised)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderSoft)
                        .frame(height: 1)
                }
        }
    }

    private var sizeBandSummaryText: String {
        store.sizeBandFitClaimRangeTitle
    }
}
