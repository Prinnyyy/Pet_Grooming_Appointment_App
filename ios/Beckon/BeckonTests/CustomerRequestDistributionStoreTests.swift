import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerRequestDistributionStoreTests {
    @Test func authoritativeExpiryEnablesHistoryWithoutWaitingForTheExpiryWorker() {
        var request = CustomerRequestsStoreTests.request(customerID: UUID(), petID: UUID())
        let revision = UUID()
        request.termsRevision = revision
        let progress = CustomerRequestProgress(requestID: request.id, termsRevision: revision,
            distributionRevision: UUID(), poolEnabled: false, status: .expired, expiresAt: .distantPast,
            checkedAt: Date(), evaluationPending: false, validOfferCount: 0, invitations: [])
        let expired = request.reconciling(progress)
        #expect(expired.status == .expired)
        #expect([expired].recentClosedRequests().count == 1)
        #expect(CustomerRequestDetailPresentation(status: expired.status).showsRepublish)
        request.termsRevision = UUID()
        #expect(request.reconciling(progress).status == .open)
        #expect(request.replacing(status: .booked).reconciling(progress).status == .booked)
    }
    @Test func uncertainPoolChangeRetainsConsentAndRetriesItsOriginalOperation() async {
        let fixture = DistributionStoreFixture()
        let store = fixture.store
        let id = fixture.repository.id
        await store.refresh(requestIDs: [id])
        fixture.repository.mutationFailure = .networkUnavailable
        #expect(await store.setPool(requestID: id, enabled: true) == false)
        #expect(store.progressByRequestID[id]?.poolEnabled == false)
        #expect(store.uncertainRequestIDs == [id])
        #expect(await store.setPool(requestID: id, enabled: false) == false)
        #expect(fixture.repository.operations.count == 1)
        fixture.repository.mutationFailure = nil
        #expect(await store.retry(requestID: id))
        #expect(fixture.repository.operations.count == 2)
        #expect(fixture.repository.operations[0] == fixture.repository.operations[1])
        #expect(store.progressByRequestID[id]?.poolEnabled == true)
        #expect(store.uncertainRequestIDs.isEmpty)
        #expect(store.error == nil)
    }

    @Test func oneVisibleContainerUsesTheEarliestLiveDeadline() async {
        let fixture = DistributionStoreFixture(), now = Date()
        fixture.repository.invitations = [
            .init(groomerID: UUID(), profile: nil, sentAt: now, replyBy: now.addingTimeInterval(-1), state: .awaitingResponse),
            .init(groomerID: UUID(), profile: nil, sentAt: now, replyBy: now.addingTimeInterval(10), state: .declined),
            .init(groomerID: UUID(), profile: nil, sentAt: now, replyBy: now.addingTimeInterval(20), state: .awaitingResponse)
        ]
        await fixture.store.refresh(requestIDs: [fixture.repository.id])
        #expect(fixture.store.nextDeadline(requestIDs: [fixture.repository.id], now: now) == now.addingTimeInterval(20))
        #expect(fixture.store.nextDeadline(requestIDs: [UUID()], now: now) == nil)
        fixture.repository.status = .expired
        await fixture.store.refresh(requestIDs: [fixture.repository.id])
        #expect(fixture.store.nextDeadline(requestIDs: [fixture.repository.id], now: now) == nil)
    }

    @Test func staleProgressCannotUndoAnInvitationConfirmedDuringItsRead() async {
        let fixture = DistributionStoreFixture()
        let id = fixture.repository.id, groomer = UUID()
        fixture.repository.onProgress = {
            fixture.repository.onProgress = nil
            _ = await fixture.store.invite(requestID: id, termsRevision: fixture.repository.terms, groomerIDs: [groomer])
        }
        await fixture.store.refresh(requestIDs: [id])
        #expect(fixture.store.state(requestID: id, groomerID: groomer, seed: .notSent) == .awaitingResponse)
        #expect(fixture.store.progressByRequestID[id]?.invitations.count == 1)
    }

    @Test func readFailurePreservesFactsAndASuccessfulRetryClearsTheError() async {
        let fixture = DistributionStoreFixture()
        let id = fixture.repository.id
        await fixture.store.refresh(requestIDs: [id])
        fixture.repository.readFailure = .networkUnavailable
        await fixture.store.refresh(requestIDs: [id])
        #expect(fixture.store.error == .networkUnavailable)
        #expect(fixture.store.progressByRequestID[id]?.validOfferCount == 2)
        fixture.repository.readFailure = nil
        await fixture.store.refresh(requestIDs: [id])
        #expect(fixture.store.error == nil)
    }

    @Test func deadlinesAndClosedRequestsOverrideOldCardSeeds() async {
        let fixture = DistributionStoreFixture()
        let id = fixture.repository.id, groomer = UUID()
        fixture.repository.invitations = [.init(groomerID: groomer, profile: nil, sentAt: .distantPast,
            replyBy: Date().addingTimeInterval(-1), state: .awaitingResponse)]
        await fixture.store.refresh(requestIDs: [id])
        #expect(fixture.store.state(requestID: id, groomerID: groomer, seed: .notSent) == .expired)
        fixture.repository.status = .booked
        await fixture.store.refresh(requestIDs: [id])
        #expect(fixture.store.state(requestID: id, groomerID: UUID(), seed: .notSent) == .closed)
    }

    @Test func batchedReadUsesAtMost25IDsAndSignOutRejectsLateRows() async {
        let fixture = DistributionStoreFixture()
        let ids = (0..<51).map { _ in UUID() }
        await fixture.store.refresh(requestIDs: ids + ids)
        #expect(fixture.repository.batches.map(\.count) == [25, 25, 1])
        #expect(fixture.store.progressByRequestID.count == 51)
        fixture.repository.onProgress = { fixture.store.clearSession() }
        await fixture.store.refresh(requestIDs: [fixture.repository.id])
        #expect(fixture.store.progressByRequestID.isEmpty)
        #expect(fixture.store.receipts.isEmpty)
        #expect(!fixture.store.isRefreshing)
    }

    @Test func authoritativePoolConflictDoesNotPublishTheRequestedState() async {
        let fixture = DistributionStoreFixture()
        let id = fixture.repository.id
        await fixture.store.refresh(requestIDs: [id])
        fixture.repository.mutationFailure = .distributionChanged
        #expect(await fixture.store.setPool(requestID: id, enabled: true) == false)
        #expect(fixture.store.progressByRequestID[id]?.poolEnabled == false)
        #expect(fixture.store.error == .distributionChanged)
        #expect(fixture.store.uncertainRequestIDs.isEmpty)
    }
}

@MainActor
private final class DistributionStoreFixture {
    let repository = DistributionStoreRepositoryFake()
    let store: CustomerRequestDistributionStore
    init() {
        let coordinator = CustomerRequestPublicationCoordinator(customerID: UUID(),
            requestRepository: CustomerRequestRepositoryFake(), distributionRepository: repository,
            storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        store = .init(repository: repository, publication: coordinator)
    }
}

@MainActor
private final class DistributionStoreRepositoryFake: RequestDistributionRepository {
    let id = UUID(), terms = UUID(), revision = UUID()
    var pool = false
    var status: GroomingRequestStatus = .open
    var invitations: [RequestInvitation] = []
    var operations: [UUID] = []
    var batches: [[UUID]] = []
    var mutationFailure: RequestDiscoveryError?
    var readFailure: RequestDiscoveryError?
    var onProgress: (() async -> Void)?
    var receipt: RequestDistributionReceipt {
        .init(requestID: id, termsRevision: terms, distributionRevision: revision,
            poolEnabled: pool, invitedGroomerIDs: invitations.map(\.groomerID))
    }
    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool,
                 groomerIDs: [UUID]) async throws -> RequestDistributionReceipt { receipt }
    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID,
                groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        operations.append(operationID)
        if let mutationFailure { throw mutationFailure }
        invitations = groomerIDs.map { .init(groomerID: $0, profile: nil, sentAt: Date(),
            replyBy: Date().addingTimeInterval(3600), state: .awaitingResponse) }
        return receipt
    }
    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID,
                 enabled: Bool) async throws -> RequestDistributionReceipt {
        operations.append(operationID)
        if let mutationFailure { throw mutationFailure }
        pool = enabled
        return receipt
    }
    func withdrawInvitation(operationID: UUID, requestID: UUID, groomerID: UUID) async throws -> RequestDistributionReceipt {
        operations.append(operationID)
        return receipt
    }
    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress] {
        batches.append(requestIDs)
        if let readFailure { throw readFailure }
        let rows = requestIDs.map { CustomerRequestProgress(requestID: $0, termsRevision: terms,
            distributionRevision: revision, poolEnabled: pool, status: status,
            expiresAt: Date().addingTimeInterval(7200), checkedAt: Date(), evaluationPending: false,
            validOfferCount: 2, invitations: invitations) }
        await onProgress?()
        return rows
    }
}
