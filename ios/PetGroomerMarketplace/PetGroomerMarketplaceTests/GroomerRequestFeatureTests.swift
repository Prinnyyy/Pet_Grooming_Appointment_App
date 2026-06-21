import Foundation
import Testing
@testable import PetGroomerMarketplace

struct GroomerRequestsStoreTests {
    @Test @MainActor
    func loadPopulatesMatchedRequests() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.matchedRequestsCallCount == 1)
        #expect(repository.lastGroomerID == groomerID)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func dismissCallsRepositoryAndRemovesMatch() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            dismissResult: .success(
                DismissRequestMatchResult(
                    matchID: matchedRequest.match.id,
                    status: .dismissed,
                    dismissedAt: "2026-06-20T13:00:00Z"
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 1)
        #expect(repository.lastDismissedMatchID == matchedRequest.match.id)
        #expect(repository.lastDismissReason == nil)
        #expect(store.matchedRequests.isEmpty)
        #expect(store.noticeMessage == "Match dismissed.")
    }

    @Test @MainActor
    func nonDismissibleMatchDoesNotCallRepository() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 0)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This match can no longer be dismissed.")
    }

    @Test @MainActor
    func dismissFailurePreservesMatch() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            dismissResult: .failure(.noLongerDismissible)
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.dismiss(matchedRequest)

        #expect(repository.dismissCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This match can no longer be dismissed.")
    }

    private static func matchedRequest(
        groomerID: UUID,
        status: RequestMatchStatus = .visible
    ) -> GroomerMatchedRequest {
        let requestID = UUID()
        let customerID = UUID()
        let petID = UUID()

        return GroomerMatchedRequest(
            match: GroomerRequestMatch(
                id: UUID(),
                requestID: requestID,
                groomerID: groomerID,
                customerID: customerID,
                matchScore: 100,
                matchReason: "same_city",
                dismissReason: nil,
                status: status,
                viewedAt: nil,
                dismissedAt: nil,
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            request: GroomerMatchedGroomingRequest(
                id: requestID,
                customerID: customerID,
                petID: petID,
                petSnapshot: GroomingRequestPetSnapshot(
                    id: petID,
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    size: "Small",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: "Full groom",
                serviceNotes: nil,
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            )
        )
    }
}

@MainActor
private final class GroomerRequestRepositoryFake: GroomerRequestRepository {
    var matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError>
    var dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError>

    private(set) var matchedRequestsCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var lastGroomerID: UUID?
    private(set) var lastDismissedMatchID: UUID?
    private(set) var lastDismissReason: String?

    init(
        matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError> = .success([]),
        dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError> =
            .failure(.unavailable)
    ) {
        self.matchedRequestsResult = matchedRequestsResult
        self.dismissResult = dismissResult
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        matchedRequestsCallCount += 1
        lastGroomerID = groomerID
        return try matchedRequestsResult.get()
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        dismissCallCount += 1
        lastDismissedMatchID = matchID
        lastDismissReason = reason
        return try dismissResult.get()
    }
}
