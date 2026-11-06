import SwiftUI

struct GroomerVisitJourneyCallout {
    let text: String
    let symbol: String?
    let tone: Tone

    init(_ text: String, _ symbol: String?, _ tone: Tone) {
        self.text = text
        self.symbol = symbol
        self.tone = tone
    }

    func face(width: CGFloat, trailingRoom: CGFloat) -> some View {
        let colors = tone.colors
        return GroomerVisitJourneyBubbleFace(face: colors.fill, edge: colors.edge, shift: 0, leadingRoom: width - trailingRoom, trailingRoom: trailingRoom) { time in
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let symbol {
                    Image(systemName: symbol).foregroundStyle(colors.icon)
                } else {
                    GroomerVisitBouncingDots(time: time, color: colors.icon)
                }
                Text(text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(DesignTokens.Typography.Expressive.caption)
            .foregroundStyle(colors.text)
            .frame(maxWidth: max(0, width - 2 * DesignTokens.Spacing.md))
        }
        .fixedSize()
    }

    func track(stops: [BeckonJourneyStop], current: Int, fills: [Double], column index: Int) -> some View {
        BeckonJourney(stops: stops, current: current, fills: fills)
            .overlay(alignment: .top) {
                GeometryReader { box in
                    let column = box.size.width / CGFloat(stops.count)
                    face(width: box.size.width, trailingRoom: box.size.width - column * (CGFloat(index) + 0.5))
                        .frame(width: column)
                        .offset(x: CGFloat(index) * column)
                }
                .allowsHitTesting(false)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    static func request(_ subject: GroomerRequestSubject, stage: GroomerRequestStage, now: Date) -> Self {
        switch stage.kind {
        case .new:
            switch stage.hold {
            case nil:
                subject.request?.invitationState == .awaitingResponse
                    ? .init("Reply to invitation", "envelope.fill", .action)
                    : .init(subject.offer == nil ? "Make an offer" : "Make a new offer", "tag.fill", .ready)
            case .checking: .init("Checking request", "clock.fill", .checking)
            case .species: .init("Confirm pet types", "pawprint.fill", .action)
            case .unsupported, .unavailable: .init("Can’t send an offer", "lock.fill", .quiet)
            }
        case .offered:
            switch stage.problem {
            case nil: .init("Waiting for customer", nil, .waitingFor(.customer))
            case .checking: .init("Checking offer", "clock.fill", .checking)
            case .timingMissing, .newOfferRequired: .init("New offer needed", "arrow.triangle.2.circlepath", .action)
            case .timeUnavailable: .init("Review offer time", "calendar.badge.exclamationmark", .action)
            }
        case .booked: .init("Offer accepted", "checkmark.seal.fill", .success)
        case .closed: closedRequest(subject, stage: stage, now: now)
        }
    }

    private static func closedRequest(_ subject: GroomerRequestSubject, stage: GroomerRequestStage, now: Date) -> Self {
        if subject.offer?.quoteEvaluation?.reason == "time_slot_booked" {
            return .init("Time slot booked", "calendar", .quiet)
        }
        switch stage.closed?.status {
        case GroomerOfferStatus.declinedByCustomer.presentation:
            return .init("Customer declined", "xmark.circle.fill", .declined)
        case GroomerOfferStatus.withdrawnByGroomer.presentation:
            return .init("Withdrawn by you", "arrow.uturn.backward", .quiet)
        case RequestMatchStatus.dismissed.presentation:
            return .init("Dismissed by you", "minus.circle", .quiet)
        case GroomingRequestStatus.cancelled.presentation:
            return .init("Customer cancelled", "person.fill", .quiet)
        case GroomingRequestStatus.booked.presentation:
            return .init("Booked elsewhere", "calendar", .quiet)
        case GroomerOfferStatus.expired.presentation:
            // The stage uses the same expiry chip for three different records. Identify which one reached its deadline.
            let text: String
            if case .status(.expired)? = subject.offer?.evaluatedDisplayStatus(now: now) {
                text = "Offer expired"
            } else if subject.request?.status == .expired || subject.match?.status != .expired {
                text = "Request expired"
            } else {
                text = "Match expired"
            }
            return .init(text, "hourglass", .quiet)
        case RequestMatchStatus.hidden.presentation:
            return .init("Match unavailable", "eye.slash", .quiet)
        default:
            return .init("Status unavailable", "questionmark.circle", .quiet)
        }
    }

    static func booking(_ kind: BeckonJourneyCallout.Kind) -> GroomerVisitJourneyCallout? {
        switch kind {
        case let .countdown(text): return .init(text, "clock.fill", .quiet)
        case .status("In service", _): return .init("In service", "scissors", .ready)
        case .waitingFor("Awaiting completion"): return .init("Finish appointment", "checkmark.circle.fill", .action)
        case .waitingFor("Awaiting review"): return .init("Awaiting review", nil, .waitingFor(.customer))
        case .status("Reviewed", _): return .init("Review received", "star.fill", .success)
        case .status("By customer", _): return .init("Customer cancelled", "person.fill", .quiet)
        case .status("By groomer", _): return .init("Cancelled by you", "arrow.uturn.backward", .quiet)
        default: return nil
        }
    }

    typealias Tone = GroomerVisitStatusTone
}
