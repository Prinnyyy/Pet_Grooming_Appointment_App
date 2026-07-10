import Foundation

struct GroomerNotification:
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    let groomerID: UUID
    let kind: GroomerNotificationKind
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
    let readAt: String?
    let relatedRequestID: UUID?
    let relatedBookingID: UUID?
    let relatedOfferID: UUID?

    var createdAtDate: Date {
        GroomingRequestDateFormatting.parsedDate(from: createdAt) ?? .distantPast
    }

    var createdAtSummary: String {
        GroomingRequestDateFormatting.displayString(from: createdAt)
    }

    nonisolated var route: GroomerNotificationRoute {
        switch kind {
        case .newMatch:
            .requests(requestID: relatedRequestID)
        case .offerAccepted, .bookingCancelledByCustomer:
            .bookings(bookingID: relatedBookingID)
        case .newMessage:
            .messages(bookingID: relatedBookingID)
        case .unknown:
            .requests(requestID: nil)
        }
    }

    func replacingReadState(
        isRead: Bool,
        readAt: String?
    ) -> GroomerNotification {
        GroomerNotification(
            id: id,
            groomerID: groomerID,
            kind: kind,
            title: title,
            body: body,
            isRead: isRead,
            createdAt: createdAt,
            readAt: readAt,
            relatedRequestID: relatedRequestID,
            relatedBookingID: relatedBookingID,
            relatedOfferID: relatedOfferID
        )
    }
}

nonisolated enum GroomerNotificationKind:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Sendable
{
    case newMatch = "new_match"
    case offerAccepted = "offer_accepted"
    case bookingCancelledByCustomer = "booking_cancelled_by_customer"
    case newMessage = "new_message"
    case unknown

    var defaultTitle: String {
        switch self {
        case .newMatch:
            "New request match"
        case .offerAccepted:
            "Offer accepted"
        case .bookingCancelledByCustomer:
            "Booking cancelled"
        case .newMessage:
            "New message"
        case .unknown:
            "Notification"
        }
    }

    var systemImage: String {
        switch self {
        case .newMatch:
            "tray.full.fill"
        case .offerAccepted:
            "checkmark.seal.fill"
        case .bookingCancelledByCustomer:
            "calendar.badge.xmark"
        case .newMessage:
            "message.fill"
        case .unknown:
            "bell.fill"
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

nonisolated enum GroomerNotificationRoute: Equatable, Sendable {
    case requests(requestID: UUID?)
    case offers(offerID: UUID?)
    case bookings(bookingID: UUID?)
    case messages(bookingID: UUID?)
}
