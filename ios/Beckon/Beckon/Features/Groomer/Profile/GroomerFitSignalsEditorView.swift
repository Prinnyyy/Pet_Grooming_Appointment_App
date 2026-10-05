import SwiftUI

struct GroomerFitSignalsEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        let presentation = GroomerFitSignalsWorkspacePresentation(
            selectedCoreFitClaimCount: store.selectedCoreFitClaimCount,
            maximumActiveClaims: GroomerFitClaim.maximumActiveClaims,
            isSaving: store.isSaving,
            isBusy: store.isBusy || !store.canEditFitSignals
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                if !store.canEditFitSignals {
                    if store.isLoadingOptionalMetadata { ProgressView("Loading fit signals...") }
                    else {
                        Text("Fit signals could not be refreshed.").font(DesignTokens.Typography.supporting)
                        Button("Retry", systemImage: "arrow.clockwise") { Task { await store.load() } }
                    }
                }
                if store.hasLoadedFitClaims {
                GroomerFitSignalsSelectionBalanceSection(
                    store: store,
                    presentation: presentation
                )
                .disabled(!store.canEditFitSignals)

                ForEach(Self.visibleGroups) { group in
                    GroomerFitSignalGroupSection(
                        group: group,
                        signals: signals(for: group),
                        store: store
                    )
                    .disabled(!store.canEditFitSignals)
                }
                }
            }
            .beckonPageInsets()
        }
        .accessibilityIdentifier("groomer.fit-signals.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Fit Signals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if store.canEditFitSignals { store.ensureSizeBandFitClaimRange() }
        }
        .onChange(of: store.canEditFitSignals) { _, ready in
            if ready { store.ensureSizeBandFitClaimRange() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.hasLoadedFitClaims {
            GroomerFitSignalsSaveBar(
                store: store,
                presentation: presentation
            )
            }
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
        BeckonSection(
            "Selection Balance",
            subtitle: "Keep your strongest matching signals focused and current."
        ) {
            BeckonGroupedSurface {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
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
                                .foregroundStyle(DesignTokens.Colors.groomerOnAccent)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ProgressView(
                            value: Double(store.selectedCoreFitClaimCount),
                            total: Double(GroomerFitClaim.maximumActiveClaims)
                        )
                        .tint(DesignTokens.Colors.groomerAccent)
                    }

                    BeckonGroupedDivider()

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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
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
                    .foregroundStyle(DesignTokens.Colors.groomerOnAccent)
                    .fixedSize(horizontal: false, vertical: true)
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

            GroomerSizeRangeLegend(titles: sizeCodes.map(\.title))
        }
    }
}

struct GroomerEvidenceDashboardView: View {
    @Bindable var store: GroomerProfileStore

    private var summaries: [GroomerPetFitEvidenceSummary] {
        store.sortedPetFitEvidenceSummary()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                if summaries.isEmpty {
                    GroomerEvidenceEmptyState()
                        .accessibilityIdentifier("groomer.evidence.empty")
                } else {
                    GroomerEvidenceOverviewSection(summaries: summaries)

                    BeckonSection(
                        "Evidence by Signal",
                        subtitle: "Verified service feedback"
                    ) {
                        BeckonGroupedSurface {
                            VStack(spacing: 0) {
                                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                                    GroomerEvidenceSummaryRow(summary: summary)

                                    if index < summaries.count - 1 {
                                        BeckonGroupedDivider(leadingInset: 56)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .beckonPageInsets()
        }
        .accessibilityIdentifier("groomer.evidence.dashboard")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct GroomerEvidenceOverviewSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summaries: [GroomerPetFitEvidenceSummary]

    var body: some View {
        BeckonSection(
            "Evidence Overview",
            subtitle: "A summary of outcomes connected to your matching signals."
        ) {
            BeckonGroupedSurface {
                metricLayout {
                    GroomerEvidenceMetric(
                        summary: String(summaries.count),
                        label: "Service details"
                    )
                    GroomerEvidenceMetric(
                        summary: String(summaries.reduce(0) { $0 + $1.positiveReviewOutcomeCount }),
                        label: "Positive answers"
                    )
                    GroomerEvidenceMetric(
                        summary: String(summaries.reduce(0) { $0 + $1.negativeReviewOutcomeCount }),
                        label: "Negative answers"
                    )
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var metricLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
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
                .fixedSize(horizontal: false, vertical: true)

            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroomerEvidenceEmptyState: View {
    var body: some View {
        BeckonSection(
            "Evidence Overview",
            subtitle: "Evidence appears after completed bookings and structured reviews."
        ) {
            BeckonGroupedSurface {
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

                Text(summary.signal.groupTitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)

                Text("\(summary.completedBookingCount) completed · \(summary.positiveReviewOutcomeCount) positive · \(summary.negativeReviewOutcomeCount) negative · \(max(0, summary.completedBookingCount - summary.structuredReviewOutcomeCount)) unreported")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

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
        case .coatType, .verifiedCoat:
            "comb"
        case .breedGroup:
            "pawprint.fill"
        case .sizeBand, .verifiedSize:
            "ruler"
        case .careFlag, .verifiedCare:
            "heart.fill"
        case .serviceFit, .verifiedService:
            "scissors"
        }
    }
}

private struct GroomerFitSignalGroupSection: View {
    let group: PetFitSignal.Group
    let signals: [PetFitSignal]
    @Bindable var store: GroomerProfileStore

    var body: some View {
        BeckonSection(title, subtitle: subtitle) {
            BeckonGroupedSurface {
                VStack(spacing: 0) {
                    ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                        GroomerFitSignalRow(
                            signal: signal,
                            isSelected: store.isFitClaimSelected(signal)
                        ) {
                            store.toggleFitClaim(signal)
                        }

                        if index < signals.count - 1 {
                            BeckonGroupedDivider(leadingInset: DesignTokens.Layout.surfaceInset)
                        }
                    }
                }
            }
        } trailing: {
                Text(statusText)
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.groomerOnAccent)
                    .lineLimit(1)
        }
    }

    private var selectedCount: Int {
        store.selectedFitClaimCount(in: group)
    }

    private var title: String {
        switch group {
        case .coatType, .verifiedCoat:
            "Coat skills"
        case .breedGroup:
            "Breed groups"
        case .sizeBand, .verifiedSize:
            "Size experience"
        case .careFlag, .verifiedCare:
            "Handling needs"
        case .serviceFit, .verifiedService:
            "Service strengths"
        }
    }

    private var subtitle: String {
        switch group {
        case .coatType, .verifiedCoat:
            "Coat structures you handle reliably."
        case .breedGroup:
            "Breed contexts retained for matching compatibility."
        case .sizeBand, .verifiedSize:
            "Body-size experience is set above and does not use core slots."
        case .careFlag, .verifiedCare:
            "Care situations you accept."
        case .serviceFit, .verifiedService:
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerFitSignalsWorkspacePresentation

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            actionLayout {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(presentation.selectionSummary)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.sizeBandFitClaimRangeTitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
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
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer, isFullWidth: dynamicTypeSize.isAccessibilitySize))
                .disabled(presentation.isSaveDisabled)
                .accessibilityIdentifier("groomer.fit-signals.save")
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }

    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
    }

    private func save() {
        Task {
            await store.saveFitClaims()
        }
    }
}
