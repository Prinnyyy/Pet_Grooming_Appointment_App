import Foundation

nonisolated struct BookingFulfillmentOperation: Codable, Equatable, Sendable {
    let id: UUID
    let bookingID: UUID
    let expectedRevision: UUID
    let action: BookingFulfillmentAction
    let note: String?
}

nonisolated struct BookingFulfillmentReceipt: Decodable, Equatable, Sendable {
    let id: UUID
    let operationID: UUID
    let bookingID: UUID
    let action: BookingFulfillmentAction
    let resultRevision: UUID
    let recordedAt: String
    private enum CodingKeys: String, CodingKey {
        case id, action
        case operationID = "operation_id"
        case bookingID = "booking_id"
        case resultRevision = "result_revision"
        case recordedAt = "recorded_at"
    }
}

struct BookingFulfillmentResult: Sendable {
    let receipt: BookingFulfillmentReceipt
    let booking: Booking
    let replayed: Bool
}

nonisolated struct BookingFulfillmentEvent: Decodable, Identifiable, Equatable, Sendable {
    let id: UUID
    let actorID: UUID
    let action: BookingFulfillmentAction
    let note: String?
    let recordedAt: String
    private enum CodingKeys: String, CodingKey {
        case id, action, note
        case actorID = "actor_id"
        case recordedAt = "recorded_at"
    }
}

nonisolated enum BookingFulfillmentRejection: String, Sendable {
    case stateChanged = "booking_revision_changed"
    case outsideStart = "outside_service_start_window"
    case tooEarly = "completion_too_early"
    case noShowWait = "no_show_wait_required"
    case otherParticipant = "other_participant_confirmation_required"
    case noteRequired = "fulfillment_note_required"
    case changedIntent = "fulfillment_operation_intent_changed"
    case unavailable

    var message: String {
        switch self {
        case .stateChanged: "This booking changed. Refresh and review its current outcome."
        case .outsideStart: "Service can start only during its scheduled appointment window."
        case .tooEarly: "Wait at least one minute after starting service before recording completion."
        case .noShowWait: "Wait 15 minutes after the scheduled start before reporting a no-show."
        case .otherParticipant: "The other participant must confirm this service outcome."
        case .noteRequired: "Add a short description of what happened, up to 500 characters."
        case .changedIntent: "A previous operation needs reconciliation before another change."
        case .unavailable: "This action is no longer available. Refresh the booking and review its current outcome."
        }
    }
}

nonisolated enum BookingFulfillmentPhase: String, Codable, Sendable {
    case scheduled
    case inService = "in_service"
    case outcomeReported = "outcome_reported"
    case completed, cancelled, unfulfilled
}

nonisolated enum BookingFulfillmentAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case start, complete, cancel
    case reportInterruption = "report_interruption"
    case reportNoShow = "report_no_show"
    case confirmStop = "confirm_stop"
    case withdrawReport = "withdraw_report"
    case closeElapsed = "close_elapsed"
    case reportCompletion = "report_completion"
    case confirmCompletion = "confirm_completion"
    case recordObjection = "record_objection"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .start: "Start Service"
        case .complete: "Complete Service"
        case .cancel: "Cancel Booking"
        case .reportInterruption: "Report Interruption"
        case .reportNoShow: "Report No-Show"
        case .confirmStop: "Confirm Service Stopped"
        case .withdrawReport: "Withdraw Report"
        case .closeElapsed: "Close Without Completion"
        case .reportCompletion: "Report Completed Service"
        case .confirmCompletion: "Confirm Completed Service"
        case .recordObjection: "Record an Objection"
        }
    }
    var systemImage: String {
        switch self {
        case .start: "play.fill"
        case .complete, .confirmCompletion: "checkmark.circle"
        case .cancel, .confirmStop, .closeElapsed: "stop.circle"
        case .withdrawReport: "arrow.uturn.backward"
        case .reportInterruption, .reportNoShow, .recordObjection: "exclamationmark.bubble"
        case .reportCompletion: "clock.badge.checkmark"
        }
    }
    var requiresNote: Bool {
        [.reportInterruption, .reportNoShow, .closeElapsed, .reportCompletion, .recordObjection].contains(self)
    }
}

nonisolated struct BookingFulfillment: Equatable, Hashable, Codable, Sendable {
    let revision: UUID
    let phase: BookingFulfillmentPhase
    let basis: String
    let actualStartedAt: String?
    let actualEndedAt: String?
    let petReleaseAt: String?
    let resourceReleaseAt: String?
    let reportedOutcome: String?
    let reportedBy: UUID?
    let reportedAt: String?
    let reportPreviousPhase: String?
    let reportNote: String?

    private enum CodingKeys: String, CodingKey {
        case revision = "fulfillment_revision"
        case phase = "fulfillment_phase"
        case basis = "fulfillment_basis"
        case actualStartedAt = "actual_started_at"
        case actualEndedAt = "actual_ended_at"
        case petReleaseAt = "pet_release_at"
        case resourceReleaseAt = "resource_release_at"
        case reportedOutcome = "reported_outcome"
        case reportedBy = "reported_by"
        case reportedAt = "reported_at"
        case reportPreviousPhase = "report_previous_phase"
        case reportNote = "report_note"
    }
}

extension Booking {
    nonisolated func applyingFulfillment(_ current: Booking) -> Booking {
        var updated = replacing(status: current.status, cancelledBy: current.cancelledBy,
            cancelledAt: current.cancelledAt, completedAt: current.completedAt,
            completedBy: current.completedBy, review: review)
        updated.fulfillment = current.fulfillment
        return updated
    }

    nonisolated func fulfillmentActions(for role: UserRole, participantID: UUID, now: Date = Date()) -> [BookingFulfillmentAction] {
        guard (role == .customer && participantID == customerID) || (role == .groomer && participantID == groomerID),
              let fulfillment,
              let start = GroomingRequestDateFormatting.parsedDate(from: scheduledStart),
              let end = GroomingRequestDateFormatting.parsedDate(from: scheduledEnd) else { return [] }
        var actions: [BookingFulfillmentAction] = []
        switch fulfillment.phase {
        case .scheduled:
            if now < start { return [.cancel] }
            if role == .groomer && now < end { actions.append(.start) }
            actions.append(.reportInterruption)
            if now >= start.addingTimeInterval(900) { actions.append(.reportNoShow) }
        case .inService:
            if canComplete(for: role, now: now) { actions.append(.complete) }
            actions.append(.reportInterruption)
        case .outcomeReported:
            if fulfillment.reportedBy == participantID { actions.append(.withdrawReport) }
            else { actions.append(fulfillment.reportedOutcome == "completion" ? .confirmCompletion : .confirmStop) }
        case .unfulfilled:
            if now >= end { actions.append(.reportCompletion) }
            actions.append(.recordObjection)
        case .completed, .cancelled:
            actions.append(.recordObjection)
        }
        if status == .confirmed && now >= end {
            actions.append(.closeElapsed)
            if fulfillment.phase != .outcomeReported { actions.append(.reportCompletion) }
        }
        return actions
    }

    nonisolated var fulfillmentTitle: String {
        guard let fulfillment else { return status.title }
        switch fulfillment.phase {
        case .scheduled: return "Confirmed"
        case .inService: return "In Service"
        case .outcomeReported: return "Outcome Awaiting Confirmation"
        case .completed: return "Completed"
        case .cancelled: return status.title
        case .unfulfilled: return "Service Not Confirmed"
        }
    }
}
