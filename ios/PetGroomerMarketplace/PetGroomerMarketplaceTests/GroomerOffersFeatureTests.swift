import Foundation
import Testing
@testable import PetGroomerMarketplace

struct GroomerOffersStoreTests {
    @Test @MainActor
    func loadPopulatesOffersAndGroupsThemByStatus() async throws {
        let groomerID = UUID()
        let pending = Self.offerItem(
            groomerID: groomerID,
            status: .pending,
            createdAt: "2026-06-22T12:00:00Z"
        )
        let accepted = Self.offerItem(
            groomerID: groomerID,
            status: .acceptedByCustomer,
            createdAt: "2026-06-21T12:00:00Z"
        )
        let expired = Self.offerItem(
            groomerID: groomerID,
            status: .expired,
            createdAt: "2026-06-20T12:00:00Z"
        )
        let repository = GroomerOfferListRepositoryFake(
            offersResult: .success([expired, accepted, pending])
        )
        let store = GroomerOffersStore(
            groomerID: groomerID,
            repository: repository
        )

        await store.load()

        #expect(repository.offersCallCount == 1)
        #expect(repository.lastGroomerID == groomerID)
        #expect(store.offers == [pending, accepted, expired])
        #expect(store.sections.map(\.status) == [.pending, .acceptedByCustomer, .expired])
        #expect(store.sections.map(\.offers) == [[pending], [accepted], [expired]])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadFailurePreservesExistingOffersAndShowsMessage() async throws {
        let groomerID = UUID()
        let existing = Self.offerItem(groomerID: groomerID, status: .pending)
        let repository = GroomerOfferListRepositoryFake(
            offersResult: .success([existing])
        )
        let store = GroomerOffersStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        repository.offersResult = .failure(.networkUnavailable)
        await store.load()

        #expect(repository.offersCallCount == 2)
        #expect(store.offers == [existing])
        #expect(store.errorMessage == "Offers unavailable. Check your connection and try again.")
    }

    @Test @MainActor
    func loadEmptyResultClearsExistingOffersAndSections() async throws {
        let groomerID = UUID()
        let existing = Self.offerItem(groomerID: groomerID, status: .pending)
        let repository = GroomerOfferListRepositoryFake(
            offersResult: .success([existing])
        )
        let store = GroomerOffersStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        repository.offersResult = .success([])
        await store.load()

        #expect(repository.offersCallCount == 2)
        #expect(store.offers.isEmpty)
        #expect(store.sections.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadCancelledPreservesExistingOffersWithoutShowingError() async throws {
        let groomerID = UUID()
        let existing = Self.offerItem(groomerID: groomerID, status: .pending)
        let repository = GroomerOfferListRepositoryFake(
            offersResult: .success([existing])
        )
        let store = GroomerOffersStore(
            groomerID: groomerID,
            repository: repository
        )
        await store.load()

        repository.offersResult = .failure(.cancelled)
        await store.load()

        #expect(repository.offersCallCount == 2)
        #expect(store.offers == [existing])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func offerItemUsesRequestSummaryWhenRequestIsVisible() {
        let groomerID = UUID()
        let item = Self.offerItem(groomerID: groomerID, status: .pending)

        #expect(item.title == "Full Groom for Mochi")
        #expect(item.subtitle == "Seattle, WA 98101")
        #expect(
            item.timeSummary
                == "\(GroomingRequestDateFormatting.displayString(from: item.offer.proposedStart)) – \(GroomingRequestDateFormatting.displayString(from: item.offer.proposedEnd))"
        )
    }

    private static func offerItem(
        groomerID: UUID,
        status: GroomerOfferStatus,
        createdAt: String = "2026-06-22T12:00:00Z"
    ) -> GroomerOfferListItem {
        let requestID = UUID()
        let customerID = UUID()
        let petID = UUID()
        let offer = GroomerOffer(
            id: UUID(),
            requestID: requestID,
            matchID: UUID(),
            customerID: customerID,
            groomerID: groomerID,
            proposedStart: "2026-06-22T16:00:00Z",
            proposedEnd: "2026-06-22T18:00:00Z",
            priceEstimate: 125,
            message: "I can help.",
            status: status,
            expiresAt: "2026-06-22T12:00:00Z",
            withdrawnAt: status == .withdrawnByGroomer ? "2026-06-21T13:00:00Z" : nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let request = GroomerMatchedGroomingRequest(
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
            status: .hasOffers,
            expiresAt: "2026-06-23T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )

        return GroomerOfferListItem(
            offer: offer,
            request: request,
            booking: nil
        )
    }
}

@MainActor
private final class GroomerOfferListRepositoryFake: GroomerRequestRepository {
    var offersResult: Result<[GroomerOfferListItem], GroomerRequestRepositoryError>

    private(set) var offersCallCount = 0
    private(set) var lastGroomerID: UUID?

    init(
        offersResult: Result<[GroomerOfferListItem], GroomerRequestRepositoryError> = .success([])
    ) {
        self.offersResult = offersResult
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        []
    }

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem] {
        offersCallCount += 1
        lastGroomerID = groomerID
        return try offersResult.get()
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        throw GroomerRequestRepositoryError.unavailable
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        throw GroomerRequestRepositoryError.unavailable
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        throw GroomerRequestRepositoryError.unavailable
    }
}
