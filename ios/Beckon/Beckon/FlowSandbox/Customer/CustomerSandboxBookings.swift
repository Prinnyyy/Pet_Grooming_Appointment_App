#if DEBUG
import Foundation

@MainActor
final class CustomerSandboxBookings: BookingRepository {
    let boundary: CustomerSandboxBoundary
    let marketplace: CustomerSandboxMarketplace
    var items: [Booking]
    var proposal: BookingRescheduleProposal?
    private var fulfillmentResults: [UUID: BookingFulfillmentResult] = [:]
    private var rescheduleResults: [UUID: BookingRescheduleResult] = [:]
    private var events: [BookingFulfillmentEvent] = []
    private var acceptances: [UUID: AcceptGroomerOfferResult] = [:]

    init(state: CustomerSandboxState, boundary: CustomerSandboxBoundary, marketplace: CustomerSandboxMarketplace) {
        self.boundary = boundary; self.marketplace = marketplace
        let booking = CustomerSandboxFixtures.booking(state: state)
        items = state == .empty ? [] : [booking]
        if state != .empty, !marketplace.items.contains(where: { $0.id == booking.requestID }) {
            marketplace.items.append(CustomerSandboxFixtures.request(state: .booked, id: booking.requestID))
        }
        if [.reschedulePending, .rescheduleAccepted, .rescheduleExpired].contains(state), let agreement = booking.agreementSnapshot {
            let status: BookingRescheduleStatus = state == .rescheduleAccepted ? .accepted : state == .rescheduleExpired ? .expired : .pending
            let start = Date().addingTimeInterval(172800).ISO8601Format()
            let end = Date().addingTimeInterval(180000).ISO8601Format()
            let proposed = CustomerSandboxFixtures.agreement(request: CustomerSandboxFixtures.request(),
                quote: agreement.quoteRevision, start: start, end: end)
            proposal = .init(id: CustomerSandboxFixtures.id(230), bookingID: booking.id, baseRevision: booking.fulfillment!.revision,
                initiatorID: booking.groomerID, proposedStart: start,
                proposedEnd: end, previousAgreement: agreement,
                proposedAgreement: proposed, status: status, effectiveStatus: status,
                expiresAt: Date().addingTimeInterval(state == .rescheduleExpired ? -3600 : 7200).ISO8601Format())
            if status == .accepted { items = [rescheduled(booking, agreement: proposed)] }
        }
    }
    func bookings(participantID: UUID, role: UserRole) async throws -> [Booking] {
        try await boundary.check(); return items
    }
    func bookings(bookingIDs: [UUID]) async throws -> [Booking] {
        try await boundary.check(); return items.filter { bookingIDs.contains($0.id) }
    }
    func bookings(participantID: UUID, role: UserRole, interval: DateInterval, page: ListPageRequest) async throws -> ListPage<Booking> {
        try await boundary.check()
        return .init(items: items.filter { interval.contains(GroomingRequestDateFormatting.parsedDate(from: $0.scheduledStart)!) }, request: page, hasMore: false)
    }
    func nearestBooking(participantID: UUID, role: UserRole, now: Date) async throws -> Booking? {
        try await boundary.check()
        return items.filter { $0.status == .confirmed && GroomingRequestDateFormatting.parsedDate(from: $0.scheduledEnd)! > now }.first
    }
    func reminderSnapshot(participantID: UUID, role: UserRole) async throws -> AppointmentReminderSnapshot {
        try await boundary.check()
        return .init(participantID: participantID, role: role, asOf: Date().ISO8601Format(),
            horizonEnd: Date().addingTimeInterval(7 * 86400).ISO8601Format(), complete: true, bookings: [])
    }
    func booking(customerID: UUID, requestID: UUID) async throws -> Booking? {
        try await boundary.check(); return items.first { $0.requestID == requestID }
    }
    func acceptOffer(offerID: UUID) async throws -> AcceptGroomerOfferResult {
        try await boundary.check()
        if let previous = acceptances[offerID] { return previous }
        guard let offer = marketplace.offerItems.first(where: { $0.id == offerID })?.offer else { throw BookingRepositoryError.offerNotFound }
        let booking = Booking(id: CustomerSandboxFixtures.id(31), requestID: offer.requestID, offerID: offer.id,
            customerID: offer.customerID, groomerID: offer.groomerID, scheduledStart: offer.proposedStart,
            scheduledEnd: offer.proposedEnd, priceEstimate: offer.priceEstimate, status: .confirmed,
            cancelledBy: nil, cancelledAt: nil, completedAt: nil, completedBy: nil,
            createdAt: Date().ISO8601Format(), updatedAt: Date().ISO8601Format(), review: nil,
            serviceType: .fullGroom, requestPetSnapshot: offer.agreementSnapshot?.petSnapshot,
            groomerBusinessName: marketplace.offerItems.first { $0.id == offerID }?.groomerTitle,
            locationMode: .groomerComesToCustomer, appliedTimingBuffers: offer.appliedTimingBuffers,
            serviceTimeZoneIdentifier: CustomerSandboxFixtures.zone, scheduleTimeZoneIdentifier: CustomerSandboxFixtures.zone,
            occupiedStart: offer.occupiedStart, occupiedEnd: offer.occupiedEnd,
            agreementSnapshot: offer.agreementSnapshot, fulfillment: CustomerSandboxFixtures.booking().fulfillment)
        items.append(booking)
        marketplace.items = marketplace.items.map { $0.id == offer.requestID ? $0.replacing(status: .booked) : $0 }
        let result = AcceptGroomerOfferResult(bookingID: booking.id, conversationID: CustomerSandboxFixtures.conversationID,
            requestID: offer.requestID, offerID: offer.id, bookingStatus: .confirmed, offerStatus: .acceptedByCustomer, requestStatus: .booked)
        acceptances[offerID] = result
        return result
    }
    func offerAcceptance(offerID: UUID) async throws -> AcceptGroomerOfferResult? { try await boundary.check(); return acceptances[offerID] }
    func cancelBooking(bookingID: UUID) async throws -> CancelBookingResult {
        try await boundary.check()
        let time = Date().ISO8601Format()
        items = items.map { $0.id == bookingID ? $0.replacing(status: .cancelledByCustomer,
            cancelledBy: CustomerSandboxFixtures.customerID, cancelledAt: time) : $0 }
        return .init(bookingID: bookingID, bookingStatus: .cancelledByCustomer, cancelledTimestamp: time, cancelledBy: CustomerSandboxFixtures.customerID)
    }
    func completeBooking(bookingID: UUID) async throws -> CompleteBookingResult {
        try await boundary.check()
        let time = Date().ISO8601Format()
        items = items.map { $0.id == bookingID ? $0.replacing(status: .completed, cancelledBy: nil, cancelledAt: nil, completedAt: time, completedBy: $0.groomerID) : $0 }
        return .init(bookingID: bookingID, bookingStatus: .completed, completedTimestamp: time, completedBy: CustomerSandboxFixtures.id(70))
    }
    func reviewContext(bookingID: UUID) async throws -> BookingReviewContext {
        try await boundary.check()
        return .init(bookingID: bookingID, contextRevision: CustomerSandboxFixtures.id(180), evidenceContextVersion: 2,
            serviceAt: items.first { $0.id == bookingID }?.completedAt,
            allowedKeys: [.init(dimension: "service", value: GroomingServiceType.fullGroom.rawValue),
                .init(dimension: "size", value: "M")])
    }
    func createReview(bookingID: UUID, draft: BookingReviewDraft) async throws -> CreateReviewResult {
        try await boundary.check()
        let review = BookingReview(id: CustomerSandboxFixtures.id(80), bookingID: bookingID,
            customerID: CustomerSandboxFixtures.customerID, groomerID: CustomerSandboxFixtures.id(70),
            rating: draft.rating, content: draft.content, createdAt: Date().ISO8601Format())
        items = items.map { $0.id == bookingID ? $0.replacing(status: $0.status,
            cancelledBy: $0.cancelledBy, cancelledAt: $0.cancelledAt,
            completedAt: $0.completedAt, completedBy: $0.completedBy, review: review) : $0 }
        return .init(review: review, groomerRatingAverage: 4.8, groomerRatingCount: 26)
    }
    func fulfillmentEvents(bookingID: UUID) async throws -> [BookingFulfillmentEvent] { try await boundary.check(); return events }
    func fulfillmentOperation(id: UUID) async throws -> BookingFulfillmentResult? { try await boundary.check(); return fulfillmentResults[id] }
    func mutateFulfillment(_ operation: BookingFulfillmentOperation) async throws -> BookingFulfillmentResult {
        try await boundary.check()
        if let value = fulfillmentResults[operation.id] { return value }
        guard let index = items.firstIndex(where: { $0.id == operation.bookingID }) else { throw BookingRepositoryError.bookingNotFound }
        let state: CustomerSandboxState = switch operation.action {
        case .complete, .confirmCompletion: .completed
        case .cancel, .confirmStop: .cancelled
        case .start: .inService
        case .withdrawReport: .confirmed
        case .closeElapsed: .unfulfilled
        default: .outcomeReported
        }
        let fixture = CustomerSandboxFixtures.booking(state: state)
        items[index] = items[index].applyingFulfillment(fixture)
        let receipt = BookingFulfillmentReceipt(id: UUID(), operationID: operation.id, bookingID: operation.bookingID,
            action: operation.action, resultRevision: fixture.fulfillment!.revision, recordedAt: Date().ISO8601Format())
        events.append(.init(id: receipt.id, actorID: CustomerSandboxFixtures.customerID,
            action: operation.action, note: operation.note, recordedAt: receipt.recordedAt))
        let result = BookingFulfillmentResult(receipt: receipt, booking: items[index], replayed: false)
        fulfillmentResults[operation.id] = result; return result
    }
    func reschedule(bookingID: UUID) async throws -> BookingRescheduleResult {
        try await boundary.check()
        guard let booking = items.first(where: { $0.id == bookingID }) else { throw BookingRepositoryError.bookingNotFound }
        return .init(booking: booking, proposal: proposal, receipt: nil)
    }
    func rescheduleOperation(id: UUID) async throws -> BookingRescheduleResult? { try await boundary.check(); return rescheduleResults[id] }
    func mutateReschedule(_ operation: BookingRescheduleOperation) async throws -> BookingRescheduleResult {
        try await boundary.check()
        if let result = rescheduleResults[operation.id] { return result }
        guard let booking = items.first(where: { $0.id == operation.bookingID }), let agreement = booking.agreementSnapshot else {
            throw BookingRepositoryError.bookingNotFound
        }
        let status: BookingRescheduleStatus = switch operation.action {
        case .propose: .pending
        case .accept: .accepted
        case .reject: .rejected
        case .withdraw: .withdrawn
        }
        let start = operation.newStart ?? proposal?.proposedStart ?? booking.scheduledStart
        let end = GroomingRequestDateFormatting.parsedDate(from: start)!.addingTimeInterval(7200).ISO8601Format()
        let proposed = CustomerSandboxFixtures.agreement(request: CustomerSandboxFixtures.request(),
            quote: agreement.quoteRevision, start: start, end: end)
        proposal = .init(id: operation.proposalID, bookingID: booking.id, baseRevision: operation.expectedRevision,
            initiatorID: operation.action == .propose ? CustomerSandboxFixtures.customerID : (proposal?.initiatorID ?? booking.groomerID),
            proposedStart: start, proposedEnd: end, previousAgreement: agreement, proposedAgreement: proposed,
            status: status, effectiveStatus: status, expiresAt: Date().addingTimeInterval(3600).ISO8601Format())
        let updated = operation.action == .accept ? rescheduled(booking, agreement: proposed) : booking
        items = items.map { $0.id == updated.id ? updated : $0 }
        let result = BookingRescheduleResult(booking: updated, proposal: proposal,
            receipt: .init(operationID: operation.id, bookingID: booking.id, proposalID: operation.proposalID,
                action: operation.action, resultRevision: operation.expectedRevision))
        rescheduleResults[operation.id] = result; return result
    }

    private func rescheduled(_ booking: Booking, agreement: ServiceAgreement) -> Booking {
        let start = GroomingRequestDateFormatting.parsedDate(from: agreement.scheduledStart)!
        let end = GroomingRequestDateFormatting.parsedDate(from: agreement.scheduledEnd)!
        return booking.applyingReschedule(Booking(id: booking.id, requestID: booking.requestID, offerID: booking.offerID,
            customerID: booking.customerID, groomerID: booking.groomerID,
            scheduledStart: agreement.scheduledStart, scheduledEnd: agreement.scheduledEnd,
            priceEstimate: booking.priceEstimate, status: booking.status,
            cancelledBy: booking.cancelledBy, cancelledAt: booking.cancelledAt,
            completedAt: booking.completedAt, completedBy: booking.completedBy,
            createdAt: booking.createdAt, updatedAt: Date().ISO8601Format(), review: booking.review,
            serviceType: booking.serviceType, requestPetSnapshot: booking.requestPetSnapshot,
            locationMode: booking.locationMode, appliedTimingBuffers: booking.appliedTimingBuffers,
            serviceTimeZoneIdentifier: booking.serviceTimeZoneIdentifier,
            scheduleTimeZoneIdentifier: booking.scheduleTimeZoneIdentifier,
            occupiedStart: start.addingTimeInterval(-1500).ISO8601Format(),
            occupiedEnd: end.addingTimeInterval(1500).ISO8601Format(),
            agreementSnapshot: agreement, fulfillment: booking.fulfillment))
    }
}
#endif
