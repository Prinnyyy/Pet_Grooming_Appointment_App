// The pieces of the groomer's booking page that are the groomer's own (design). The page is the owner's Grooming detail seen from the
// other side, so most of its blocks are that page's (the hero with its path, the cards that say what needs the person, the manage
// rows, the activity), and what is here is what a groomer needs and an owner does not: where the booking stands on the groomer's
// path, the appointment with the way there and the time it holds, what to know about the pet before starting, and the owner's
// review. The page that holds them is GroomerBookingDetailView.swift.
import SwiftUI


// MARK: Where the booking stands

/// A booking's place on the groomer's path (Booked, In service, Finished, Reviewed), the bubble over it, and what a closed booking says.
/// Worked out from the booking and the clock alone, so a preview can say any moment.
struct GroomerBookingStage {
    let path: GroomingDetailHero.Path?
    let closed: GroomingDetailHero.Closed?
    /// The service is over: the owner's review is the thing for this stage.
    let isFinished: Bool

    var isClosed: Bool { closed != nil }

    init(_ booking: Booking, now: Date) {
        let stops = BeckonJourneyStop.servicePath
        if booking.status.isCancellation || booking.status == .unfulfilled {
            path = nil
            isFinished = false
            closed = .init(status: booking.status.presentation, message: Self.closedMessage(booking.status))
            return
        }
        closed = nil
        let phase = booking.fulfillment?.phase
        let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart)
        let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd)

        if booking.status == .completed || phase == .completed {
            isFinished = true
            path = booking.review != nil
                ? .init(stops: stops, current: stops.count, fills: [1, 1, 1], status: "Finished and reviewed")
                : .init(stops: stops, current: 3, fills: [1, 1, 0.4], bubble: .init(kind: .waitingFor("Awaiting review"), column: 3),
                    status: "Finished, waiting for the customer's review")
            return
        }
        isFinished = false

        switch phase {
        case .inService:
            let started = booking.fulfillment?.actualStartedAt.flatMap { GroomingRequestDateFormatting.parsedDate(from: $0) } ?? start
            let length = max(1, (end ?? now).timeIntervalSince(start ?? now))
            let progress = started.map { min(0.92, max(0.08, now.timeIntervalSince($0) / length)) } ?? 0.08
            path = .init(stops: stops, current: 1, fills: [1, progress, 0],
                bubble: .init(kind: .status("In service", systemImage: "scissors"), column: 1), status: "In service")
        case .outcomeReported:
            let reportedByGroomer = booking.fulfillment?.reportedBy == booking.groomerID
            path = .init(stops: stops, current: 1, fills: [1, 0.8, 0],
                bubble: .init(kind: reportedByGroomer ? .waitingFor("Customer to confirm") : .confirmOutcome, column: 1),
                status: reportedByGroomer ? "Service reported, waiting for the customer" : "Confirm the outcome")
        default:
            // Until the service record is read the groomer can do nothing with a booking, so the bubble only counts the days.
            if phase != nil, let end, now >= end {
                path = .init(stops: stops, current: 0, fills: [0.8, 0, 0],
                    bubble: .init(kind: .attention("Close it out", systemImage: "exclamationmark.circle.fill"), column: 0),
                    status: "The time is over and the service was not closed")
            } else if phase != nil, let start, now >= start {
                path = .init(stops: stops, current: 0, fills: [0.8, 0, 0],
                    bubble: .init(kind: .attention("Start now", systemImage: "play.circle.fill"), column: 0),
                    status: "Time to start")
            } else {
                let countdown = BeckonBookingCountdown.label(for: booking, now: now)
                path = .init(stops: stops, current: 0, fills: [GroomingFeed.waitingProgress(booking, now: now), 0, 0],
                    bubble: .init(kind: .countdown(countdown == "Today" ? "Today!" : (countdown ?? "Booked")), column: 0),
                    status: countdown.map { "Booked, \($0.lowercased())" } ?? "Booked")
            }
        }
    }

    private static func closedMessage(_ status: BookingStatus) -> String {
        switch status {
        case .cancelledByCustomer: "The customer cancelled this booking. The time is free again."
        case .cancelledByGroomer: "You cancelled this booking."
        case .unfulfilled: "This service was not confirmed. Nothing more will happen on it."
        default: "This booking is no longer active."
        }
    }
}


// MARK: The appointment

/// When and where, as the owner's page says it, with what only a groomer needs: the way there (a mobile booking) and the customer
/// with the way to message them. The booking holds its appointment and nothing around it (design): the groomer judges what fits.
struct GroomerBookingAppointment: View {
    let booking: Booking
    var onOpenChat: ((Booking) -> Void)?
    /// The service is over or the booking is closed: the way there is no longer needed.
    var isOver = false

    private var isMobile: Bool { booking.locationMode == .groomerComesToCustomer }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Appointment", systemImage: "calendar")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomingAppointmentHeader(booking: booking)
                DesignFactRow(systemImage: "location.fill", title: locationTitle, value: booking.appointmentAddressSummary)
                if isMobile, !isOver { directions }
                DesignRowDivider()
                GroomingPartnerFoot(caption: "Your customer", name: "Customer · #\(booking.participantReferenceCode(for: .groomer))",
                    messageLabel: "Message your customer", onMessage: onOpenChat.map { open in { open(booking) } }) {
                    BeckonProfileAvatar(data: nil, tone: .customer, size: DesignTokens.Metrics.minimumTouchTarget,
                        cornerRadius: DesignTokens.CornerRadius.pill)
                }
            }
            .designCardBody()
        }
        .accessibilityIdentifier("groomer.booking.details")
    }

    private var locationTitle: String {
        booking.locationMode.map { BeckonGroomingLocationModePresentation(mode: $0, perspective: .groomer).title }
            ?? "Location not confirmed"
    }

    /// The address in the maps app: the way to the customer's door.
    @ViewBuilder
    private var directions: some View {
        if let query = booking.appointmentAddressSummary.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://maps.apple.com/?daddr=\(query)") {
            Link(destination: url) {
                DesignQuietAction(title: "Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityIdentifier("groomer.booking.directions")
        }
    }
}


// MARK: The review

/// What the owner said about the service, once it is over: the stars, their words, and the pet-fit notes (read only; the owner writes
/// them), or the note that it is awaited.
struct GroomerBookingReview: View {
    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Review", systemImage: "star.fill")
            if let review = booking.review {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .foregroundStyle(DesignTokens.Colors.ratingStar)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(review.ratingSummary)
                    Text(review.displayContent).designSupportingText()
                    ForEach(review.petFitOutcomes) { outcome in
                        GroomerFitOutcomeRow(outcome: outcome)
                    }
                    Text("Submitted \(GroomingRequestDateFormatting.displayString(from: review.createdAt))")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                .designCardBody()
                .accessibilityIdentifier("bookings.review.display")
            } else {
                BeckonLedgeNote(systemImage: "star", text: "Waiting for the customer to leave a review.")
            }
        }
        .accessibilityIdentifier("groomer.booking.review")
    }
}


/// One pet-fit note of a review: what it was about, and whether it went well.
private struct GroomerFitOutcomeRow: View {
    let outcome: BookingReviewPetFitOutcomeRecord

    private var isPositive: Bool { outcome.outcome == .positive }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(isPositive ? DesignTokens.Colors.statusSuccessText : DesignTokens.Colors.statusWarningText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(outcome.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(outcome.groupTitle)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(outcome.outcome.title)
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(isPositive ? DesignTokens.Colors.statusSuccessText : DesignTokens.Colors.statusWarningText)
        }
        .accessibilityElement(children: .combine)
    }
}
