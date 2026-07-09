import Foundation
import Testing
@testable import PetGroomerMarketplace

struct GroomerRequestsStoreTests {
    @Test @MainActor
    func requestPaginationRetriesThenAppendsUniqueRowsAndStopsAtLastPage() async {
        let groomerID = UUID()
        let first = Self.matchedRequest(groomerID: groomerID)
        let second = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestPages: [
                .success(ListPage(items: [first], request: .first, hasMore: true)),
                .failure(.networkUnavailable),
                .success(
                    ListPage(
                        items: [first, second],
                        request: .first.next,
                        hasMore: false
                    )
                ),
            ]
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()
        await store.loadNextPage()

        #expect(store.matchedRequests.map(\.id) == [first.id])
        #expect(store.canLoadMore == true)
        #expect(store.errorMessage == "Check your connection and try again.")

        await store.loadNextPage()

        #expect(repository.receivedMatchedRequestPages == [.first, .first.next, .first.next])
        #expect(store.matchedRequests.map(\.id) == [first.id, second.id])
        #expect(store.canLoadMore == false)
    }

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
    func loadRecordsStructuredDebugEventsForEmptyMatchedRequestResult() async throws {
        let groomerID = UUID()
        let recorder = AppDebugEventRecorder(
            writer: AppDebugEventWriterSpy(),
            emitsToOSLog: false
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([])
        )
        let store = GroomerRequestsStore(
            groomerID: groomerID,
            repository: repository,
            debugRecorder: recorder
        )

        await store.load()

        let start = try #require(
            recorder.events.first {
                $0.source == "GroomerRequestsStore.load"
                    && $0.message == "start"
            }
        )
        let success = try #require(
            recorder.events.first {
                $0.source == "GroomerRequestsStore.load"
                    && $0.message == "success"
            }
        )

        #expect(start.scope == "groomer.requests")
        #expect(start.metadata["operation"] == "load")
        #expect(start.metadata["groomerID"] == groomerID.uuidString.prefix(8).uppercased())
        #expect(success.scope == "groomer.requests")
        #expect(success.metadata["operation"] == "load")
        #expect(success.metadata["matchedRequestCount"] == "0")
        #expect(success.metadata["requestPhotoCount"] == "0")
        #expect(success.metadata["downloadedPhotoCount"] == "0")
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
    func submitOfferUnavailableRangePreservesMatchAndShowsAvailabilityError() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(.groomerUnavailable)
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
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "Choose a time within your availability and outside time off.")
    }

    @Test @MainActor
    func submitOfferRequestNoLongerOpenPreservesMatchAndShowsStaleRequestError() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(.requestNoLongerOpen)
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
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "This request can no longer receive offers.")
    }

    @Test @MainActor
    func submitOfferActiveOfferConflictPreservesMatchAndShowsConflictError() async throws {
        let groomerID = UUID()
        let matchedRequest = Self.matchedRequest(groomerID: groomerID)
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([matchedRequest]),
            createOfferResult: .failure(.activeOfferExists)
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
            priceEstimateText: "125",
            message: "",
            now: start.addingTimeInterval(-60 * 60)
        )

        #expect(repository.createOfferCallCount == 1)
        #expect(store.matchedRequests == [matchedRequest])
        #expect(store.errorMessage == "You already have an active offer for this request.")
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

    @Test @MainActor
    func acceptedOfferWithdrawalIsRejectedWithoutCallingRepositoryAndClearsStaleNotice() async throws {
        let groomerID = UUID()
        let offerID = UUID()
        let pendingRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: offerID
        )
        let repository = GroomerRequestRepositoryFake(
            matchedRequestsResult: .success([pendingRequest]),
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
        await store.withdrawOffer(for: pendingRequest)
        #expect(store.noticeMessage == "Offer withdrawn.")

        let acceptedRequest = Self.matchedRequest(
            groomerID: groomerID,
            status: .offered,
            offerID: UUID(),
            offerStatus: .acceptedByCustomer
        )
        await store.withdrawOffer(for: acceptedRequest)

        #expect(repository.withdrawOfferCallCount == 1)
        #expect(store.errorMessage == "This offer can no longer be withdrawn.")
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func fitEvidencePresentationUsesExplanationFirstCopyWithoutRawScore() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 94.6,
            matchReason: """
            Same city and service location. Pet-fit evidence: curly coats with positive reviews, poodles from completed bookings.
            """
        )

        let presentation = matchedRequest.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.reason
                == "Same city and service location. Pet-fit evidence: curly coats with positive reviews, poodles from completed bookings."
        )
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Earned Evidence: curly coats with positive reviews, poodles from completed bookings."
        )
    }

    @Test @MainActor
    func fitEvidencePresentationLabelsStarterSignalsAsLowConfidence() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 86,
            matchReason: """
            Same city and service location. Groomer fit signals: portfolio tag for poodles, claim for gentle handling.
            """
        )

        let presentation = matchedRequest.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Starter Signals: portfolio tag for poodles, claim for gentle handling."
        )
    }

    @Test @MainActor
    func matchSummaryDoesNotExposeRawScoreAsMatchPercentage() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            status: .viewed,
            matchScore: 88,
            matchReason: """
            Same city and service location. Pet-fit evidence: gentle handling.
            """
        )

        #expect(matchedRequest.matchSummary == "Viewed · Fit evidence available")
    }

    @Test @MainActor
    func fitEvidencePresentationIgnoresBlankReason() {
        let matchedRequest = Self.matchedRequest(
            groomerID: UUID(),
            matchScore: 91,
            matchReason: "   \n  "
        )

        #expect(matchedRequest.fitEvidencePresentation == nil)
    }

    private static func matchedRequest(
        groomerID: UUID,
        status: RequestMatchStatus = .visible,
        matchScore: Double? = 100,
        matchReason: String? = "same_city",
        offerID: UUID? = nil,
        offerStatus: GroomerOfferStatus = .pending
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
                matchScore: matchScore,
                matchReason: matchReason,
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
                    coatType: nil,
                    size: "M",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .fullGroom,
                serviceNotes: nil,
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                locationMode: .groomerComesToCustomer,
                streetAddress: "123 Pine Street",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                travelRadiusMiles: nil,
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
                    status: offerStatus,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: offerStatus == .withdrawnByGroomer
                        ? "2026-06-21T13:00:00Z"
                        : nil,
                    createdAt: "2026-06-20T12:00:00Z",
                    updatedAt: "2026-06-20T12:00:00Z"
                )
            }
        )
    }
}

@MainActor
private final class GroomerRequestRepositoryFake: GroomerRequestRepository {
    var matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError>
    var dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError>
    var createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError>
    var withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError>
    var matchedRequestPages: [Result<ListPage<GroomerMatchedRequest>, GroomerRequestRepositoryError>]

    private(set) var matchedRequestsCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var createOfferCallCount = 0
    private(set) var withdrawOfferCallCount = 0
    private(set) var lastGroomerID: UUID?
    private(set) var lastDismissedMatchID: UUID?
    private(set) var lastDismissReason: String?
    private(set) var lastOfferDraft: GroomerOfferDraft?
    private(set) var lastWithdrawnOfferID: UUID?
    private(set) var receivedMatchedRequestPages: [ListPageRequest] = []

    init(
        matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError> = .success([]),
        dismissResult: Result<DismissRequestMatchResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        createOfferResult: Result<CreateGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        withdrawOfferResult: Result<WithdrawGroomerOfferResult, GroomerRequestRepositoryError> =
            .failure(.unavailable),
        matchedRequestPages: [Result<ListPage<GroomerMatchedRequest>, GroomerRequestRepositoryError>] = []
    ) {
        self.matchedRequestsResult = matchedRequestsResult
        self.dismissResult = dismissResult
        self.createOfferResult = createOfferResult
        self.withdrawOfferResult = withdrawOfferResult
        self.matchedRequestPages = matchedRequestPages
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        matchedRequestsCallCount += 1
        lastGroomerID = groomerID
        return try matchedRequestsResult.get()
    }

    func matchedRequests(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerMatchedRequest> {
        matchedRequestsCallCount += 1
        lastGroomerID = groomerID
        receivedMatchedRequestPages.append(page)
        if !matchedRequestPages.isEmpty {
            return try matchedRequestPages.removeFirst().get()
        }

        return ListPage(
            items: try matchedRequestsResult.get(),
            request: page,
            hasMore: false
        )
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
