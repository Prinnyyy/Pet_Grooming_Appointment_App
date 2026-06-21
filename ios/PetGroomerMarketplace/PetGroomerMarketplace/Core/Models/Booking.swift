import Foundation

struct Booking: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let offerID: UUID
    let customerID: UUID
    let groomerID: UUID
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let status: BookingStatus
    let cancelledBy: UUID?
    let cancelledAt: String?
    let createdAt: String
    let updatedAt: String

    nonisolated var priceSummary: String {
        priceEstimate.formatted(
            .currency(code: "USD").precision(.fractionLength(2))
        )
    }

    nonisolated var scheduledTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: scheduledStart)) – \(GroomingRequestDateFormatting.displayString(from: scheduledEnd))"
    }

    nonisolated var referenceCode: String {
        Self.referenceCode(for: id)
    }

    nonisolated var requestReferenceCode: String {
        Self.referenceCode(for: requestID)
    }

    nonisolated var offerReferenceCode: String {
        Self.referenceCode(for: offerID)
    }

    nonisolated var canCancel: Bool {
        status == .confirmed
    }

    nonisolated func participantReferenceCode(for role: UserRole) -> String {
        switch role {
        case .customer:
            Self.referenceCode(for: groomerID)
        case .groomer:
            Self.referenceCode(for: customerID)
        }
    }

    nonisolated func participantSummary(for role: UserRole) -> String {
        switch role {
        case .customer:
            "Groomer ref \(participantReferenceCode(for: role))"
        case .groomer:
            "Customer ref \(participantReferenceCode(for: role))"
        }
    }

    nonisolated func replacing(
        status: BookingStatus,
        cancelledBy: UUID?,
        cancelledAt: String?
    ) -> Booking {
        Booking(
            id: id,
            requestID: requestID,
            offerID: offerID,
            customerID: customerID,
            groomerID: groomerID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            priceEstimate: priceEstimate,
            status: status,
            cancelledBy: cancelledBy,
            cancelledAt: cancelledAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    nonisolated private static func referenceCode(for id: UUID) -> String {
        String(id.uuidString.prefix(8)).uppercased()
    }
}

nonisolated enum BookingStatus:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case confirmed
    case completed
    case cancelledByCustomer = "cancelled_by_customer"
    case cancelledByGroomer = "cancelled_by_groomer"

    var title: String {
        switch self {
        case .confirmed:
            "Confirmed"
        case .completed:
            "Completed"
        case .cancelledByCustomer:
            "Cancelled by customer"
        case .cancelledByGroomer:
            "Cancelled by groomer"
        }
    }

    var isCancellation: Bool {
        switch self {
        case .cancelledByCustomer, .cancelledByGroomer:
            true
        case .confirmed, .completed:
            false
        }
    }
}

struct AcceptGroomerOfferResult: Equatable, Sendable {
    let bookingID: UUID
    let conversationID: UUID
    let requestID: UUID
    let offerID: UUID
    let bookingStatus: BookingStatus
    let offerStatus: GroomerOfferStatus
    let requestStatus: GroomingRequestStatus
}

struct CancelBookingResult: Equatable, Sendable {
    let bookingID: UUID
    let bookingStatus: BookingStatus
    let cancelledTimestamp: String?
    let cancelledBy: UUID?
}
