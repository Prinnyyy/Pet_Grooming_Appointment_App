import Foundation
import Testing
@testable import Beckon

@MainActor
struct SafeGroomerRequestTests {
    @Test(arguments: [RequestInvitationState.withdrawn, .expired, .declined, .closed])
    func endedInvitationsDoNotLabelPoolAccessAsAnActiveInvitation(_ state: RequestInvitationState) {
        var request = GroomerRequestsStoreTests.matchedRequest(groomerID: UUID()).request
        request.invitationState = state
        request.poolEnabled = true
        #expect(request.distributionSourceTitle == "Request Pool")
        request.poolEnabled = false
        #expect(request.distributionSourceTitle == "Previous Invitation")
    }

    @Test func quoteAndWithdrawalPreserveRequestRevisionAndDistributionFacts() {
        var request = GroomerRequestsStoreTests.matchedRequest(groomerID: UUID()).request
        request.termsRevision = UUID()
        request.poolEnabled = true
        request.invitationState = .awaitingResponse
        let offered = request.replacing(status: .hasOffers)
        let withdrawn = offered.replacing(status: .open)
        #expect(offered.termsRevision == request.termsRevision)
        #expect(withdrawn.termsRevision == request.termsRevision)
        #expect(withdrawn.poolEnabled == true)
        #expect(withdrawn.invitationState == .awaitingResponse)
        #expect(withdrawn.distributionSourceTitle == "Invited + Request Pool")
    }

    @Test func detailIsSeparatelyAuthorizedAndRevokedOnRefreshFailure() async throws {
        let owner = UUID()
        let summary = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        var request = summary.request
        request.termsRevision = UUID()
        let detail = GroomerMatchedRequest(match: summary.match, request: request, offer: summary.offer)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([summary]))
        repository.exactMatchResult = .success(detail)
        let store = GroomerRequestsStore(groomerID: owner, repository: repository)
        await store.load()
        #expect(repository.exactReadCount == 0)
        #expect(store.authorizedDetail == nil)
        await store.openDetail(matchID: summary.id)
        #expect(store.authorizedDetail == detail)
        await store.load()
        #expect(store.authorizedDetail == detail)
        #expect(repository.exactReadCount == 2)
        repository.exactMatchResult = .failure(.notAllowed)
        await store.load()
        #expect(store.authorizedDetail == nil)
        #expect(store.detailError != nil)
    }

    @Test func lateDetailCannotRestoreAClosedOrSignedOutPage() async {
        let owner = UUID()
        let summary = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([summary]))
        repository.exactMatchResult = .success(summary)
        let store = GroomerRequestsStore(groomerID: owner, repository: repository)
        await store.load()
        repository.onExactRead = { store.closeDetail() }
        await store.openDetail(matchID: summary.id)
        #expect(store.authorizedDetail == nil)
        repository.onExactRead = { store.invalidateSession() }
        await store.openDetail(matchID: summary.id)
        #expect(store.authorizedDetail == nil)
        #expect(store.matchedRequests.isEmpty)
    }

    @Test func summaryDecodesWithoutPrivateAddressOrNotes() throws {
        let id = UUID()
        let row: [String: Any] = [
            "id": id.uuidString, "customer_id": UUID().uuidString,
            "pet_snapshot": ["id": UUID().uuidString, "name": "Poppy", "species": "Dog"],
            "photo_snapshot": [], "service_type": "full_groom",
            "preferred_start": "2026-10-01T10:00:00Z", "preferred_end": "2026-10-01T12:00:00Z",
            "location_mode": "groomer_comes_to_customer", "city": "Key West", "state": "FL",
            "status": "open", "expires_at": "2026-09-30T10:00:00Z",
            "pool_enabled": true, "invitation_state": "awaiting_response",
            "created_at": "2026-09-28T10:00:00Z", "updated_at": "2026-09-28T10:00:00Z"
        ]
        let decoded = try JSONDecoder().decode(GroomerMatchedGroomingRequestRow.self,
            from: JSONSerialization.data(withJSONObject: row))
        #expect(decoded.request.id == id)
        #expect(decoded.request.locationSummary == "Key West, FL")
        #expect(decoded.request.streetAddress.isEmpty)
        #expect(decoded.request.zipCode.isEmpty)
        #expect(decoded.request.serviceNotes == nil)
        #expect(decoded.request.petSnapshot.medicalNotes == nil)
        #expect(decoded.request.distributionSourceTitle == "Invited + Request Pool")
    }
}

@MainActor
struct RequestDistributionWireTests {
    @Test func waitingFactsPreserveUnknownAndRejectNegativeCandidateCounts() throws {
        var row = CustomerRequestProgressRow(requestID: UUID(), termsRevision: UUID(), distributionRevision: UUID(),
            poolEnabled: true, status: .open, expiresAt: "2026-09-23T00:00:00Z",
            checkedAt: "2026-09-22T00:00:00Z", evaluationPending: false, validOfferCount: 0, invitations: [])
        #expect(try row.progress().poolCandidateCount == nil)
        row.poolCandidateCount = 0
        #expect(try row.progress().poolCandidateCount == 0)
        row.poolCandidateCount = -1
        #expect(throws: RequestDiscoveryError.unavailable) { try row.progress() }
    }

    @Test func waitingStatesDoNotConflateCheckingZeroOrEndedInvitations() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func progress(pool: Bool = true, pending: Bool = false, count: Int? = nil, offers: Int = 0,
                      status: GroomingRequestStatus = .open, expiry: Date? = nil,
                      invitations: [RequestInvitation] = []) -> CustomerRequestProgress {
            .init(requestID: UUID(), termsRevision: UUID(), distributionRevision: UUID(), poolEnabled: pool,
                  status: status, expiresAt: expiry ?? now.addingTimeInterval(60), checkedAt: now,
                  evaluationPending: pending, validOfferCount: offers, invitations: invitations, poolCandidateCount: count)
        }
        #expect(progress(pending: true, count: 0).waitingTitle(at: now) == "Checking Availability")
        #expect(progress(count: 0).waitingTitle(at: now) == "No Matching Groomers Right Now")
        #expect(progress().waitingTitle(at: now) == "Request Pool Open")
        #expect(progress(count: 3).waitingTitle(at: now) == "Request Pool Open")
        #expect(progress(pending: true, count: 0, offers: 1).waitingTitle(at: now) == "Offers Ready")
        #expect(progress(pool: false).waitingTitle(at: now) == "No Available Offers")
        let invite = RequestInvitation(groomerID: UUID(), profile: nil, sentAt: now.addingTimeInterval(-60),
                                       replyBy: now.addingTimeInterval(20), state: .awaitingResponse)
        #expect(progress(pool: false, invitations: [invite]).waitingTitle(at: now) == "Waiting for Replies")
        #expect(progress(pool: false, invitations: [invite]).waitingTitle(at: now.addingTimeInterval(21)) == "No Available Offers")
        #expect(progress(offers: 2, expiry: now).waitingTitle(at: now) == GroomingRequestStatus.expired.title)
        #expect(progress(offers: 2, status: .cancelled).waitingTitle(at: now) == GroomingRequestStatus.cancelled.title)
    }

    @Test func receiptIsBoundToTheRequestedIdentity() throws {
        let id = UUID()
        let row = RequestDistributionReceiptRow(requestID: id, termsRevision: UUID(),
            distributionRevision: UUID(), poolEnabled: false, invitedGroomerIDs: [UUID()])
        #expect(try row.receipt(expectedRequest: id).requestID == id)
        #expect(throws: RequestDiscoveryError.notAllowed) { try row.receipt(expectedRequest: UUID()) }
        let duplicate = RequestDistributionReceiptRow(requestID: id, termsRevision: row.termsRevision,
            distributionRevision: row.distributionRevision, poolEnabled: false,
            invitedGroomerIDs: row.invitedGroomerIDs + row.invitedGroomerIDs)
        #expect(throws: RequestDiscoveryError.unavailable) { try duplicate.receipt(expectedRequest: id) }
    }

    @Test func receiptRoundTripsWithoutChangingTheOriginalIntent() throws {
        let receipt = RequestDistributionReceipt(requestID: UUID(), termsRevision: UUID(),
            distributionRevision: UUID(), poolEnabled: false, invitedGroomerIDs: [UUID()])
        #expect(try JSONDecoder().decode(RequestDistributionReceipt.self,
            from: JSONEncoder().encode(receipt)) == receipt)
    }

    @Test func invitationDeadlineAndKnownStateAreRequired() throws {
        let groomer = UUID()
        let expired = RequestInvitationRow(groomerID: groomer, safeProfile: nil,
            sentAt: "2026-09-22T00:00:00Z", replyBy: "2026-09-23T00:00:00Z", state: .expired)
        #expect(try expired.invitation().state == .expired)
        let tooLong = RequestInvitationRow(groomerID: groomer, safeProfile: nil,
            sentAt: expired.sentAt, replyBy: "2026-09-23T01:00:00Z", state: .awaitingResponse)
        #expect(throws: RequestDiscoveryError.unavailable) { try tooLong.invitation() }
        let absent = RequestInvitationRow(groomerID: groomer, safeProfile: nil,
            sentAt: expired.sentAt, replyBy: expired.replyBy, state: .notSent)
        #expect(throws: RequestDiscoveryError.unavailable) { try absent.invitation() }
    }

    @Test func failedProgressCannotBecomeNoOffers() throws {
        let row = CustomerRequestProgressRow(requestID: UUID(), termsRevision: UUID(), distributionRevision: UUID(),
            poolEnabled: false, status: .unknown, expiresAt: "2026-09-23T00:00:00Z",
            checkedAt: "2026-09-22T00:00:00Z", evaluationPending: false, validOfferCount: 0, invitations: [])
        #expect(throws: RequestDiscoveryError.unavailable) { try row.progress() }
    }
}
