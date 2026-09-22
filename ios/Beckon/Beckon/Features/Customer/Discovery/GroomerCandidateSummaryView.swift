import SwiftUI

struct GroomerCandidateSummaryView: View {
    let profile: MarketplaceGroomerSummary
    let avatarData: Data?
    var candidate: DiscoveredGroomer? = nil
    var compact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summaryLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            summaryLayout {
                BeckonModuleImage(data: avatarData) {
                    Image(systemName: "person.crop.square")
                        .font(compact ? DesignTokens.Typography.sectionTitle : DesignTokens.Typography.featureTitle)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignTokens.Colors.surface)
                }
                .frame(width: compact ? 64 : 104, height: compact ? 64 : 104)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.displayName)
                        .font(compact ? DesignTokens.Typography.headline : DesignTokens.Typography.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if profile.isVerified {
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .font(DesignTokens.Typography.caption)
                    }
                    let location = [profile.city, profile.state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                    if !location.isEmpty { Text(location).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary) }
                    if let rating = profile.ratingAverage {
                        Label("\(rating.formatted(.number.precision(.fractionLength(1)))) (\(profile.ratingCount))", systemImage: "star.fill")
                            .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
                    } else { Text("No reviews yet").font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary) }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let candidate {
                summaryLayout {
                    Label("\(candidate.distanceMiles.formatted(.number.precision(.fractionLength(1)))) mi", systemImage: "location")
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    if let price = candidate.referencePrice {
                        Text("From \(price.amount.formatted(.currency(code: price.currency)))")
                    } else { Text("Quote required") }
                }
                .font(DesignTokens.Typography.supporting)
                .fixedSize(horizontal: false, vertical: true)
                Text(candidate.eligibility.state == "assessment_required" ? "Needs groomer assessment" : "Fits your request")
                    .font(DesignTokens.Typography.supporting.weight(.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if !compact {
                    if let evidence = candidate.matchingEvidence {
                        BeckonFitEvidenceBlock(scoreText: nil, summary: evidence.summary, reason: evidence.detail,
                            accent: .customer, isCompact: false)
                    }
                    Text("Reference pricing. Your appointment is confirmed only after you accept an offer.")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            if !compact {
                if let years = profile.yearsExperience { Text("\(years) years of experience").font(DesignTokens.Typography.supporting) }
                if let bio = profile.bio, !bio.isEmpty { Text(bio).font(DesignTokens.Typography.body).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .foregroundStyle(DesignTokens.Colors.textPrimary)
    }
}
