import SwiftUI

struct BookingRescheduleSection: View {
    let booking: Booking
    let store: BookingsStore
    @State private var review: BookingRescheduleSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if shouldShowChanges {
            BeckonSectionHeader("Appointment changes")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let proposal = store.rescheduleSnapshots[booking.id]?.proposal {
                    Text(proposal.currentStatus(for: booking, now: context.date).title)
                        .font(DesignTokens.Typography.headline)
                    BookingRescheduleTimes(booking: booking, proposal: proposal)
                    Text(proposal.initiatorID == booking.customerID ? "Proposed by Customer" : "Proposed by Groomer")
                        .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
                    if proposal.currentStatus(for: booking, now: context.date) == .pending {
                        Text("Reply before " + GroomingRequestDateFormatting.displayString(from: proposal.expiresAt,
                            serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier))
                            .font(DesignTokens.Typography.supporting)
                        Text("The original appointment remains confirmed. The proposed time is not reserved.")
                            .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
                if store.pendingRescheduleOperation(for: booking.id) == nil {
                    ForEach(store.rescheduleActions(for: booking, now: context.date)) { action in
                        Button(action.title, systemImage: action == .propose ? "calendar.badge.clock" : "checkmark.circle") {
                            review = BookingRescheduleSelection(action: action,
                                proposal: store.rescheduleSnapshots[booking.id]?.proposal)
                        }
                        .accessibilityIdentifier("booking.reschedule.\(action.rawValue)")
                    }
                }
            }
            if let error = store.rescheduleErrors[booking.id] {
                BeckonErrorBanner(title: "Time change unavailable", message: error)
            }
            if let notice = store.appointmentReminderNotice {
                Text(notice).font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            if let pending = store.pendingRescheduleOperation(for: booking.id) {
                Text("\(pending.action.title): result not yet verified.").font(DesignTokens.Typography.supporting)
                Button("Check Change Status", systemImage: "arrow.clockwise") {
                    Task { await store.recoverReschedule(for: booking.id) }
                }
                Button("Retry Original Change", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await store.recoverReschedule(for: booking.id, retryIfMissing: true) }
                }
            } else {
                Button("Refresh Time Changes", systemImage: "arrow.clockwise") {
                    Task { await store.loadReschedule(for: booking.id) }
                }
            }
            }
        }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
        .disabled(store.isMutatingReschedule || store.isMutatingFulfillment)
        .task(id: booking.id) { await store.loadReschedule(for: booking.id) }
        .bookingRescheduleDialog(selection: $review, booking: booking) { selection, newStart in
            Task { await store.performReschedule(selection.action, for: booking,
                reviewedProposal: selection.proposal, newStart: newStart) }
        }
    }

    private var shouldShowChanges: Bool {
        (booking.status == .confirmed && (booking.fulfillment == nil || booking.fulfillment?.phase == .scheduled))
            || store.rescheduleSnapshots[booking.id]?.proposal != nil
            || store.pendingRescheduleOperation(for: booking.id) != nil
            || store.rescheduleErrors[booking.id] != nil
    }
}

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
