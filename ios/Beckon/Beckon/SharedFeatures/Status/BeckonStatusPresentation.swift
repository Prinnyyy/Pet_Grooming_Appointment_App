import SwiftUI

nonisolated struct BeckonStatusPresentation: Equatable, Sendable {
    let title: String
    let systemImage: String
    let tone: BeckonStatusChip.Tone
}

extension BeckonStatusChip {
    init(_ presentation: BeckonStatusPresentation) {
        self.init(presentation.title, systemImage: presentation.systemImage, tone: presentation.tone)
    }
}

extension BeckonStatusPresentation {
    static let verified = Self(title: "Verified", systemImage: "checkmark.seal.fill", tone: .success)
    static let draft = Self(title: "Draft", systemImage: "pencil", tone: .info)
    static let petRequired = Self(title: "Add a pet before continuing", systemImage: "pawprint", tone: .warning)
    static let unavailable = Self(title: "Unavailable", systemImage: "xmark.circle", tone: .neutral)

    static func offersToReview(count: Int?) -> Self {
        let title = count.map { "\($0) offer\($0 == 1 ? "" : "s") to review" } ?? "Offers ready to review"
        return Self(title: title, systemImage: "tag", tone: .warning)
    }

    static func rating(average: Double, count: Int) -> Self {
        Self(title: "\(average.formatted(.number.precision(.fractionLength(2)))) from \(count) review\(count == 1 ? "" : "s")",
             systemImage: "star.fill", tone: .neutral)
    }

    static func acceptance(offer: GroomerOfferStatus, request: GroomingRequestStatus) -> Self {
        if offer == .acceptedByCustomer { return offer.presentation }
        if request == .booked { return request.presentation }
        return .unavailable
    }
}

extension GroomerOffer {
    func statusPresentation(now: Date = Date()) -> BeckonStatusPresentation {
        evaluatedDisplayStatus(now: now).presentation
    }
}

extension GroomerOfferDisplayStatus {
    var presentation: BeckonStatusPresentation {
        switch self {
        case .status(let status): status.presentation
        case .checking: .init(title: title, systemImage: "clock", tone: .info)
        case .newOfferRequired: .init(title: title, systemImage: "arrow.clockwise", tone: .warning)
        case .timeUnavailable: .init(title: title, systemImage: "calendar.badge.exclamationmark", tone: .warning)
        }
    }
}

extension GroomingRequestStatus {
    var presentation: BeckonStatusPresentation {
        switch self {
        case .open: .init(title: title, systemImage: "clock", tone: .info)
        case .hasOffers: .init(title: title, systemImage: "tag", tone: .warning)
        case .booked: .init(title: title, systemImage: "checkmark.circle", tone: .success)
        case .cancelled: .init(title: title, systemImage: "xmark.circle", tone: .neutral)
        case .expired: .init(title: title, systemImage: "hourglass", tone: .neutral)
        case .unknown: .init(title: title, systemImage: "questionmark.circle", tone: .neutral)
        }
    }
}

extension RequestMatchStatus {
    var presentation: BeckonStatusPresentation {
        switch self {
        case .visible, .viewed: .init(title: title, systemImage: "sparkles", tone: .info)
        case .offered: .init(title: title, systemImage: "clock", tone: .warning)
        case .dismissed: .init(title: title, systemImage: "xmark.circle", tone: .neutral)
        case .hidden: .init(title: title, systemImage: "minus.circle", tone: .neutral)
        case .expired: .init(title: title, systemImage: "hourglass", tone: .neutral)
        case .unknown: .init(title: title, systemImage: "questionmark.circle", tone: .neutral)
        }
    }
}

extension GroomerOfferStatus {
    var presentation: BeckonStatusPresentation {
        switch self {
        case .pending: .init(title: title, systemImage: "clock", tone: .warning)
        case .acceptedByCustomer: .init(title: title, systemImage: "checkmark.circle", tone: .success)
        case .declinedByCustomer: .init(title: title, systemImage: "xmark.circle", tone: .neutral)
        case .withdrawnByGroomer: .init(title: title, systemImage: "arrow.uturn.backward", tone: .neutral)
        case .expired: .init(title: title, systemImage: "hourglass", tone: .neutral)
        case .unknown: .init(title: title, systemImage: "questionmark.circle", tone: .neutral)
        }
    }
}

extension BookingStatus {
    var presentation: BeckonStatusPresentation {
        switch self {
        case .confirmed: .init(title: title, systemImage: "calendar.badge.checkmark", tone: .info)
        case .completed: .init(title: title, systemImage: "checkmark.circle", tone: .success)
        case .unfulfilled: .init(title: "Service not confirmed", systemImage: "minus.circle", tone: .neutral)
        case .cancelledByCustomer, .cancelledByGroomer: .init(title: title, systemImage: "xmark.circle", tone: .neutral)
        case .unknown: .init(title: title, systemImage: "questionmark.circle", tone: .neutral)
        }
    }
}
