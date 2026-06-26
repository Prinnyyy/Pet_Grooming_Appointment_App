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

    @Test @MainActor
    func submitOfferTrimsFormCallsRepositoryAndUpdatesState() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let offerID = UUID()
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .success(
                CreateGroomerOfferResult(
                    offerID: offerID,
                    offerStatus: .pending,
                    requestStatus: .hasOffers
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        let start = Date(timeIntervalSince1970: 1_783_000_000)
        let end = start.addingTimeInterval(2 * 60 * 60)
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: end,
            priceEstimateText: " 125.50 ",
            message: "  I can handle sensitive paws. ",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(repository.lastOfferDraft?.requestID == matchedRequest.request.id)
        #expect(repository.lastOfferDraft?.priceEstimate == 125.50)
        #expect(repository.lastOfferDraft?.message == "I can handle sensitive paws.")
        #expect(store.matchedRequests.first?.match.status == .offered)
        #expect(store.matchedRequests.first?.request.status == .hasOffers)
        #expect(store.matchedRequests.first?.offer?.id == offerID)
        #expect(store.matchedRequests.first?.offer?.status == .pending)
        #expect(store.noticeMessage == "Offer submitted.")
    }

    @Test @MainActor
    func supabaseMatchedRequestContractUsesBackendTravelRadiusColumn() throws {
        #expect(
            SupabaseGroomerRequestRepository.requestColumns
                .contains("travel_radius_miles")
        )
        #expect(
            !SupabaseGroomerRequestRepository.requestColumns
                .contains("travel_range_miles")
        )

        let row = try JSONDecoder().decode(
            GroomerMatchedGroomingRequestRow.self,
            from: Self.requestRowData(travelRadiusMiles: 25)
        )

        #expect(row.request.travelRangeMiles == 25)
    }

    @Test @MainActor
    func invalidOfferPriceDoesNotCallRepository() async throws {
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

        let start = Date(timeIntervalSince1970: 1_783_000_000)
        await store.submitOffer(
            for: matchedRequest,
            proposedStart: start,
            proposedEnd: start.addingTimeInterval(2 * 60 * 60),
            priceEstimateText: "12.345",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 0)
        #expect(store.errorMessage == "Price must be 0–100000 with at most 2 decimals.")
    }

    @Test @MainActor
    func pendingOfferCanBeWithdrawnAndReturnsMatchToViewed() async throws {
        let groomerID = UUID()
        let offerID = UUID()
        let matchedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: offerID
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            withdrawOfferResult: .success(
                WithdrawGroomerOfferResult(
                    offerID: offerID,
                    offerStatus: .withdrawnByGroomer,
                    withdrawnTimestamp: "2026-06-20T14:00:00Z",
                    requestStatus: .open
                )
            )
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        await store.withdrawOffer(for: matchedRequest)

        #expect(repository.withdrawOfferCallCount == 1)
        #expect(repository.lastWithdrawnOfferID == offerID)
        #expect(store.matchedRequests.first?.match.status == .viewed)
        #expect(store.matchedRequests.first?.request.status == .open)
        #expect(store.matchedRequests.first?.offer?.status == .withdrawnByGroomer)
        #expect(store.noticeMessage == "Offer withdrawn.")
    }

    private static func matchedRequest(
        groomerID: UUID,
        status: RequestMatchStatus = .visible,
        offerID: UUID? = nil
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
                locationMode: .comeToMe,
                streetAddress: "120 Pine St",
                travelRangeMiles: nil,
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            offer: offerID.map {
                GroomerOffer(
                    id: $0,
                    requestID: requestID,
                    matchID: UUID(),
                    customerID: customerID,
                    groomerID: groomerID,
                    proposedStart: "2026-06-22T16:00:00Z",
                    proposedEnd: "2026-06-22T18:00:00Z",
                    priceEstimate: 125,
                    message: "I can help.",
                    status: .pending,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: nil,
                    createdAt: "2026-06-20T12:00:00Z",
                    updatedAt: "2026-06-20T12:00:00Z"
                )
            }
        )
    }

    private static func requestRowData(travelRadiusMiles: Int) -> Data {
        Data(
            #"""
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "customer_id": "22222222-2222-2222-2222-222222222222",
              "pet_id": "33333333-3333-3333-3333-333333333333",
              "pet_snapshot": {
                "id": "33333333-3333-3333-3333-333333333333",
                "name": "Mochi",
                "species": "Dog",
                "breed": "Corgi",
                "size": "Small",
                "weight_lbs": 22,
                "birthday": null,
                "temperament": "Gentle",
                "medical_notes": null,
                "grooming_notes": null,
                "snapshot_at": "2026-06-20T12:00:00Z"
              },
              "photo_snapshot": [],
              "service_type": "Full groom",
              "service_notes": null,
              "preferred_start": "2026-06-22T16:00:00Z",
              "preferred_end": "2026-06-22T18:00:00Z",
              "location_mode": "visit_groomer",
              "street_address": "120 Pine St",
              "travel_radius_miles": \#(travelRadiusMiles),
              "city": "Seattle",
              "state": "WA",
              "zip_code": "98101",
              "status": "open",
              "expires_at": "2026-06-22T12:00:00Z",
              "created_at": "2026-06-20T12:00:00Z",
              "updated_at": "2026-06-20T12:00:00Z"
            }
            """#.utf8
        )
    }
}

@MainActor
private final class GroomerRequestRepositoryFake: GroomerRequestRepository {
    var matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError>
    var dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError>
    var createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError>
    var withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError>

    private(set) var matchedRequestsCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var createOfferCallCount = 0
    private(set) var withdrawOfferCallCount = 0
    private(set) var lastGroomerID: UUID?
    private(set) var lastDismissedMatchID: UUID?
    private(set) var lastDismissReason: String?
    private(set) var lastOfferDraft: GroomerOfferDraft?
    private(set) var lastWithdrawnOfferID: UUID?

    init(
        matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError> = .success([]),
        dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable)
    ) {
        self.matchedRequestsResult = matchedRequestsResult
        self.dismissResult = dismissResult
        self.createOfferResult = createOfferResult
        self.withdrawOfferResult = withdrawOfferResult
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

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        createOfferCallCount += 1
        lastOfferDraft = draft
        return try createOfferResult.get()
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        withdrawOfferCallCount += 1
        lastWithdrawnOfferID = offerID
        return try withdrawOfferResult.get()
    }
}
