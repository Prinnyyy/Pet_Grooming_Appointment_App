import Foundation
import Testing
@testable import Beckon

struct MatchRankingTests {
    @Test @MainActor
    func notificationRefreshPreservesPositionAndInvalidatesPagination() async throws {
        let owner = UUID()
        let first = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let second = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([first, second]))
        repository.exactMatchResult = .success(first)
        let store = GroomerRequestsStore(groomerID: owner, repository: repository)
        await store.load()
        _ = try await store.resolveNotificationRequest(id: first.request.id)
        #expect(store.matchedRequests.map(\.id) == [first.id, second.id])
        #expect(store.listNeedsRefresh)
        #expect(!store.canLoadMore)
        store.setSessionValidation { false }
        do {
            _ = try await store.resolveNotificationRequest(id: first.request.id)
            Issue.record("Expired session must not apply notification data")
        } catch is CancellationError {
        }
    }

    @Test @MainActor
    func modeChangeDiscardsThePreviousInFlightResponse() async {
        let owner = UUID()
        let old = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let new = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let repository = GroomerRequestRepositoryFake()
        func page(_ item: GroomerMatchedRequest, mode: String) -> RankedPage<GroomerMatchedRequest> {
            RankedPage(items: [item], rankingRevision: mode, scoreAsOf: Date(timeIntervalSince1970: 1),
                validUntil: Date(timeIntervalSince1970: 301), algorithmVersion: "matching-v1",
                requestedMode: mode, effectiveMode: mode, pendingCount: 0, assessmentCount: 0, nextCursor: nil)
        }
        repository.rankedPages = [.success(page(old, mode: "fit")), .success(page(new, mode: "distance"))]
        let store = GroomerRequestsStore(groomerID: owner, repository: repository)
        repository.onRankedRead = {
            repository.onRankedRead = nil
            await store.changeSort(to: .distance)
        }
        await store.load()
        #expect(store.matchedRequests.map(\.id) == [new.id])
        #expect(store.sort == .distance)
        #expect(store.rankedPage?.effectiveMode == "distance")
        #expect(!store.isLoading)
    }
    @Test @MainActor
    func changedCustomerPageKeepsOrderAndRefreshesInvalidQuotes() async {
        let customer = UUID()
        let request = CustomerRequestsStoreTests.request(customerID: customer, petID: UUID())
        let item = CustomerRequestsStoreTests.offerReview(customerID: customer, requestID: request.id)
        let repository = CustomerRequestRepositoryFake()
        repository.rankedPages = [.success(RankedPage(items: [item], rankingRevision: "one",
            scoreAsOf: Date(timeIntervalSince1970: 1), validUntil: Date(timeIntervalSince1970: 301),
            algorithmVersion: "matching-v1", requestedMode: "balanced", effectiveMode: "balanced",
            pendingCount: 0, assessmentCount: 0, nextCursor: "next")), .failure(.listChanged)]
        repository.quoteEvaluationsResult = .success([item.id: QuoteEvaluation(termsValid: false,
            selectable: false, reason: "eligibility_revoked")])
        let store = CustomerRequestsStore(customerID: customer, petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.loadOffers(for: request)
        await store.loadNextOffersPage(for: request)
        await store.loadNextOffersPage(for: request)
        #expect(store.offers(for: request).map(\.id) == [item.id])
        #expect(store.offers(for: request).first?.offer.quoteEvaluation?.selectable == false)
        #expect(!store.canLoadMoreOffers(for: request))
        #expect(repository.rankedRequests.count == 2)
    }

    @Test @MainActor
    func structuredEvidenceShowsNegativeAndUnknownWithoutProbability() {
        var item = GroomerRequestsStoreTests.matchedRequest(groomerID: UUID())
        item.matchingEvidence = MatchingEvidence(state: "available", algorithmVersion: "matching-v1",
            scoreAsOf: "2026-09-11T08:00:00.123Z", relatedReviewCount: 2, independentCustomers: 2,
            completedCount: 4, latestServiceAt: nil, coverage: [MatchingEvidenceCoverage(dimension: "service",
                value: "nail_trim", completedCount: 4, positiveCount: 1, negativeCount: 1, unknownCount: 2)])
        #expect(item.fitEvidencePresentation?.scoreText == nil)
        #expect(item.fitEvidencePresentation?.reason.contains("1 positive, 1 negative, 2 unreported") == true)
        #expect(item.fitEvidencePresentation?.reason.contains("Updated") == true)
        #expect(item.fitEvidencePresentation?.reason.contains("%") == false)
    }
    @Test @MainActor
    func changedPagePreservesMatchesAndStopsWithoutRetry() async {
        let item = GroomerRequestsStoreTests.matchedRequest(groomerID: UUID())
        let repository = GroomerRequestRepositoryFake()
        repository.rankedPages = [.success(RankedPage(items: [item], rankingRevision: "one",
            scoreAsOf: Date(timeIntervalSince1970: 1), validUntil: Date(timeIntervalSince1970: 301),
            algorithmVersion: "matching-v1", requestedMode: "fit", effectiveMode: "fit",
            pendingCount: 0, assessmentCount: 0, nextCursor: "next")), .failure(.listChanged)]
        let store = GroomerRequestsStore(groomerID: item.match.groomerID, repository: repository)
        await store.load()
        await store.loadNextPage()
        await store.loadNextPage()
        #expect(store.matchedRequests.map(\.id) == [item.id])
        #expect(store.listNeedsRefresh)
        #expect(!store.canLoadMore)
        #expect(repository.rankedRequests.count == 2)
    }

    @Test @MainActor
    func sessionInvalidationDiscardsLateMatches() async {
        let item = GroomerRequestsStoreTests.matchedRequest(groomerID: UUID())
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success([item]))
        let store = GroomerRequestsStore(groomerID: item.match.groomerID, repository: repository)
        repository.onRankedRead = { store.invalidateSession() }
        await store.load()
        #expect(store.matchedRequests.isEmpty)
        #expect(store.rankedPage == nil)
        #expect(!store.isLoading)
    }
    @Test
    func rankedPagesRejectChangedSnapshotAndMode() {
        let first = page(revision: "one", mode: "fit")
        #expect(first.canAppend(page(revision: "one", mode: "fit")))
        #expect(!first.canAppend(page(revision: "two", mode: "fit")))
        #expect(!first.canAppend(page(revision: "one", mode: "distance")))
        #expect(!first.canAppend(page(revision: "one", mode: "fit", asOf: 2)))
    }

    @Test @MainActor
    func preferencesAreExplicitAndAccountScoped() throws {
        let name = "MatchRankingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = MatchSortPreferenceStore(defaults: defaults)
        let first = UUID(), second = UUID()
        #expect(preferences.groomerSort(accountID: first) == .fit)
        #expect(preferences.customerSort(accountID: first) == .balanced)
        preferences.setGroomerSort(.distance, accountID: first)
        preferences.setCustomerSort(.price, accountID: first)
        #expect(preferences.groomerSort(accountID: first) == .distance)
        #expect(preferences.customerSort(accountID: first) == .price)
        #expect(preferences.groomerSort(accountID: second) == .fit)
        #expect(preferences.customerSort(accountID: second) == .balanced)
        preferences.reset(accountID: first)
        #expect(preferences.groomerSort(accountID: first) == .fit)
        #expect(preferences.customerSort(accountID: first) == .balanced)
    }

    @Test
    func pageLimitsStayInsideServerContract() {
        #expect(RankedPageRequest(mode: GroomerMatchSort.fit, limit: 500).limit == 50)
        #expect(RankedPageRequest(mode: CustomerOfferSort.balanced, limit: 0).limit == 1)
    }

    private func page(revision: String, mode: String, asOf: TimeInterval = 1) -> RankedPage<Int> {
        RankedPage(items: [1], rankingRevision: revision, scoreAsOf: Date(timeIntervalSince1970: asOf),
            validUntil: Date(timeIntervalSince1970: 300), algorithmVersion: "matching-v1",
            requestedMode: mode, effectiveMode: mode, pendingCount: 0, assessmentCount: 0, nextCursor: "next")
    }
}
