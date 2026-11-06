import SwiftUI
import Testing
@testable import Beckon

@MainActor struct GroomerGroomingWorkspaceTests {
    private func workspace(_ fixture: GroomerSandboxSession, repository: (any GroomerRequestRepository)? = nil,
        isCurrent: @escaping @MainActor () -> Bool = { true }) -> GroomerGroomingWorkspace {
        GroomerGroomingWorkspace(session: GroomerGroomingSession(groomerID: fixture.groomerID,
            requests: fixture.requests, offers: fixture.offers, bookings: fixture.bookings,
            chat: fixture.chat, notifications: fixture.notifications,
            requestRepository: repository ?? fixture.requestRepository, chatRepository: fixture.chatRepository,
            bookingRepository: fixture.bookingRepository, isCurrent: isCurrent))
    }

    @Test func existingStoreRowsAreAvailableBeforeFirstPageReturns() async {
        let fixture = GroomerSandboxSession(state: .loaded)
        let workspace = workspace(fixture, repository: GroomerRequestRepositoryFake())
        #expect(workspace.cachedMatches(location: nil) == fixture.requests.matchedRequests)
        #expect(workspace.cachedOffers(group: "waiting") == fixture.offers.offers)
        #expect(workspace.cachedBookings(closed: false) == fixture.bookings.bookings)
        #expect(!workspace.hasLoadedPage("matches/all"), "Store fallback must not suppress the authoritative page fetch")
        await workspace.refresh(.matches)
        #expect(workspace.hasLoadedPage("matches/all"))
        #expect(workspace.cachedMatches(location: nil).isEmpty, "An authoritative empty page must replace cached Store rows")
    }

    @Test func recycledCardsReusePortraitsAndFailuresRemainRetryable() async {
        let fixture = GroomerSandboxSession(state: .loaded)
        let repository = GroomerRequestRepositoryFake()
        let workspace = workspace(fixture, repository: repository)
        let id = UUID(), bytes = Data("portrait".utf8)
        repository.petPhotoResult = .success(bytes)
        await workspace.loadPetPhoto(requestID: id)
        await workspace.loadPetPhoto(requestID: id)
        #expect(repository.petPhotoReadCount == 1)
        #expect(workspace.photo(for: id) == bytes)
        let failed = UUID()
        repository.petPhotoResult = .failure(.networkUnavailable)
        await workspace.loadPetPhoto(requestID: failed)
        repository.petPhotoResult = .success(bytes)
        await workspace.loadPetPhoto(requestID: failed)
        #expect(repository.petPhotoReadCount == 3)
        #expect(workspace.photo(for: failed) == bytes)
    }

    @Test func adjacentPrefetchWaitsForCurrentPageAndNeverWalksAllPages() async {
        let fixture = GroomerSandboxSession(state: .loaded)
        let repository = GroomerRequestRepositoryFake()
        let workspace = workspace(fixture, repository: repository)
        await workspace.prefetchAdjacent(to: .matches)
        #expect(repository.rankedRequests.isEmpty)
        await workspace.refresh(.matches)
        await workspace.prefetchAdjacent(to: .matches)
        #expect(repository.groomingLocations.count == 2)
        #expect(repository.groomingLocations.last! == .customerComesToGroomer)
        #expect(repository.rankedRequests.allSatisfy { $0.cursor == nil })
        await workspace.prefetchAdjacent(to: .matches)
        #expect(repository.rankedRequests.count == 2, "A cached neighbour is not fetched again")
        #expect(!workspace.hasLoadedPage("matches/" + GroomingLocationMode.groomerComesToCustomer.rawValue))
    }

    @Test func neighbourWarmupIsLimitedToTwoPortraits() async {
        let fixture = GroomerSandboxSession(state: .loaded)
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .success(GroomerSandboxFixtures.matches()))
        repository.petPhotoResult = .success(Data("portrait".utf8))
        let workspace = workspace(fixture, repository: repository)
        await workspace.refresh(.matches)
        await workspace.prefetchAdjacent(to: .matches)
        #expect(repository.petPhotoReadCount == 2)
        await workspace.prefetchAdjacent(to: .matches)
        #expect(repository.petPhotoReadCount == 2)
        #expect(repository.rankedRequests.count == 2)
    }

    @Test func foregroundJoinsAnInFlightNeighbourWithoutDuplicateRequest() async throws {
        let fixture = GroomerSandboxSession(state: .loaded)
        let repository = GroomerRequestRepositoryFake()
        let workspace = workspace(fixture, repository: repository)
        await workspace.refresh(.matches)
        var release: CheckedContinuation<Void, Never>?
        repository.onRankedRead = { await withCheckedContinuation { release = $0 } }
        let speculative = Task { await workspace.prefetchAdjacent(to: .matches) }
        for _ in 0..<100 where release == nil { await Task.yield() }
        let gate = try #require(release)
        workspace.select(location: .customerComesToGroomer, offers: "waiting", bookingsClosed: false)
        workspace.prioritize(.matches)
        var foregroundStarted = false
        let foreground = Task { foregroundStarted = true; await workspace.refresh(.matches) }
        for _ in 0..<100 where !foregroundStarted { await Task.yield() }
        #expect(foregroundStarted)
        #expect(repository.rankedRequests.count == 2)
        gate.resume()
        await speculative.value
        await foreground.value
        #expect(repository.rankedRequests.count == 2)
        #expect(workspace.loaded.contains(.matches))
    }

    @Test func pagedMatchesCanOpenInTheExistingStoreAndRestoreTheirScope() async throws {
        let fixture = GroomerSandboxSession(state: .loaded)
        let rows = Array(GroomerSandboxFixtures.matches().prefix(4))
        let repository = GroomerRequestRepositoryFake()
        func page(_ items: [GroomerMatchedRequest], next: String?) -> RankedPage<GroomerMatchedRequest> {
            RankedPage(items: items, rankingRevision: "fixture", scoreAsOf: Date(timeIntervalSince1970: 1),
                validUntil: Date(timeIntervalSince1970: 301), algorithmVersion: "matching-v1",
                requestedMode: fixture.requests.sort.rawValue, effectiveMode: fixture.requests.sort.rawValue,
                pendingCount: 0, assessmentCount: 0, nextCursor: next)
        }
        repository.rankedPages = [.success(page(Array(rows.prefix(2)), next: "2")),
                                  .success(page(Array(rows.suffix(2)), next: nil))]
        let workspace = workspace(fixture, repository: repository)
        workspace.select(location: nil, offers: "waiting", bookingsClosed: false)
        await workspace.refresh(.matches)
        #expect(workspace.errors[.matches] == nil)
        #expect(workspace.matches.count == 2)
        #expect(workspace.cachedMatches(location: nil) == workspace.matches)
        #expect(workspace.cachedMatches(location: .customerComesToGroomer).isEmpty)
        #expect(workspace.hasLoadedPage("matches/all"))
        #expect(!workspace.hasLoadedPage("matches/" + GroomingLocationMode.customerComesToGroomer.rawValue))
        #expect(workspace.hasMore(.matches))
        let first = try #require(workspace.matches.first)
        await fixture.requests.openDetail(matchID: first.id)
        #expect(fixture.requests.authorizedDetail?.id == first.id)
        await workspace.loadMore(.matches)
        #expect(workspace.matches.count == 4)
        #expect(Set(workspace.matches.map(\.id)).count == 4)
        let cached = workspace.matches
        workspace.select(location: .customerComesToGroomer, offers: "waiting", bookingsClosed: false)
        #expect(!workspace.loaded.contains(.matches))
        #expect(workspace.matches.isEmpty)
        #expect(workspace.cachedMatches(location: nil) == cached, "The outgoing page keeps its own rows during a swipe")
        workspace.select(location: nil, offers: "waiting", bookingsClosed: false)
        #expect(workspace.loaded.contains(.matches))
        #expect(workspace.matches == cached)
    }

    @Test func retiredSessionCannotPublishAnInFlightPage() async {
        let fixture = GroomerSandboxSession(state: .loading)
        var active = true
        let repository = GroomerRequestRepositoryFake()
        repository.onRankedRead = { try? await fixture.boundary.check() }
        let workspace = workspace(fixture, repository: repository, isCurrent: { active })
        let read = Task { await workspace.refresh(.matches) }
        await Task.yield()
        active = false
        fixture.boundary.release()
        await read.value
        #expect(workspace.matches.isEmpty)
        #expect(workspace.loaded.isEmpty)
        #expect(workspace.errors.isEmpty)
    }

    @Test func exactOfferLookupDoesNotDependOnTheFirstPage() async throws {
        let fixture = GroomerSandboxSession(state: .loaded)
        let repository = GroomerRequestRepositoryFake()
        let items = GroomerSandboxFixtures.offers()
        repository.offersResult = .success(Array(items.prefix(1)))
        repository.offerReadResult = .success(items.last?.offer)
        let workspace = workspace(fixture, repository: repository)
        await workspace.refresh(.offers)
        #expect(workspace.offers.count == 1)
        let id = try #require(GroomerSandboxFixtures.offers().last?.id)
        #expect(workspace.offers.first?.id != id)
        let detail = try await workspace.offerItem(id: id)
        #expect(detail?.id == id)
        #expect(workspace.offers.count == 1, "Opening a detail must not eagerly fetch every list page")
    }
}
