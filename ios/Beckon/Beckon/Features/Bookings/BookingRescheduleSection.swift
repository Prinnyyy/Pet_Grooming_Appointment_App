import SwiftUI

struct BookingRescheduleTimes: View {
    let booking: Booking
    let proposal: BookingRescheduleProposal
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Original time").font(DesignTokens.Typography.fieldLabel)
            Text(summary(proposal.previousAgreement.scheduledStart, proposal.previousAgreement.scheduledEnd))
                .font(DesignTokens.Typography.body)
            Text("Proposed time").font(DesignTokens.Typography.fieldLabel)
            Text(summary(proposal.proposedStart, proposal.proposedEnd)).font(DesignTokens.Typography.body)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    private func summary(_ start: String, _ end: String) -> String {
        let zone = booking.serviceTimeZoneIdentifier
        return BeckonDateTimeFormatter.interval(from: start, to: end, serviceTimeZoneIdentifier: zone).summary
    }
}
