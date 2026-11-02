// The groomer's fit signals and evidence, in the customer prototype's language (design) and laid out from what they are for (design).
// Same job as GroomerFitSignalsEditorView and GroomerEvidenceDashboardView in Features/Groomer/Profile/GroomerFitSignalsEditorView.swift:
// choose the skills that guide matching (coat, handling, services; up to eight core ones) and the sizes of pet the groomer is
// comfortable with, save them; and read what completed bookings and reviews say about each skill. The store, the limits, the size-range
// rules and the ids are the real ones.
// Fit signals is the groomer's claim, and its limit is the point of the page, so the page opens on the slots: a coral banner with how
// many of the eight are used, in pips, and what to do when all are (the skills left over are dimmed). Evidence is the proof: one row
// per skill, built alike (the skill, how much evidence there is, how its completed jobs were answered as one bar), and a negative
// answer is a note along the foot of its card, not a chip. The two pages and the portfolio speak of skills in the same words
// (`PetFitSignal.Group.beckonTitle`).
import SwiftUI


struct GroomerFitSignalsEditorView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let presentation = GroomerFitSignalsWorkspacePresentation(
            selectedCoreFitClaimCount: store.selectedCoreFitClaimCount,
            maximumActiveClaims: GroomerFitClaim.maximumActiveClaims,
            isSaving: store.isSaving,
            isBusy: store.isBusy || !store.canEditFitSignals
        )

        DesignPage {
            if !store.canEditFitSignals {
                if store.isLoadingOptionalMetadata {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ProgressView().tint(DesignTokens.Colors.customerDeep)
                        Text("Loading fit signals…").designSupportingText()
                    }
                } else {
                    BeckonErrorBanner(title: "Fit signals could not be refreshed", message: "Try again to edit them.") {
                        Button { Task { await store.load() } } label: {
                            DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                }
            }
            if store.hasLoadedFitClaims {
                slots
                sizes.disabled(!store.canEditFitSignals)
                ForEach(Self.groups) { group in
                    section(group).disabled(!store.canEditFitSignals)
                }
                GroomerBarClearance()
            }
        }
        .navigationTitle("Fit signals")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .onAppear { if store.canEditFitSignals { store.ensureSizeBandFitClaimRange() } }
        .onChange(of: store.canEditFitSignals) { _, ready in
            if ready { store.ensureSizeBandFitClaimRange() }
        }
        .background { GroomerProfileStatusView(store: store) }
        .beckonStationaryPageAction {
            if store.hasLoadedFitClaims {
                GroomerSaveBar(title: "Save fit signals", isSaving: store.isSaving, isDisabled: presentation.isSaveDisabled,
                    identifier: "groomer.fit-signals.save",
                    summary: "\(presentation.selectionSummary) · \(store.sizeBandFitClaimRangeTitle)") {
                    Task { await store.saveFitClaims() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.fit-signals.edit")
    }

    // MARK: Slots

    private var isFull: Bool { store.selectedCoreFitClaimCount >= GroomerFitClaim.maximumActiveClaims }

    /// How many of the eight core slots are used. With all of them used it says what to do, and the chips left over are dimmed.
    private var slots: some View {
        let used = store.selectedCoreFitClaimCount
        let limit = GroomerFitClaim.maximumActiveClaims
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm))) {
                Text("\(used)").font(DesignTokens.Typography.Expressive.display)
                Text("of \(limit) core skills").font(DesignTokens.Typography.Expressive.headline)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            GroomerPips(filled: used, total: limit, onBanner: true)
            Text(isFull ? "Every slot is used. Remove a skill to choose another."
                : "Coat, handling, and service strengths guide matching.")
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .designBanner()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("groomer.fit-signals.balance")
    }

    // MARK: Sizes

    private var sizes: some View {
        let options = CustomerPetSizeCode.allCases
        return DesignSection(title: PetFitSignal.Group.sizeBand.beckonTitle, systemImage: PetFitSignal.Group.sizeBand.beckonSymbol,
            spacing: DesignTokens.Spacing.md) {
            Text("Set the full range you are comfortable grooming.").designSupportingText()
            Text(store.sizeBandFitClaimRangeTitle)
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier("groomer.fit-signals.size-range-title")
            GroomerSizeRangeSlider(
                lowerIndex: Binding(get: { store.selectedSizeBandRange.lowerBound }, set: {
                    store.setSizeBandFitClaimRange(lowerIndex: $0, upperIndex: store.selectedSizeBandRange.upperBound)
                }),
                upperIndex: Binding(get: { store.selectedSizeBandRange.upperBound }, set: {
                    store.setSizeBandFitClaimRange(lowerIndex: store.selectedSizeBandRange.lowerBound, upperIndex: $0)
                }),
                optionCount: options.count, rangeTitle: store.sizeBandFitClaimRangeTitle)
            GroomerSizeRangeLegend(titles: options.map(\.title))
        }
    }

    // MARK: Skills

    private func section(_ group: PetFitSignal.Group) -> some View {
        let signals = GroomerFitClaim.availableSignals.filter { $0.group == group }
        let selected = store.selectedFitClaimCount(in: group)
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: group.beckonTitle, systemImage: group.beckonSymbol, count: selected)
            Text(group.beckonSubtitle).designSupportingText()
            BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                ForEach(signals) { signal in
                    let isSelected = store.isFitClaimSelected(signal)
                    DesignChoiceChip(title: signal.title, isSelected: isSelected) {
                        store.toggleFitClaim(signal)
                    }
                    .disabled(isFull && !isSelected)
                    .accessibilityLabel("\(signal.title) fit signal")
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                }
            }
            .designCardBody()
        }
    }

    private static var groups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerFitClaim.availableSignals.contains { $0.group == group }
        }
    }
}


// MARK: Evidence

/// What completed bookings and structured reviews say about each skill: one row per skill, the best evidence first.
struct GroomerEvidenceDashboardView: View {
    @Bindable var store: GroomerProfileStore

    private var summaries: [GroomerPetFitEvidenceSummary] { store.sortedPetFitEvidenceSummary() }

    var body: some View {
        DesignPage {
            if summaries.isEmpty {
                // Nothing is "no evidence yet" only once the read is over: before it, and when it failed, the page says so.
                if store.isLoadingOptionalMetadata || (!store.hasLoadedFitClaims && store.optionalLoadError == nil) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ProgressView().tint(DesignTokens.Colors.customerDeep)
                        Text("Loading evidence…").designSupportingText()
                    }
                } else if store.optionalLoadError != nil {
                    BeckonErrorBanner(title: "Evidence could not be refreshed", message: "Try again to read it.") {
                        Button { Task { await store.load() } } label: {
                            DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("No evidence yet")
                            .font(DesignTokens.Typography.Expressive.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                        Text("Evidence appears after completed bookings and structured reviews.").designSupportingText()
                    }
                    .designCardBody()
                    .accessibilityIdentifier("groomer.evidence.empty")
                }
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    BeckonLedgeHeading(title: "Customer proof", systemImage: "checkmark.seal.fill", count: summaries.count)
                    Text("Confidence grows with completed bookings and customer answers.").designSupportingText()
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(summaries) { summary in GroomerEvidenceRow(summary: summary) }
                    }
                    if let updated {
                        Text("Evidence updated \(updated)")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
            }
        }
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .accessibilityIdentifier("groomer.evidence.dashboard")
    }

    /// When the evidence was last brought up to date (the newest of the skills'), as a day. There are no totals across the skills: one
    /// booking is counted once for each skill it proves, so their sum would count it more than once.
    private var updated: String? {
        summaries.compactMap(\.evidenceUpdatedAt).max()
            .flatMap(GroomingRequestDateFormatting.parsedDate(from:))?.formatted(date: .abbreviated, time: .omitted)
    }
}


/// One skill's evidence: its name and how much evidence there is (three pips and a word), how many jobs were completed and answered
/// well, and a bar of how they were answered. A negative answer is the note along the foot of the card.
private struct GroomerEvidenceRow: View {
    let summary: GroomerPetFitEvidenceSummary
    @Environment(\.dynamicTypeSize) private var typeSize

    private var level: Int {
        switch summary.confidenceTier {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    DesignIconDisc(systemImage: summary.signal.group.beckonSymbol, size: .touch,
                        font: DesignTokens.Typography.Expressive.glyph)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
                        titleLine
                        Text("\(summary.completedBookingCount) completed · \(summary.positiveReviewOutcomeCount) positive")
                            .font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroomerProofBar(positive: summary.positiveReviewOutcomeCount, negative: summary.negativeReviewOutcomeCount,
                    total: summary.completedBookingCount)
            }
            .padding(DesignTokens.Spacing.md)
            if summary.negativeReviewOutcomeCount > 0 {
                BeckonFootNote(text: summary.negativeReviewOutcomeCount == 1 ? "1 negative answer"
                    : "\(summary.negativeReviewOutcomeCount) negative answers", systemImage: "exclamationmark.triangle.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.signal.title), \(summary.confidenceTier.title) confidence, \(summary.completedBookingCount) completed, "
            + "\(summary.positiveReviewOutcomeCount) positive, \(summary.negativeReviewOutcomeCount) negative")
    }

    private var titleLine: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm))) {
            // The name is what the row is about, so a long one takes a second line before it is cut.
            Text(summary.signal.title)
                .font(DesignTokens.Typography.Expressive.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(summary.confidenceTier.title)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                GroomerPips(filled: level, total: 3)
            }
            .fixedSize()
        }
    }
}
