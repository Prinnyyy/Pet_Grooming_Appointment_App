import Foundation

nonisolated enum GroomerRequestsSegment: String, CaseIterable, Identifiable, Equatable, Sendable {
    case matches
    case offers

    var id: Self { self }

    var title: String {
        switch self {
        case .matches:
            "Matches"
        case .offers:
            "Offers"
        }
    }

    var accessibilityIdentifier: String {
        "groomer.requests.segment.\(rawValue)"
    }

    func count(matches: Int, offers: Int) -> Int {
        switch self {
        case .matches:
            matches
        case .offers:
            offers
        }
    }
}

nonisolated struct GroomerRequestsRoute: Equatable, Sendable {
    let segment: GroomerRequestsSegment
    let requestID: UUID?
    let offerID: UUID?

    static let matches = GroomerRequestsRoute(
        segment: .matches,
        requestID: nil,
        offerID: nil
    )
    static let offers = GroomerRequestsRoute(
        segment: .offers,
        requestID: nil,
        offerID: nil
    )

    init(
        segment: GroomerRequestsSegment,
        requestID: UUID?,
        offerID: UUID?
    ) {
        self.segment = segment
        self.requestID = requestID
        self.offerID = offerID
    }

    init?(notificationRoute: GroomerNotificationRoute) {
        switch notificationRoute {
        case let .requests(requestID):
            self = GroomerRequestsRoute(
                segment: .matches,
                requestID: requestID,
                offerID: nil
            )
        case let .offers(offerID):
            self = GroomerRequestsRoute(
                segment: .offers,
                requestID: nil,
                offerID: offerID
            )
        case .bookings, .messages:
            return nil
        }
    }
}
