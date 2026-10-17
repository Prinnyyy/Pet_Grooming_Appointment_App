import Foundation
import Testing
@testable import Beckon

@MainActor
struct GroomerFavoritesTests {
    @Test func confirmedFavoriteOutranksAReadThatStartedBeforeTheWrite() async {
        let repo = FavoritesRepositoryFake()
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        let id = UUID(), epoch = store.readEpoch
        store.merge([id: .init(isFavorite: false, revision: nil)], since: epoch)
        await store.setFavorite(id, enabled: true)
        store.merge([id: .init(isFavorite: false, revision: nil)], since: epoch)
        #expect(store.state(for: id)?.isFavorite == true)
        #expect(repo.writes.count == 1)
    }

    @Test func failedFavoriteRollsBackAndRetainsAnError() async {
        let repo = FavoritesRepositoryFake()
        repo.error = .networkUnavailable
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        let id = UUID()
        store.merge([id: .init(isFavorite: false, revision: nil)], since: store.readEpoch)
        await store.setFavorite(id, enabled: true)
        #expect(store.state(for: id)?.isFavorite == false)
        #expect(store.error == .networkUnavailable)
    }

    @Test func conflictUsesServerStateWithoutOverwritingTheOtherDevice() async {
        let repo = FavoritesRepositoryFake(), revision = UUID()
        repo.error = .favoriteChanged(.init(isFavorite: false, revision: revision))
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        let id = UUID()
        await store.setFavorite(id, enabled: true)
        #expect(store.state(for: id) == .init(isFavorite: false, revision: revision))
        #expect(repo.writes.count == 1)
    }

    @Test func clearingTheSessionDiscardsALateWrite() async {
        let repo = FavoritesRepositoryFake()
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        let id = UUID()
        repo.onWrite = { store.clearSession() }
        await store.setFavorite(id, enabled: true)
        #expect(store.state(for: id) == nil)
        #expect(store.items.isEmpty)
    }

    @Test func failedListIsNotAnEmptySuccess() async {
        let repo = FavoritesRepositoryFake()
        repo.error = .networkUnavailable
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        await store.load(scope: nil)
        #expect(store.error == .networkUnavailable)
        #expect(!store.hasLoaded)
    }

    @Test func clearedSessionRejectsLateCandidateSeeds() {
        let store = GroomerFavoritesStore(customerID: UUID(), repository: FavoritesRepositoryFake())
        let oldEpoch = store.readEpoch, id = UUID()
        store.clearSession()
        store.merge([id: .init(isFavorite: true, revision: UUID())], since: oldEpoch)
        #expect(store.state(for: id) == nil)
    }

    @Test func lateListCannotRestoreACursorInvalidatedByAFavoriteWrite() async {
        let repo = FavoritesRepositoryFake()
        let store = GroomerFavoritesStore(customerID: UUID(), repository: repo)
        repo.onRead = { await store.setFavorite(UUID(), enabled: true) }
        repo.page = .init(items: [], nextCursor: "old-cursor", revision: "1", asOf: Date())
        await store.load(scope: nil)
        #expect(store.nextCursor == nil)
        #expect(store.listNeedsReload)
    }
}

@MainActor
final class FavoritesRepositoryFake: GroomerFavoritesRepository {
    var error: RequestDiscoveryError?
    var writes: [UUID] = []
    var onWrite: (() -> Void)?
    var onRead: (() async -> Void)?
    var page = GroomerFavoritesPage(items: [], nextCursor: nil, revision: "1", asOf: Date())
    func setFavorite(groomerID: UUID, isFavorite: Bool, expectedRevision: UUID?) async throws -> GroomerFavoriteState {
        writes.append(groomerID)
        onWrite?()
        if let error { throw error }
        return .init(isFavorite: isFavorite, revision: UUID())
    }
    func favorites(scope: GroomerDiscoveryScope?, limit: Int, cursor: String?) async throws -> GroomerFavoritesPage {
        if let error { throw error }
        await onRead?()
        return page
    }
}
