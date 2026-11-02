// Where a request stands for the groomer, and what the merged request page says about it (design). The request page and the offer
// page were two pages for one job: a request the groomer was matched to, the offer they made for it, and the booking it became. This
// file works out the one thing the page needs to know from whatever the stores hold, whichever way the page was opened: the stage
// (a new request to answer, an offer waiting, booked, closed), the path and bubble of the hero, what holds an answer back, what is
// wrong with a pending offer, and what happened.
import SwiftUI


/// What the page is opened on: a match the groomer was sent, or an offer the groomer made (which knows its request).
enum GroomerRequestTarget: Hashable {
    case match(UUID)
    case offer(UUID)
}


/// Everything the stores hold about one request, put together.
struct GroomerRequestSubject {
    /// The request with the groomer's match, alive: the groomer can answer it, withdraw its offer or dismiss it. Nil when the
    /// request is no longer readable (an old offer): the page is then the record of the offer.
    var matched: GroomerMatchedRequest?
    /// The offers list's record of the offer: it carries the booking, and the request itself when the match is gone.
    var item: GroomerOfferListItem?
    /// Every offer made for the request, oldest first.
    var history: [GroomerOffer] = []

    var request: GroomerMatchedGroomingRequest? { matched?.request ?? item?.request }
    var match: GroomerRequestMatch? { matched?.match }
    /// The latest offer: the open detail's when there is one (it follows what the groomer just did), else the list's.
    var offer: GroomerOffer? { matched?.offer ?? item?.offer }
    var booking: Booking? { item?.booking }

    /// The offers before the latest one.
    var earlierOffers: [GroomerOffer] { history.filter { $0.id != offer?.id } }
}


struct GroomerRequestStage {
    enum Kind: Equatable { case new, offered, booked, closed }

    /// What stops the groomer from answering a request that is open to them.
    enum Hold: Equatable {
        case checking, species, unsupported, unavailable

        /// What the page's needs card and the list's row both call it.
        var title: String {
            switch self {
            case .checking: "Checking this request"
            case .species: "Confirm the species first"
            case .unsupported: "Not possible in this version"
            case .unavailable: "No new offer possible"
            }
        }
    }

    /// What is wrong with an offer that is waiting.
    enum Problem: Equatable {
        case timingMissing, newOfferRequired, timeUnavailable, checking

        /// The groomer has to replace the offer: withdraw it and send a new one.
        var needsWithdrawal: Bool { self == .timingMissing || self == .newOfferRequired }

        /// Something is for the groomer to do (checking is only a wait).
        var needsAttention: Bool { self != .checking }

        /// What the page's needs card and the list's row both call it.
        var title: String {
            switch self {
            case .timingMissing: "Updated offer required"
            case .newOfferRequired: "New offer required"
            case .timeUnavailable: "Time unavailable"
            case .checking: "Checking this offer"
            }
        }
    }

    let kind: Kind
    let hold: Hold?
    let problem: Problem?
    let path: GroomingDetailHero.Path?
    let closed: GroomingDetailHero.Closed?
    /// "Closes in 23 hours", on a request that is open.
    let closes: String?
    /// The request closes within the day: the list says it in a chip.
    let closesSoon: Bool
    /// The offer form is there.
    let canAnswer: Bool
    let canWithdraw: Bool
    let canDismiss: Bool

    init(_ subject: GroomerRequestSubject, now: Date) {
        let offer = subject.offer
        let matched = subject.matched
        let display = offer?.evaluatedDisplayStatus(now: now)
        var offerStatus = offer?.status
        if case .status(let status)? = display { offerStatus = status }
        let requestStatus = subject.request?.status
        let isOpen = (requestStatus?.isOpenForOffers ?? true) && (subject.request.map {
            guard let expiry = GroomingRequestDateFormatting.parsedDate(from: $0.expiresAt) else { return false }
            return expiry > now
        } ?? true)

        let kind: Kind
        if offerStatus == .acceptedByCustomer {
            kind = .booked
        } else if offerStatus == .pending, isOpen {
            kind = .offered
        } else if let matched, isOpen, matched.match.status.isOfferable {
            kind = .new
        } else {
            kind = .closed
        }
        self.kind = kind

        var hold: Hold?
        if kind == .new, let matched, !matched.canCreateOffer {
            let evaluation = matched.match.eligibilityEvaluation
            if evaluation?.state == "pending" {
                hold = .checking
            } else if evaluation?.confirmationKeys.contains("service_species_configuration") == true {
                hold = .species
            } else if evaluation?.state == "assessment_required" {
                hold = .unsupported
            } else {
                hold = .unavailable
            }
        }
        self.hold = hold

        var problem: Problem?
        if kind == .offered, let offer {
            if offer.requiresTimingUpdate {
                problem = .timingMissing
            } else {
                switch display {
                case .newOfferRequired?: problem = .newOfferRequired
                case .timeUnavailable?: problem = .timeUnavailable
                case .checking?: problem = .checking
                default: break
                }
            }
        }
        self.problem = problem

        canAnswer = kind == .new && hold == nil && matched != nil
        canWithdraw = kind == .offered && matched != nil && offer?.status == .pending
        canDismiss = kind == .new && matched?.match.status.isDismissible == true

        let closing = kind == .new ? Self.closingLine(subject.request, now: now) : nil
        closes = closing?.text
        closesSoon = closing?.isSoon ?? false

        switch kind {
        case .new:
            let bubble: BeckonJourney.Bubble
            switch hold {
            case nil: bubble = .init(kind: .attention("Make an offer", systemImage: "tag.fill"), column: 1)
            case .checking?: bubble = .init(kind: .status("Checking", systemImage: "clock.fill"), column: 1)
            default: bubble = .init(kind: .attention("On hold", systemImage: "exclamationmark.circle.fill"), column: 1)
            }
            path = .init(stops: BeckonJourneyStop.groomerRequestPath, current: 1, fills: [1, 0], bubble: bubble,
                status: hold == nil ? "New request, waiting for your offer" : "New request, on hold")
            closed = nil
        case .offered:
            let needsAttention = problem?.needsAttention == true
            path = .init(stops: BeckonJourneyStop.groomerRequestPath, current: 2, fills: [1, 0.5],
                bubble: needsAttention
                    ? BeckonJourney.Bubble(kind: .attention("Needs attention", systemImage: "exclamationmark.circle.fill"), column: 1)
                    : BeckonJourney.Bubble(kind: .waitingFor("Customer to answer"), column: 2),
                status: needsAttention ? "Offer sent, needs attention" : "Offer sent, waiting for the customer")
            closed = nil
        case .booked:
            path = .init(stops: BeckonJourneyStop.groomerRequestPath, current: 3, fills: [1, 1],
                bubble: .init(kind: .booked, column: 2), status: "Booked")
            closed = nil
        case .closed:
            path = nil
            closed = .init(status: Self.closedStatus(subject, offerStatus: offerStatus, now: now),
                message: Self.closedMessage(subject, offerStatus: offerStatus, now: now))
        }
    }

    // MARK: Words

    private static func closingLine(_ request: GroomerMatchedGroomingRequest?, now: Date) -> (text: String, isSoon: Bool)? {
        guard let request, request.status.isOpenForOffers,
              let date = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt), date > now else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return ("Closes " + formatter.localizedString(for: date, relativeTo: now), date.timeIntervalSince(now) < 24 * 3600)
    }

    private static func closedStatus(_ subject: GroomerRequestSubject, offerStatus: GroomerOfferStatus?, now: Date) -> BeckonStatusPresentation {
        // An offer still marked pending on a request that closed says nothing: the request's own end does.
        if let offer = subject.offer, let offerStatus, offerStatus != .pending { return offer.statusPresentation(now: now) }
        if let match = subject.match, !match.status.isOfferable { return match.status.presentation }
        if let request = subject.request, request.status.isOpenForOffers {
            guard let expiry = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt) else { return .unavailable }
            if expiry <= now { return GroomingRequestStatus.expired.presentation }
        }
        return subject.request?.status.presentation ?? .unavailable
    }

    private static func closedMessage(_ subject: GroomerRequestSubject, offerStatus: GroomerOfferStatus?, now: Date) -> String {
        let requestStatus = subject.request?.status
        let elsewhere = requestStatus == .booked ? " The request was booked with another groomer." : ""
        switch offerStatus {
        case .declinedByCustomer?: return "The customer declined this offer." + elsewhere
        case .expired?: return "This offer expired before the customer answered." + elsewhere
        case .withdrawnByGroomer?: return "You withdrew this offer." + elsewhere
        default: break
        }
        if subject.match?.status == .dismissed { return "You dismissed this match." }
        if let request = subject.request, request.status.isOpenForOffers,
           let expiry = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt), expiry <= now {
            return "This request expired before it was booked."
        }
        switch requestStatus {
        case .cancelled?: return "The customer cancelled this request."
        case .expired?: return "This request expired before it was booked."
        case .booked?: return "The customer booked another groomer."
        default: return "This request is no longer available."
        }
    }
}


// MARK: The offers, in the order the groomer works through them

/// The Offers list as the flow runs: what needs the groomer, what waits for the customer, what became a booking, what is over. Each
/// offer is placed by the stage the request page would show it at, so a row and its page can never disagree.
struct GroomerOfferGroups {
    struct Entry: Identifiable {
        let item: GroomerOfferListItem
        let stage: GroomerRequestStage

        var id: UUID { item.id }
    }

    private(set) var attention: [Entry] = []
    private(set) var pending: [Entry] = []
    private(set) var booked: [Entry] = []
    private(set) var earlier: [Entry] = []

    init(_ items: [GroomerOfferListItem], now: Date) {
        for item in items {
            let subject = GroomerRequestSubject(matched: nil, item: item, history: [item.offer])
            let entry = Entry(item: item, stage: GroomerRequestStage(subject, now: now))
            switch entry.stage.kind {
            case .offered:
                if entry.stage.problem?.needsAttention == true { attention.append(entry) } else { pending.append(entry) }
            case .booked:
                booked.append(entry)
            case .new, .closed:
                earlier.append(entry)
            }
        }
    }
}


// MARK: What happened

extension GroomingTimelineEntry {
    /// What happened to a request the groomer was matched to, from the match to the booking, each with its time when there is one.
    @MainActor
    static func groomerRequest(_ subject: GroomerRequestSubject) -> [GroomingTimelineEntry] {
        guard let request = subject.request else { return [] }
        let zone = request.preferenceTimeZoneIdentifier ?? subject.offer?.serviceTimeZoneIdentifier
        func when(_ raw: String?) -> String? {
            raw.map { GroomingRequestDateFormatting.displayString(from: $0, serviceTimeZoneIdentifier: zone) }
        }
        var entries: [GroomingTimelineEntry] = []
        if let match = subject.match {
            entries.append(.init(id: "matched", systemImage: "sparkles", title: "Matched", detail: when(match.createdAt),
                note: request.distributionSourceTitle))
            if let viewed = match.viewedAt {
                entries.append(.init(id: "viewed", systemImage: "eye.fill", title: "You viewed it", detail: when(viewed)))
            }
        } else {
            entries.append(.init(id: "posted", systemImage: "paperplane.fill", title: "Request posted", detail: when(request.createdAt)))
        }
        for offer in subject.history {
            entries.append(.init(id: "offer-\(offer.id)", systemImage: "tag.fill", title: "Offer sent", detail: when(offer.createdAt),
                note: offer.priceSummary))
            switch offer.status {
            case .withdrawnByGroomer:
                entries.append(.init(id: "withdrawn-\(offer.id)", systemImage: "arrow.uturn.backward.circle", title: "Offer withdrawn",
                    detail: when(offer.withdrawnAt ?? offer.updatedAt)))
            case .declinedByCustomer:
                entries.append(.init(id: "declined-\(offer.id)", systemImage: "xmark.circle", title: "Offer declined", detail: when(offer.updatedAt)))
            case .expired:
                entries.append(.init(id: "expired-\(offer.id)", systemImage: "clock.badge.xmark", title: "Offer expired", detail: when(offer.updatedAt)))
            case .acceptedByCustomer:
                entries.append(.init(id: "accepted-\(offer.id)", systemImage: "checkmark.circle", title: "Offer accepted", detail: when(offer.updatedAt)))
            case .pending, .unknown:
                break
            }
        }
        if let booking = subject.booking {
            entries.append(.init(id: "booked", systemImage: "calendar", title: "Booked", detail: when(booking.createdAt),
                note: "#\(booking.referenceCode)"))
        }
        if let dismissed = subject.match?.dismissedAt {
            entries.append(.init(id: "dismissed", systemImage: "xmark.circle", title: "You dismissed it", detail: when(dismissed)))
        }
        return entries
    }
}
