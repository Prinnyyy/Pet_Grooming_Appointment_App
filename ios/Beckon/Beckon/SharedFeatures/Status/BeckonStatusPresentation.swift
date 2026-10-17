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
