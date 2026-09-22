import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerGroomerDiscoveryTests {
    @Test func refreshRetainsIdentityButInvalidatesInFlightMotion() async {
        let repository = DiscoveryRepositoryFake()
        let first = candidate(1), second = candidate(2)
        repository.pages = [.success(page([first, second])), .success(page([second, first])),
                            .success(page([first])), .success(page([]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        store.deckSelection = .groomer(second.id)
        let revision = store.deckRevision
        await store.load()
        #expect(store.deckSelection == .groomer(second.id))
        #expect(store.deckRevision != revision)
        await store.load()
        #expect(store.deckSelection == .groomer(first.id))
        store.deckSelection = .more
        await store.load()
        #expect(store.deckSelection == nil)
        #expect(store.recommended.isEmpty)
    }

    @Test func tailRefreshAndSessionInvalidationCannotRestoreOldSelection() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)])), .success(page([candidate(1)]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        store.deckSelection = .more
        await store.load()
        #expect(store.deckSelection == .more)
        let revision = store.deckRevision
        store.invalidateSession()
        #expect(store.deckSelection == nil)
        #expect(store.deckRevision != revision)
        await store.load()
        #expect(store.deckSelection == nil)
        #expect(repository.reads.count == 2)
    }

    @Test(arguments: [false, true])
    func resumeRequestReplaysPendingPublicationWithoutAnotherBrowse(_ fails: Bool) async throws {
        let customerID = UUID(), petID = UUID()
        let distribution = PublicationDistributionFake()
        let request = CustomerRequestsStoreTests.request(id: distribution.receipt.requestID,
            customerID: customerID, petID: petID)
        let repository = CustomerRequestRepositoryFake(requestsResult: .success([request]))
        let marketplace = CustomerMarketplaceSession(customerID: customerID, requestRepository: repository,
            services: .init(discovery: DiscoveryRepositoryFake(), distribution: distribution,
                favorites: FavoritesRepositoryFake(), images: DiscoveryImageFake()), sessionIsCurrent: { true })
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Beckon/PendingPublications/\(customerID.uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let draft = GroomingRequestDraft(petID: petID, serviceType: .fullGroom, serviceNotes: "Recovery",
            preferredStart: Date().addingTimeInterval(7200), preferredEnd: Date().addingTimeInterval(14400),
            locationMode: .groomerComesToCustomer, streetAddress: "123 Main St", city: "Seattle",
            stateCode: .washington, zipCode: "98101", travelRadiusMiles: nil)
        let intent = PendingRequestPublication(customerID: customerID, draft: draft, photos: [],
            session: .init(id: UUID(), inputDigest: "immutable", expiresAt: .distantPast), groomerIDs: [UUID()])
        try marketplace.publication.begin(intent)
        if fails { distribution.failure = .networkUnavailable }
        let store = CustomerRequestsStore(customerID: customerID, petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake(),
            publicationCoordinator: marketplace.publication, marketplace: marketplace)
        store.isShowingWizard = true
        await store.prepareDiscovery()
        #expect(distribution.operations == [draft.publishOperationID])
        #expect(repository.createCallCount == 0)
        #expect(store.discoveryFlow == nil)
        #expect(store.isShowingWizard == fails)
        #expect((marketplace.publication.pending != nil) == fails)
        #expect((store.errorMessage != nil) == fails)
        if !fails { #expect(store.publishResult?.requestID == request.id) }
    }

    @Test func returningFromTheTailListPreservesTheTail() async {
        let repository = DiscoveryRepositoryFake()
        let items = (1...8).map { candidate($0) }
        repository.pages = [.success(page(items))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        store.deckSelection = .more
        store.showAll()
        store.showRecommendations()
        #expect(store.deckSelection == .more)
        #expect(repository.reads.count == 1)
    }

    @Test func avatarRevocationRejectsAnOlderResponseEvenWhenThePathIsReused() async {
        let images = DiscoveryImageFake()
        let session = CustomerMarketplaceSession(customerID: UUID(), requestRepository: CustomerRequestRepositoryFake(),
            services: .init(discovery: DiscoveryRepositoryFake(), distribution: PublicationDistributionFake(),
                favorites: FavoritesRepositoryFake(), images: images), sessionIsCurrent: { true })
        let profile = MarketplaceGroomerSummary(id: UUID(), businessName: "Fixture", avatarPath: "fixture/avatar.png")
        images.onLoad = {
            if images.calls == 1 {
                session.revokeAvatar(profile.id)
                await session.loadAvatar(profile)
            }
        }
        await session.loadAvatar(profile)
        #expect(images.calls == 2)
        #expect(session.avatarData[profile.id] == Data([2]))
        session.clearSession()
        #expect(session.avatarData.isEmpty)
    }

    @Test func missingMediaAndLateSignOutDoNotBlockOrRestoreCandidateIdentity() async {
        let images = DiscoveryImageFake()
        let session = CustomerMarketplaceSession(customerID: UUID(), requestRepository: CustomerRequestRepositoryFake(),
            services: .init(discovery: DiscoveryRepositoryFake(), distribution: PublicationDistributionFake(),
                favorites: FavoritesRepositoryFake(), images: images), sessionIsCurrent: { true })
        var profile = MarketplaceGroomerSummary(id: UUID(), businessName: "Fixture")
        await session.loadAvatar(profile)
        #expect(images.calls == 0)
        profile.avatarPath = "fixture/avatar.png"
        images.onLoad = { session.clearSession() }
        await session.loadAvatar(profile)
        #expect(session.avatarData.isEmpty)
    }
    @Test(arguments: [0, 1, 3, 8, 26, 101])
    func allPoolSizesKeepOneCompleteOrderedCollection(_ count: Int) async {
        let repository = DiscoveryRepositoryFake()
        let items = (0..<count).map { candidate($0 + 1) }
        repository.pages = count == 0 ? [.success(page([]))] : stride(from: 0, to: count, by: 25).map { offset in
            .success(page(Array(items[offset..<min(offset + 25, count)]),
                cursor: offset + 25 < count ? String(offset + 25) : nil))
        }
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        let first = store.recommended.map(\.id)
        store.showAll()
        while store.canLoadMore { await store.loadNextPage() }
        #expect(store.candidates.map(\.id) == items.map(\.id))
        #expect(first == Array(items.prefix(8)).map(\.id))
        #expect(store.recommended.map(\.id) == first)
        #expect(Set(store.candidates.map(\.id)).count == count)
    }

    @Test func publicationConfirmationNamesTheRecipientsAndNeverInheritsPoolConsent() {
        let flow = CustomerRequestDiscoveryFlow(store: .init(scope: scope(), repository: DiscoveryRepositoryFake()))
        #expect(!flow.poolEnabled)
        #expect(flow.publicationConfirmation(names: ["One", "Two"]) ==
            "Send to: One, Two. Request pool: off. Only invited groomers can respond.")
        flow.poolEnabled = true
        #expect(flow.publicationConfirmation(names: []) ==
            "No direct invitations. Request pool: on. All eligible groomers can see this request.")
        flow.store.publicationConfirmed(requestScope: .request(id: UUID(), termsRevision: UUID()))
        #expect(flow.publicationConfirmation(names: ["One"]) == nil)
    }

    @Test func scopeWireIdentityCannotMixPreviewAndPublishedRequest() throws {
        let id = UUID(), revision = UUID()
        let preview = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            RequestDiscoveryScopeParameters(scope: .preview(sessionID: id, inputDigest: "digest")))) as? [String: String]
        #expect(preview == ["kind": "preview", "id": id.uuidString.lowercased(), "input_digest": "digest"])
        let request = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
            RequestDiscoveryScopeParameters(scope: .request(id: id, termsRevision: revision)))) as? [String: String]
        #expect(request == ["kind": "request", "id": id.uuidString.lowercased(), "terms_revision": revision.uuidString.lowercased()])
    }

    @Test func wireCandidateRejectsMismatchedIdentityAndInvalidMoney() throws {
        let id = UUID()
        let object: [String: Any] = [
            "groomer_id": id.uuidString,
            "safe_profile": ["id": id.uuidString, "rating_count": 0, "is_verified": false],
            "eligibility": ["state": "estimated_fit"], "distance_miles": 3.5,
            "favorite_state": ["is_favorite": false], "invitation_state": "not_sent"
        ]
        func decode(_ value: [String: Any]) throws -> DiscoveredGroomer {
            try JSONDecoder().decode(DiscoveredGroomerRow.self, from: JSONSerialization.data(withJSONObject: value)).groomer()
        }
        #expect(try decode(object).id == id)
        var invalid = object
        invalid["groomer_id"] = UUID().uuidString
        #expect(throws: RequestDiscoveryError.notAllowed) { try decode(invalid) }
        invalid = object
        invalid["reference_price"] = ["amount": -1, "currency": "USD", "service_id": UUID().uuidString, "reference_only": true]
        #expect(throws: RequestDiscoveryError.unavailable) { try decode(invalid) }
        invalid["reference_price"] = ["amount": 80, "currency": "USD", "service_id": UUID().uuidString, "reference_only": false]
        #expect(throws: RequestDiscoveryError.unavailable) { try decode(invalid) }
    }

    @Test func browsingSharesTheSameOrderedCandidates() async {
        let repository = DiscoveryRepositoryFake()
        let items = (1...26).map { candidate($0) }
        repository.pages = [.success(page(Array(items.prefix(25)), cursor: "page-2")),
                            .success(page([items[25]]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        #expect(store.recommended.map(\.id) == Array(items.prefix(8)).map(\.id))
        store.deckSelection = .groomer(items[4].id)
        store.showAll()
        await store.loadNextPage()
        #expect(store.candidates.map(\.id) == items.map(\.id))
        store.showRecommendations()
        #expect(store.deckSelection == .groomer(items[4].id))
        #expect(repository.reads.count == 2)
    }

    @Test func smallAndPendingPoolsAreNotPaddedOrReportedAsErrors() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)], pending: 2))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        #expect(store.recommended.count == 1)
        #expect(store.pendingCount == 2)
        #expect(store.error == nil)
    }

    @Test func changedPageCannotAppendMixedCandidates() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)], cursor: "next")),
                            .success(page([candidate(2)], revision: "changed"))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        await store.loadNextPage()
        #expect(store.error == .listChanged)
        #expect(!store.canLoadMore)
        #expect(!store.candidates.contains(where: { $0.id == candidate(2).id }))
    }

    @Test func networkFailureKeepsExistingCandidatesAndRetryCursor() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)], cursor: "next")),
                            .failure(.networkUnavailable), .success(page([candidate(2)]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        await store.loadNextPage()
        #expect(store.candidates.map(\.id) == [candidate(1).id])
        #expect(store.error == .networkUnavailable)
        #expect(store.canLoadMore)
        await store.loadNextPage()
        #expect(store.candidates.map(\.id) == [candidate(1).id, candidate(2).id])
    }

    @Test func sortChangeDiscardsLateResponse() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)])), .success(page([candidate(2)], mode: "distance"))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        repository.onRead = {
            repository.onRead = nil
            // A new UI action is not a child of the network operation it cancels.
            await Task { await store.changeSort(to: .distance) }.value
        }
        await store.load()
        #expect(store.sort == .distance)
        #expect(store.candidates.map(\.id) == [candidate(2).id])
        #expect(!store.isLoading)
    }

    @Test func assessmentRemainsDiscoverableWhenGroomerMustConfirmServiceScope() async {
        let repository = DiscoveryRepositoryFake()
        let base = candidate(1)
        let assessment = DiscoveredGroomer(profile: base.profile,
            eligibility: MatchEligibilityEvaluation(state: "assessment_required", reason: "service_details_unconfirmed",
                serviceStart: nil, serviceEnd: nil, requiredConfirmations: ["service_species_configuration"]),
            matchingEvidence: nil, distanceMiles: 1, referencePrice: nil,
            favoriteState: base.favoriteState, invitationState: .notSent)
        repository.pages = [.success(page([assessment]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        await store.load()
        #expect(store.recommended.map(\.id) == [base.id])
        #expect(store.error == nil)
        #expect(!assessment.eligibility.isOfferable)
    }

    @Test func sessionRevocationClearsCandidatesAndIgnoresLateResult() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)]))]
        let store = CustomerGroomerDiscoveryStore(scope: scope(), repository: repository)
        repository.onRead = { store.invalidateSession() }
        await store.load()
        #expect(store.candidates.isEmpty)
        #expect(!store.canLoadMore)
        #expect(store.error == nil)
    }

    @Test func publishedPreviewKeepsBrowseAndPosition() async {
        let repository = DiscoveryRepositoryFake()
        repository.pages = [.success(page([candidate(1)], cursor: "next"))]
        let preview = scope()
        let store = CustomerGroomerDiscoveryStore(scope: preview, repository: repository)
        await store.load()
        store.deckSelection = .groomer(candidate(1).id)
        let requestScope = GroomerDiscoveryScope.request(id: UUID(), termsRevision: UUID())
        store.publicationConfirmed(requestScope: requestScope)
        #expect(store.scope == preview)
        #expect(store.actionScope == requestScope)
        #expect(store.deckSelection == .groomer(candidate(1).id))
        #expect(store.canLoadMore)
        #expect(repository.reads.count == 1)
    }

    private func scope() -> GroomerDiscoveryScope { .preview(sessionID: UUID(), inputDigest: "digest") }

    private func candidate(_ index: Int) -> DiscoveredGroomer {
        let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
        return DiscoveredGroomer(profile: MarketplaceGroomerSummary(id: id, businessName: "Groomer \(index)"),
            eligibility: MatchEligibilityEvaluation(state: "estimated_fit", reason: nil,
                serviceStart: nil, serviceEnd: nil), matchingEvidence: nil, distanceMiles: 1,
            referencePrice: nil, favoriteState: .init(isFavorite: false, revision: nil), invitationState: .notSent)
    }

    private func page(_ items: [DiscoveredGroomer], cursor: String? = nil, pending: Int = 0,
                      revision: String = "initial", mode: String = "fit") -> RankedPage<DiscoveredGroomer> {
        RankedPage(items: items, rankingRevision: revision, scoreAsOf: .distantPast,
            validUntil: .distantFuture, algorithmVersion: "matching-v1", requestedMode: mode,
            effectiveMode: mode, pendingCount: pending, assessmentCount: 0, nextCursor: cursor)
    }
}

@MainActor
final class DiscoveryImageFake: PrivateImageLoading {
    var calls = 0
    var onLoad: (() async -> Void)?
    func loadData(bucketID: String, storagePath: String) async throws -> Data {
        calls += 1
        let result = Data([UInt8(calls)])
        await onLoad?()
        return result
    }
    func refreshData(bucketID: String, storagePath: String) async throws -> Data {
        try await loadData(bucketID: bucketID, storagePath: storagePath)
    }
    func saveData(_ data: Data, bucketID: String, storagePath: String) {}
    func removeData(bucketID: String, storagePath: String) {}
}

@MainActor
final class DiscoveryRepositoryFake: CustomerGroomerDiscoveryRepository {
    var pages: [Result<RankedPage<DiscoveredGroomer>, RequestDiscoveryError>] = []
    var reads: [RankedPageRequest<GroomerDiscoverySort>] = []
    var onRead: (() async -> Void)?
    func prepare(draftID: UUID, draft: GroomingRequestDraft) async throws -> DiscoverySession {
        throw RequestDiscoveryError.unavailable
    }
    func candidates(scope: GroomerDiscoveryScope, page: RankedPageRequest<GroomerDiscoverySort>) async throws -> RankedPage<DiscoveredGroomer> {
        reads.append(page)
        let response = pages.removeFirst()
        await onRead?()
        return try response.get()
    }
    func profile(scope: GroomerDiscoveryScope, groomerID: UUID) async throws -> DiscoveredGroomer {
        throw RequestDiscoveryError.unavailable
    }
}
