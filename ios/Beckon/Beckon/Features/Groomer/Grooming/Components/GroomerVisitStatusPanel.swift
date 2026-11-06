import SwiftUI

struct GroomerVisitNeedsActionPanel<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroomerVisitExplanationPanel(title: title, symbol: symbol, fill: GroomerVisitStatusTone.action.colors.fill,
            iconColor: GroomerVisitStatusTone.action.colors.icon, textColor: GroomerVisitStatusTone.action.colors.text, content: content)
    }
}

struct GroomerVisitStatusContentPanel<Content: View>: View {
    let title: String
    let tone: GroomerVisitStatusTone
    @ViewBuilder let content: () -> Content

    var body: some View {
        let colors = tone.colors
        GroomerVisitExplanationPanel(title: title, symbol: "info.circle", fill: colors.fill,
            iconColor: colors.icon, textColor: colors.text, content: content)
    }
}

struct GroomerVisitStatusInfoPanel: View {
    let title: String
    let message: String
    var waitingFor: BeckonRole? = nil
    var tone: GroomerVisitStatusTone = .quiet

    var body: some View {
        let colors = (waitingFor.map { GroomerVisitStatusTone.waitingFor($0) } ?? tone).colors
        GroomerVisitExplanationPanel(title: title, symbol: "info.circle", fill: colors.fill,
            iconColor: colors.icon, textColor: colors.text) {
            Text(message).font(DesignTokens.Typography.Expressive.supporting)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One state supplies the list note and decides whether its detail needs an explanation.
struct GroomerVisitCardStatus {
    let title: String
    let message: String
    let symbol: String
    var listTitle: String? = nil
    var waitingFor: BeckonRole? = nil
    var tone: GroomerVisitStatusTone = .quiet
    var showsExplanation = true
    var resolvedTone: GroomerVisitStatusTone { waitingFor.map { .waitingFor($0) } ?? tone }

    var note: GroomerRequestRowContent.Note {
        .init(text: listTitle ?? title, systemImage: symbol, tone: .calm)
    }

    static let slotBooked = Self(title: "Request still open",
        message: "Your offer closed automatically when another appointment was booked for this time.",
        symbol: "calendar", listTitle: "Time slot booked")

    static func offer(_ subject: GroomerRequestSubject, stage: GroomerRequestStage, linked: Bool) -> Self? {
        if subject.offer?.quoteEvaluation?.reason == "time_slot_booked" { return .slotBooked }
        if stage.kind == .new {
            switch stage.hold {
            case .checking:
                return .init(title: "Checking request", message: "Service eligibility and availability are being checked.", symbol: "clock.fill", tone: .checking)
            case .unsupported, .unavailable:
                return .init(title: "Offer unavailable", message: "You cannot send an offer for this request right now.", symbol: "lock.fill")
            default: return nil
            }
        }
        if stage.kind == .booked {
            return linked ? .init(title: "Now in Bookings", message: "Offer accepted. Tap View booking to manage the appointment.", symbol: "calendar", tone: .success)
                : .init(title: "Preparing booking", message: "Your customer accepted this offer. The appointment details are being retrieved.", symbol: "calendar", tone: .success)
        }
        if let closed = stage.closed {
            let elsewhere = subject.offer?.status == .pending && subject.request?.status == .booked
            return .init(title: elsewhere ? "Booked elsewhere" : closed.status.title,
                         message: closed.message, symbol: closed.status.systemImage,
                         tone: closed.status == GroomerOfferStatus.declinedByCustomer.presentation ? .declined : .quiet)
        }
        guard stage.kind == .offered, let offer = subject.offer else { return nil }
        if let problem = stage.problem {
            return problem == .checking ? .init(title: "Checking offer",
                message: "The offer details and your availability are being checked.", symbol: "clock", tone: .checking) : nil
        }
        return .init(title: "Awaiting reply", message: "Your customer can review the offer before it expires.",
                     symbol: "ellipsis", listTitle: awaitingReplyTitle(expiresAt: offer.expiresAt, zone: offer.serviceTimeZoneIdentifier), waitingFor: .customer, showsExplanation: false)
    }

    private static func awaitingReplyTitle(expiresAt: String, zone: String?) -> String {
        guard let deadline = BeckonWhen(start: expiresAt, end: nil, zoneIdentifier: zone)?.short else {
            return "Awaiting reply"
        }
        return "Awaiting reply · Expires " + deadline
    }

    static func booking(_ booking: Booking, stage: GroomerBookingStage, proposal: BookingRescheduleProposal? = nil, now: Date = .now) -> Self {
        if !stage.isClosed && !stage.isFinished, let proposal,
           proposal.currentStatus(for: booking, now: now) == .pending, proposal.initiatorID == booking.groomerID {
            return .init(title: "Time change sent", message: "Your customer is reviewing the proposed time. The current appointment stays booked until accepted.",
                         symbol: "ellipsis", listTitle: awaitingReplyTitle(expiresAt: proposal.expiresAt,
                            zone: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier), waitingFor: .customer)
        }
        if stage.isFinished && booking.review == nil {
            return .init(title: "Awaiting review", message: "The appointment is finished. Your customer can now leave a review.",
                         symbol: "ellipsis", listTitle: "Awaiting review", waitingFor: .customer, showsExplanation: false)
        }
        let title: String
        if stage.isClosed { title = booking.status.title }
        else if stage.isFinished { title = "Review received" }
        else if booking.fulfillment?.phase == .inService { title = "In service" }
        else { title = "Appointment booked" }
        let message: String
        if let closed = stage.closed { message = closed.message }
        else if stage.isFinished {
            message = booking.review == nil ? "The appointment has ended. Your customer can now leave a review." : "Your customer has reviewed this appointment. Open Review to see their feedback."
        } else if booking.fulfillment?.phase == .inService {
            message = "This appointment is in progress. The booked time and service details are shown below."

        } else {
            message = "The appointment is booked for " + booking.scheduledTimeSummary + "."
        }
        return .init(title: title, message: message, symbol: stage.isFinished ? "star.fill" : booking.status.presentation.systemImage,
            tone: stage.isClosed ? .quiet : stage.isFinished ? .success : booking.fulfillment?.phase == .inService ? .ready : .quiet,
            showsExplanation: stage.isClosed)
    }
}

/// Presentation-only shortening; decision strings and action routing remain unchanged.
struct GroomerVisitExplanationTitle: View {
    let title: String

    private var compactTitle: String {
        switch title {
        case "Customer requested a time change": "Time change request"
        case "You proposed a new time": "Time change sent"
        case "Confirm accepted species", "Confirm the species first": "Confirm pet types"
        case "Timing details missing": "Missing timing"
        case "Review service outcome": "Review outcome"
        case "Cancelled by customer": "Customer cancelled"
        case "Cancelled by groomer": "You cancelled"
        case "Declined by customer": "Customer declined"
        case "Withdrawn by groomer": "Offer withdrawn"
        default: title
        }
    }

    var body: some View {
        Text(compactTitle)
            .font(DesignTokens.Typography.Expressive.emphasis)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(title)
    }
}

private struct GroomerVisitExplanationPanel<Content: View>: View {
    let title: String
    let symbol: String
    let fill: Color
    var iconColor: Color? = nil
    var textColor: Color? = nil
    @ViewBuilder let content: () -> Content

    @ScaledMetric(relativeTo: .subheadline) private var titleLineHeight: CGFloat = 18

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: symbol)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(iconColor ?? DesignTokens.Colors.textPrimary)
                .frame(width: 20, height: titleLineHeight)
            VStack(alignment: .leading, spacing: 6) {
                GroomerVisitExplanationTitle(title: title)
                content()
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(textColor ?? DesignTokens.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(fill, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset))
    }
}

enum GroomerVisitOfferReplacement {
    case missingTiming, outdatedTerms

    init?(_ problem: GroomerRequestStage.Problem?) {
        switch problem {
        case .timingMissing: self = .missingTiming
        case .newOfferRequired: self = .outdatedTerms
        default: return nil
        }
    }

    var reason: String {
        switch self {
        case .missingTiming: "Timing details missing"
        case .outdatedTerms: "Offer terms outdated"
        }
    }

    var instructions: String {
        switch self {
        case .missingTiming: "Withdraw this offer, confirm the service time, then send a new offer."
        case .outdatedTerms: "Withdraw this offer, review the current request, then send an updated offer."
        }
    }
}
