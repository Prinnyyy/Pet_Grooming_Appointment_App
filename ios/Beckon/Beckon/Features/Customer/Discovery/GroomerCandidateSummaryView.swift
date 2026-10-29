import SwiftUI


struct GroomerCandidateSummaryView: View {
    let profile: MarketplaceGroomerSummary
    let avatarData: Data?
    var candidate: DiscoveredGroomer? = nil
    var compact = false
    /// Where the groomer stands for the request ("Invited", "Not a fit"): a chip in the row of the Verified chip, so it never adds a row.
    var status: (title: String, systemImage: String)? = nil
    /// The card behind is mint (it is ticked): the chips go white.
    var onTint = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    private var badges: some View {
        if profile.isVerified { BeckonMetaChip(text: "Verified", systemImage: "checkmark.seal.fill", onTint: onTint) }
        if let status { BeckonMetaChip(text: status.title, systemImage: status.systemImage, onTint: onTint) }
    }

    private var summaryLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            summaryLayout {
                BeckonProfileAvatar(data: avatarData, tone: .groomer, size: compact ? 64 : 96,
                    cornerRadius: DesignTokens.CornerRadius.inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(profile.displayName)
                        .font(compact ? DesignTokens.Typography.Expressive.headline : DesignTokens.Typography.Expressive.title)
                        .fixedSize(horizontal: false, vertical: true)
                    if profile.isVerified || status != nil {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: DesignTokens.Spacing.sm) { badges }
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) { badges }
                        }
                    }
                    let location = [profile.city, profile.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                    if !location.isEmpty {
                        Text(location).font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    if let rating = profile.ratingAverage {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "star.fill").foregroundStyle(DesignTokens.Colors.ratingStar)
                                .accessibilityHidden(true)
                            Text("\(rating.formatted(.number.precision(.fractionLength(1)))) (\(profile.ratingCount))")
                        }
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    } else {
                        Text("No reviews yet").font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let candidate {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DesignTokens.Spacing.sm) { candidateChips(candidate) }
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) { candidateChips(candidate) }
                }
                // Everyone on the list fits the request, so a box saying so on every card said nothing; it appears only for the
                // exception, a groomer who has to see the pet first.
                if candidate.eligibility.state == "assessment_required" {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(DesignTokens.Colors.customerDeep)
                            .accessibilityHidden(true)
                        Text("Needs groomer assessment")
                            .font(DesignTokens.Typography.Expressive.emphasis)
                            .foregroundStyle(DesignTokens.Colors.customerInk)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.Colors.customerTint,
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
                }
                if !compact {
                    if let evidence = candidate.matchingEvidence {
                        BeckonFitEvidenceBlock(scoreText: nil, summary: evidence.summary, reason: evidence.detail, isCompact: false)
                    }
                    Text("Reference price. Booked when you accept an offer.")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            if !compact {
                if let years = profile.yearsExperience {
                    Text("\(years) years of experience").font(DesignTokens.Typography.Expressive.supporting)
                }
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio).font(DesignTokens.Typography.Expressive.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    @ViewBuilder
    private func candidateChips(_ candidate: DiscoveredGroomer) -> some View {
        BeckonMetaChip(text: "\(candidate.distanceMiles.formatted(.number.precision(.fractionLength(1)))) mi",
            systemImage: "location.fill")
        if let price = candidate.referencePrice {
            BeckonMetaChip(text: "From \(price.amount.formatted(.currency(code: price.currency)))", systemImage: "tag.fill")
        } else {
            BeckonMetaChip(text: "Quote required", systemImage: "tag.fill")
        }
    }
}
