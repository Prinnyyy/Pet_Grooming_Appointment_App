import SwiftUI

/// Groomer-facing comparison for a pending proposal on this booking.
struct GroomerVisitBookingTimeChange: View {
    let booking: Booking
    let proposal: BookingRescheduleProposal
    var showsTitle = true

    private var zone: String? { booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier }

    private func labels(_ start: String, _ end: String) -> GroomerVisitRequestTimeLabels? {
        guard let start = GroomingRequestDateFormatting.parsedDate(from: start),
              let end = GroomingRequestDateFormatting.parsedDate(from: end) else { return nil }
        var calendar = Calendar.current
        if let zone, let timeZone = TimeZone(identifier: zone) { calendar.timeZone = timeZone }
        return GroomerVisitRequestTimeLabels(start: start, end: end, calendar: calendar)
    }

    var body: some View {
        let yours = proposal.initiatorID == booking.groomerID
        let proposed = labels(proposal.proposedStart, proposal.proposedEnd)
        let booked = labels(booking.scheduledStart, booking.scheduledEnd)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if showsTitle {
                GroomerVisitExplanationTitle(title: yours ? "Time change sent" : "Time change request")
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Proposed time").font(DesignTokens.Typography.Expressive.chip)
                if let proposed {
                    Text(proposed.startDate).font(DesignTokens.Typography.Expressive.emphasis)
                    Text(timeRange(proposed)).font(DesignTokens.Typography.Expressive.headline)
                } else {
                    Text(BeckonDateTimeFormatter.interval(from: proposal.proposedStart, to: proposal.proposedEnd,
                        serviceTimeZoneIdentifier: zone).summary).font(DesignTokens.Typography.Expressive.headline)
                }
            }
            .foregroundStyle(proposal.initiatorID == booking.groomerID
                ? GroomerVisitWaitingPalette(responder: .customer).icon : GroomerVisitStatusTone.action.colors.icon)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Proposed time. " + BeckonDateTimeFormatter.interval(from: proposal.proposedStart,
                to: proposal.proposedEnd, serviceTimeZoneIdentifier: zone).summary)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Current appointment").font(DesignTokens.Typography.Expressive.chip)
                if let booked {
                    Text(booked.startDate).font(DesignTokens.Typography.Expressive.supporting)
                    Text(timeRange(booked)).font(DesignTokens.Typography.Expressive.supporting)
                } else {
                    Text(booking.scheduledTimeSummary).font(DesignTokens.Typography.Expressive.supporting)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current appointment. " + BeckonDateTimeFormatter.interval(from: booking.scheduledStart,
                to: booking.scheduledEnd, serviceTimeZoneIdentifier: zone).summary)
            Divider()
            Label("Reply by " + GroomingRequestDateFormatting.displayString(
                from: proposal.expiresAt, serviceTimeZoneIdentifier: zone), systemImage: "clock")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }

    }

    private func timeRange(_ labels: GroomerVisitRequestTimeLabels) -> String {
        labels.startTime + " – " + labels.endTime
    }
}
