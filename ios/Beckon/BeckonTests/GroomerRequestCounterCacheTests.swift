import XCTest
@testable import Beckon

@MainActor final class GroomerRequestCounterCacheTests: XCTestCase {
    func testCountsAreVisibleBeforeFirstReadButDoNotMarkListsLoaded() async throws {
        let name = "Beckon-Counter-Test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let cache = GroomerRequestCountCache(defaults: defaults)
        let session = GroomerSandboxSession(state: .loaded)
        let owner = session.groomerID
        cache.save(91, groomerID: owner, kind: .matches)
        cache.save(92, groomerID: owner, kind: .offers)
        let requests = GroomerRequestsStore(groomerID: owner, repository: session.requestRepository, countCache: cache)
        let offers = GroomerOffersStore(groomerID: owner, repository: session.requestRepository, countCache: cache)
        XCTAssertEqual(requests.displayedMatchCount(at: Date()), 91)
        XCTAssertEqual(offers.displayedOfferCount, 92)
        XCTAssertFalse(requests.hasLoadedOnce)
        XCTAssertFalse(offers.hasLoadedOnce)
        XCTAssertTrue(requests.matchedRequests.isEmpty && offers.offers.isEmpty)
        XCTAssertNil(cache.count(groomerID: UUID(), kind: .matches))

        await requests.load()
        await offers.load()
        XCTAssertEqual(requests.displayedMatchCount(at: Date()), 4)
        XCTAssertEqual(offers.displayedOfferCount, 4)
        let restartedCache = GroomerRequestCountCache(defaults: try XCTUnwrap(UserDefaults(suiteName: name)))
        XCTAssertEqual(restartedCache.count(groomerID: owner, kind: .matches), 4)
        XCTAssertEqual(restartedCache.count(groomerID: owner, kind: .offers), 4)

        let empty = GroomerSandboxSession(state: .empty)
        let emptyRequests = GroomerRequestsStore(groomerID: owner, repository: empty.requestRepository, countCache: restartedCache)
        let emptyOffers = GroomerOffersStore(groomerID: owner, repository: empty.requestRepository, countCache: restartedCache)
        await emptyRequests.load()
        await emptyOffers.load()
        XCTAssertEqual(restartedCache.count(groomerID: owner, kind: .matches), 0)
        XCTAssertEqual(restartedCache.count(groomerID: owner, kind: .offers), 0)
    }

    func testOldSessionCannotRestoreCountsAfterLogout() async {
        let defaults = HomePreviewMemoryDefaults()
        let cache = GroomerRequestCountCache(defaults: defaults)
        let session = GroomerSandboxSession(state: .loaded)
        var active = true
        let requests = GroomerRequestsStore(groomerID: session.groomerID, repository: session.requestRepository, countCache: cache)
        requests.setSessionValidation { active }
        let offers = GroomerOffersStore(groomerID: session.groomerID, repository: session.requestRepository,
            countCache: cache, sessionIsCurrent: { active })
        await requests.load()
        await offers.load()
        active = false
        cache.remove(groomerID: session.groomerID)
        requests.invalidateSession()
        await offers.load()
        XCTAssertNil(requests.displayedMatchCount(at: Date()))
        XCTAssertNil(offers.displayedOfferCount)
        XCTAssertNil(cache.count(groomerID: session.groomerID, kind: .matches))
        XCTAssertNil(cache.count(groomerID: session.groomerID, kind: .offers))
    }
}
