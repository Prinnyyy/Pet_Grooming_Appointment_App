import SwiftUI

struct GroomerVisitRequestOfferRecord: View {
    let offer: GroomerOffer
    var earlierStatus: BeckonStatusPresentation? = nil

    var body: some View {
        let zone = offer.agreementSnapshot?.serviceTimeZoneIdentifier ?? offer.serviceTimeZoneIdentifier
        let note = offer.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPending = offer.status == .pending && offer.evaluatedDisplayStatus() != .status(.expired)
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: earlierStatus == nil ? "Your offer" : "Your earlier offer", systemImage: "tag.fill")
            VStack(spacing: 0) {
                GroomerVisitOfferPriceHeader { _ in
                    Text(GroomerVisitOfferInput.displayPrice(Decimal(offer.priceEstimate)))
                        .lineLimit(1).minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } accessory: {
                    if let earlierStatus { BeckonStatusChip(earlierStatus) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Price estimate")
                .accessibilityValue([offer.priceSummary, earlierStatus?.title].compactMap { $0 }.joined(separator: ", "))

                GroomerVisitDetailRowGroup {
                    GroomerVisitRequestFactRow(systemImage: "calendar", title: "Your proposed time",
                        value: BeckonDateTimeFormatter.interval(from: offer.proposedStart, to: offer.proposedEnd,
                            serviceTimeZoneIdentifier: zone).summary)
                    GroomerVisitRequestFactRow(systemImage: "hourglass",
                        title: isPending ? "The offer ends" : "Original offer deadline",
                        value: GroomingRequestDateFormatting.displayString(from: offer.expiresAt, serviceTimeZoneIdentifier: zone))
                    if let note, !note.isEmpty {
                        GroomerVisitRequestFactRow(systemImage: "text.bubble", title: "Your message", value: note)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, GroomerVisitDetailRowLayout.separatorInset)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
            .beckonLedge(.card)
        }
        .accessibilityIdentifier("groomer.requests.offer")
    }
}

/// An inline explanation grows down from its first line when a form hint or error wraps.
struct GroomerVisitRequestInfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage).font(DesignTokens.Typography.Expressive.glyph).accessibilityHidden(true)
            Text(text).designSupportingText()
        }.foregroundStyle(DesignTokens.Colors.textSecondary)
    }
}
