import Foundation

struct CustomerRequestSummaryPresentation {
    let title: String
    let initial: String
    let time: BeckonDateTimePresentation
    let status: BeckonStatusPresentation
    let step: Int?

    init(card: CustomerRequestActionCardItem) {
        title = card.request.displayTitle
        initial = card.request.petSnapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() } ?? "?"
        time = card.handoff?.booking.scheduledTimePresentation ?? card.request.preferredTimePresentation
        let requestStatus = card.request.status
        let confirmed = card.handoff?.booking.status == .confirmed
        if confirmed {
            step = 3
            status = GroomingRequestStatus.booked.presentation
        } else {
            step = switch requestStatus {
            case .open: 1
            case .hasOffers: 2
            case .booked: 3
            case .cancelled, .expired, .unknown: nil
            }
            status = requestStatus == .hasOffers
                ? .offersToReview(count: card.loadedOfferCount) : requestStatus.presentation
        }
    }

    var progressSummary: String? {
        switch step {
        case 1: "Step 1 of 3: request posted"
        case 2: "Step 2 of 3: offers received"
        case 3: "Step 3 of 3: booked"
        default: nil
        }
    }

    var accessibilityLabel: String {
        [title, time.accessibilityLabel, progressSummary, status.title, "Review"]
            .compactMap { $0 }.joined(separator: ". ")
    }
}
