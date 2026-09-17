import Foundation

nonisolated enum BookingRescheduleAction: String, Codable, Identifiable, Sendable {
    case propose, accept, reject, withdraw
    var id: String { rawValue }
    var title: String {
        switch self {
        case .propose: "Propose New Time"
        case .accept: "Accept New Time"
        case .reject: "Keep Original Time"
        case .withdraw: "Withdraw Time Change"
        }
    }
}

nonisolated enum BookingRescheduleStatus: String, Codable, Sendable {
    case pending, accepted, rejected, withdrawn, expired, invalidated
    var title: String {
        switch self {
        case .pending: "Awaiting Time Confirmation"
        case .accepted: "Time Change Accepted"
        case .rejected: "Time Change Declined"
        case .withdrawn: "Time Change Withdrawn"
        case .expired: "Time Change Expired"
        case .invalidated: "Booking Changed"
        }
    }
}

struct BookingRescheduleProposal: Decodable, Identifiable, Sendable {
    let id: UUID
    let bookingID: UUID
    let baseRevision: UUID
    let initiatorID: UUID
    let proposedStart: String
    let proposedEnd: String
    let previousAgreement: ServiceAgreement
    let proposedAgreement: ServiceAgreement
    let status: BookingRescheduleStatus
    let effectiveStatus: BookingRescheduleStatus
    let expiresAt: String
    private enum CodingKeys: String, CodingKey {
        case id, status
        case bookingID = "booking_id", baseRevision = "base_revision", initiatorID = "initiator_id"
        case proposedStart = "proposed_start", proposedEnd = "proposed_end"
        case previousAgreement = "previous_agreement", proposedAgreement = "proposed_agreement"
        case effectiveStatus = "effective_status", expiresAt = "expires_at"
    }

    func currentStatus(for booking: Booking, now: Date = Date()) -> BookingRescheduleStatus {
        guard effectiveStatus == .pending else { return effectiveStatus }
        guard booking.id == bookingID, booking.fulfillment?.revision == baseRevision,
              booking.status == .confirmed, booking.fulfillment?.phase == .scheduled else { return .invalidated }
        guard let deadline = GroomingRequestDateFormatting.parsedDate(from: expiresAt),
              let originalStart = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
              now < min(deadline, originalStart) else { return .expired }
        return .pending
    }

    func actions(for booking: Booking, participantID: UUID, now: Date = Date()) -> [BookingRescheduleAction] {
        guard [booking.customerID, booking.groomerID].contains(participantID), currentStatus(for: booking, now: now) == .pending else { return [] }
        return initiatorID == participantID ? [.withdraw] : [.accept, .reject]
    }
}

nonisolated struct BookingRescheduleOperation: Codable, Equatable, Sendable {
    let id: UUID
    let bookingID: UUID
    let expectedRevision: UUID
    let proposalID: UUID
    let action: BookingRescheduleAction
    let newStart: String?
}

nonisolated struct BookingRescheduleReceipt: Decodable, Sendable {
    let operationID: UUID
    let bookingID: UUID
    let proposalID: UUID
    let action: BookingRescheduleAction
    let resultRevision: UUID
    private enum CodingKeys: String, CodingKey {
        case action
        case operationID = "operation_id", bookingID = "booking_id", proposalID = "proposal_id", resultRevision = "result_revision"
    }
}

struct BookingRescheduleResult: Sendable {
    let booking: Booking
    let proposal: BookingRescheduleProposal?
    let receipt: BookingRescheduleReceipt?
}

extension Booking {
    nonisolated func canProposeReschedule(now: Date = Date()) -> Bool {
        status == .confirmed && fulfillment?.phase == .scheduled && agreementSnapshot?.isSupported == true
            && appliedTimingBuffers != nil && serviceTimeZoneIdentifier != nil
            && (GroomingRequestDateFormatting.parsedDate(from: scheduledStart).map { $0 > now } ?? false)
    }

    nonisolated func applyingReschedule(_ current: Booking) -> Booking {
        Booking(id: current.id, requestID: current.requestID, offerID: current.offerID,
            customerID: current.customerID, groomerID: current.groomerID,
            scheduledStart: current.scheduledStart, scheduledEnd: current.scheduledEnd,
            priceEstimate: current.priceEstimate, status: current.status,
            cancelledBy: current.cancelledBy, cancelledAt: current.cancelledAt,
            completedAt: current.completedAt, completedBy: current.completedBy,
            createdAt: current.createdAt, updatedAt: current.updatedAt, review: current.review ?? review,
            serviceType: current.serviceType, requestPetSnapshot: current.requestPetSnapshot,
            groomerBusinessName: current.groomerBusinessName ?? groomerBusinessName,
            groomerAvatarPhotoData: current.groomerAvatarPhotoData ?? groomerAvatarPhotoData,
            groomerBaseStreetAddress: groomerBaseStreetAddress, groomerBaseCity: groomerBaseCity,
            groomerBaseState: groomerBaseState, groomerBaseZipCode: groomerBaseZipCode,
            locationMode: current.locationMode, customerStreetAddress: customerStreetAddress,
            customerCity: customerCity, customerState: customerState, customerZipCode: customerZipCode,
            appliedTimingBuffers: current.appliedTimingBuffers, serviceTimeZoneIdentifier: current.serviceTimeZoneIdentifier,
            scheduleTimeZoneIdentifier: current.scheduleTimeZoneIdentifier, occupiedStart: current.occupiedStart,
            occupiedEnd: current.occupiedEnd, agreementSnapshot: current.agreementSnapshot, fulfillment: current.fulfillment)
    }
}
