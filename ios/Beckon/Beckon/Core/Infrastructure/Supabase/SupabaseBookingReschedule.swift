import Foundation

struct SupabaseRescheduleResponse: Decodable {
    let booking: SupabaseBookingRow
    let proposal: BookingRescheduleProposal?
    let receipt: BookingRescheduleReceipt?
    var result: BookingRescheduleResult {
        BookingRescheduleResult(booking: booking.booking, proposal: proposal, receipt: receipt)
    }
}

struct SupabaseRescheduleLookup: Encodable {
    let bookingID: UUID
    private enum CodingKeys: String, CodingKey { case bookingID = "p_booking_id" }
}

struct SupabaseRescheduleParameters: Encodable {
    let operation: BookingRescheduleOperation
    private enum CodingKeys: String, CodingKey {
        case bookingID = "p_booking_id", expectedRevision = "p_expected_revision", operationID = "p_operation_id"
        case proposalID = "p_proposal_id", action = "p_action", newStart = "p_new_start"
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation.bookingID, forKey: .bookingID)
        try container.encode(operation.expectedRevision, forKey: .expectedRevision)
        try container.encode(operation.id, forKey: .operationID)
        try container.encode(operation.proposalID, forKey: .proposalID)
        try container.encode(operation.action.rawValue, forKey: .action)
        try container.encode(operation.newStart, forKey: .newStart)
    }
}
