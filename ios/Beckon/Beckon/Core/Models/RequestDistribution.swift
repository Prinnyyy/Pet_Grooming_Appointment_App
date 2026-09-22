import Foundation

nonisolated struct RequestDistributionReceipt: Codable, Equatable, Sendable {
    let requestID: UUID
    let termsRevision: UUID
    let distributionRevision: UUID
    let poolEnabled: Bool
    let invitedGroomerIDs: [UUID]

    var scope: GroomerDiscoveryScope { .request(id: requestID, termsRevision: termsRevision) }
}

nonisolated struct RequestInvitation: Equatable, Identifiable, Sendable {
    let groomerID: UUID
    let profile: MarketplaceGroomerSummary?
    let sentAt: Date
    let replyBy: Date
    let state: RequestInvitationState
    var id: UUID { groomerID }
}

nonisolated struct CustomerRequestProgress: Equatable, Identifiable, Sendable {
    let requestID: UUID
    let termsRevision: UUID
    let distributionRevision: UUID
    let poolEnabled: Bool
    let status: GroomingRequestStatus
    let expiresAt: Date
    let checkedAt: Date
    let evaluationPending: Bool
    let validOfferCount: Int
    let invitations: [RequestInvitation]
    var poolCandidateCount: Int? = nil
    var id: UUID { requestID }

    func waitingTitle(at now: Date = Date()) -> String {
        guard status.isOpenForOffers else { return status.title }
        guard expiresAt > now else { return GroomingRequestStatus.expired.title }
        if validOfferCount > 0 { return "Offers Ready" }
        if poolEnabled {
            if evaluationPending { return "Checking Availability" }
            if poolCandidateCount == 0 { return "No Matching Groomers Right Now" }
            return "Request Pool Open"
        }
        return invitations.contains { $0.state == .awaitingResponse && $0.replyBy > now }
            ? "Waiting for Replies" : "No Available Offers"
    }
}
