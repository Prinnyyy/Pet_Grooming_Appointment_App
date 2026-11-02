import SwiftUI
import XCTest
@testable import Beckon

@MainActor final class GroomerFirstReadContinuityTests: XCTestCase {
    func testSegmentLabelKeepsItsWidthWhenTheFirstCountArrives() async {
        let session = GroomerSandboxSession(state: .loaded)
        let view = GroomerRequestsView(route: .constant(.matches), requests: session.requests, offers: session.offers)
        let unknown = GroomerRequestsSegment.allCases.map { width(view.segmentChip($0)) }
        await session.requests.load()
        await session.offers.load()
        for (index, segment) in GroomerRequestsSegment.allCases.enumerated() {
            XCTAssertEqual(width(view.segmentChip(segment)), unknown[index], accuracy: 0.5, "\(segment)")
        }
    }

    func testAccountUsesItsCachedIdentityBeforeStartingAnyRequest() {
        let owner = UUID()
        let cache = GroomerProfileSnapshotCacheFake(snapshot: ProfileSnapshot(userID: owner,
            displayName: "Saved Grooming Studio", detailText: "Saved rating", avatarData: nil))
        let store = GroomerProfileStore(groomerID: owner, repository: GroomerProfileRepositoryFake(), profileSnapshotCache: cache)
        XCTAssertEqual(store.profileDisplayName, "Saved Grooming Studio")
        XCTAssertEqual(store.profileDetailText, "Saved rating")
    }

    func testAccountSummariesSurviveRestartIdentityWritesAndRefreshFailuresWithoutAuthorizingEdits() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GroomerSandboxSession(state: .loaded)
        let cache = FileProfileSnapshotCache(directoryURL: directory)
        let first = GroomerProfileStore(groomerID: session.groomerID, repository: session.profileRepository, profileSnapshotCache: cache)
        await first.load()
        XCTAssertTrue(first.hasResolvedAccountSummary)
        let expected = first.accountPresentation
        XCTAssertNotNil(cache.snapshot(userID: session.groomerID)?.groomerAccountSummary)

        // Home writes identity to this same cache. It must not discard Account's richer display snapshot.
        cache.save(ProfileSnapshot(userID: session.groomerID, displayName: first.profileDisplayName, detailText: nil, avatarData: nil))
        let restartedCache = FileProfileSnapshotCache(directoryURL: directory)
        let repository = GroomerProfileRepositoryFake()
        let second = GroomerProfileStore(groomerID: session.groomerID, repository: repository, profileSnapshotCache: restartedCache)
        XCTAssertEqual(second.accountPresentation, expected)
        XCTAssertNil(second.profile)
        XCTAssertTrue(second.services.isEmpty)
        XCTAssertNil(second.savedAvailability)
        XCTAssertFalse(second.canEditFitSignals)
        XCTAssertFalse(second.canEditPortfolioTags)
        XCTAssertNil(restartedCache.snapshot(userID: UUID()))

        await second.load() // Network failure must not turn known summaries into zeros.
        XCTAssertNotNil(second.loadErrorMessage)
        XCTAssertEqual(second.accountPresentation, expected)

        // A successful empty result replaces cached counts; a failed optional read retains its old display value only.
        repository.profileResult = .success(try XCTUnwrap(first.profile))
        repository.fitClaimsResult = .failure(.unavailable)
        await second.load()
        XCTAssertEqual(second.accountPresentation.servicesSummary, "No active services")
        XCTAssertEqual(second.accountPresentation.portfolioSummary, "No photos")
        XCTAssertEqual(second.accountPresentation.evidenceSummary, "No evidence")
        XCTAssertEqual(second.accountPresentation.fitSignalsSummary, expected.fitSignalsSummary)
        XCTAssertFalse(second.canEditFitSignals)
        XCTAssertEqual(restartedCache.snapshot(userID: session.groomerID)?.groomerAccountSummary?.portfolioPhotoCount, 0)
        restartedCache.remove(userID: session.groomerID)
        XCTAssertNil(restartedCache.snapshot(userID: session.groomerID))
    }

    func testLegacyIdentitySnapshotsStillDecode() throws {
        let owner = UUID()
        let data = Data("{\"userID\":\"\(owner.uuidString)\",\"displayName\":\"Legacy studio\"}".utf8)
        let snapshot = try JSONDecoder().decode(ProfileSnapshot.self, from: data)
        XCTAssertEqual(snapshot.displayName, "Legacy studio")
        XCTAssertNil(snapshot.groomerAccountSummary)
    }

    private func width<V: View>(_ view: V) -> CGFloat {
        let host = UIHostingController(rootView: view.fixedSize(horizontal: true, vertical: false)
            .environment(\.beckonRole, .groomer).environment(\.scenePhase, .inactive))
        return host.sizeThatFits(in: CGSize(width: 1000, height: 500)).width
    }
}
