import Foundation

struct SupabaseFulfillmentResponse: Decodable {
    let receipt: BookingFulfillmentReceipt
    let booking: SupabaseBookingRow
    let replayed: Bool
    var result: BookingFulfillmentResult {
        BookingFulfillmentResult(receipt: receipt, booking: booking.booking, replayed: replayed)
    }
}

struct SupabaseFulfillmentLookup: Encodable {
    let operationID: UUID
    private enum CodingKeys: String, CodingKey { case operationID = "p_operation_id" }
}

struct SupabaseFulfillmentParameters: Encodable {
    let operation: BookingFulfillmentOperation
    private enum CodingKeys: String, CodingKey {
        case bookingID = "p_booking_id"
        case expectedRevision = "p_expected_revision"
        case operationID = "p_operation_id"
        case action = "p_action"
        case note = "p_note"
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation.bookingID, forKey: .bookingID)
        try container.encode(operation.expectedRevision, forKey: .expectedRevision)
        try container.encode(operation.id, forKey: .operationID)
        try container.encode(operation.action.rawValue, forKey: .action)
        try container.encode(operation.note, forKey: .note)
    }
}

struct SupabaseBookingRow: Decodable {
    static let fulfillmentColumns = "fulfillment_revision,fulfillment_phase,fulfillment_basis,actual_started_at,actual_ended_at,pet_release_at,resource_release_at,reported_outcome,reported_by,reported_at,report_previous_phase,report_note"
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
    let completedAt: String?
    let completedBy: UUID?
    let createdAt: String
    let updatedAt: String
    let appliedTimingBuffers: GroomingTimingBuffers?
    let serviceTimeZoneIdentifier: String?
    let scheduleTimeZoneIdentifier: String?
    let occupiedStart: String?
    let occupiedEnd: String?
    let agreementSnapshot: ServiceAgreement?
    let fulfillment: BookingFulfillment?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        requestID = try container.decode(UUID.self, forKey: .requestID)
        offerID = try container.decode(UUID.self, forKey: .offerID)
        customerID = try container.decode(UUID.self, forKey: .customerID)
        groomerID = try container.decode(UUID.self, forKey: .groomerID)
        scheduledStart = try container.decode(String.self, forKey: .scheduledStart)
        scheduledEnd = try container.decode(String.self, forKey: .scheduledEnd)
        priceEstimate = try container.decode(Double.self, forKey: .priceEstimate)
        status = try container.decode(BookingStatus.self, forKey: .status)
        cancelledBy = try container.decodeIfPresent(UUID.self, forKey: .cancelledBy)
        cancelledAt = try container.decodeIfPresent(String.self, forKey: .cancelledAt)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        completedBy = try container.decodeIfPresent(UUID.self, forKey: .completedBy)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        appliedTimingBuffers = try container.decodeIfPresent(GroomingTimingBuffers.self, forKey: .appliedTimingBuffers)
        serviceTimeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .serviceTimeZoneIdentifier)
        scheduleTimeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .scheduleTimeZoneIdentifier)
        occupiedStart = try container.decodeIfPresent(String.self, forKey: .occupiedStart)
        occupiedEnd = try container.decodeIfPresent(String.self, forKey: .occupiedEnd)
        agreementSnapshot = try container.decodeIfPresent(ServiceAgreement.self, forKey: .agreementSnapshot)
        fulfillment = try container.decodeIfPresent(UUID.self, forKey: .fulfillmentRevision) == nil
            ? nil : BookingFulfillment(from: decoder)
    }

    var booking: Booking {
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
            completedAt: completedAt,
            completedBy: completedBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            review: nil,
            serviceType: agreementSnapshot?.serviceType,
            requestPetSnapshot: agreementSnapshot?.petSnapshot,
            locationMode: agreementSnapshot?.locationMode,
            appliedTimingBuffers: appliedTimingBuffers,
            serviceTimeZoneIdentifier: serviceTimeZoneIdentifier,
            scheduleTimeZoneIdentifier: scheduleTimeZoneIdentifier,
            occupiedStart: occupiedStart,
            occupiedEnd: occupiedEnd,
            agreementSnapshot: agreementSnapshot,
            fulfillment: fulfillment
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fulfillmentRevision = "fulfillment_revision"
        case requestID = "request_id"
        case offerID = "offer_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case priceEstimate = "price_estimate"
        case status
        case cancelledBy = "cancelled_by"
        case cancelledAt = "cancelled_at"
        case completedAt = "completed_at"
        case completedBy = "completed_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case appliedTimingBuffers = "applied_timing_buffers"
        case serviceTimeZoneIdentifier = "service_time_zone_identifier"
        case scheduleTimeZoneIdentifier = "schedule_time_zone_identifier"
        case occupiedStart = "occupied_start"
        case occupiedEnd = "occupied_end"
        case agreementSnapshot = "agreement_snapshot"
    }
}
