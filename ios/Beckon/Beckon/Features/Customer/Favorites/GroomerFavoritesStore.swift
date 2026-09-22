import Foundation
import Observation

@MainActor
@Observable
final class GroomerFavoritesStore {
    let customerID: UUID
    private(set) var states: [UUID: GroomerFavoriteState] = [:]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var error: RequestDiscoveryError?
    private(set) var mutatingIDs: Set<UUID> = []
    private(set) var readEpoch: UInt64 = 0
    private(set) var nextCursor: String?
    private(set) var listNeedsReload = false
    private(set) var scope: GroomerDiscoveryScope?
    private var entities: [UUID: FavoriteGroomer] = [:]
    private var orderedIDs: [UUID] = []
    private var stateEpochs: [UUID: UInt64] = [:]
    private var revision: String?
    private var listGeneration: UInt64 = 0
    private var sessionGeneration: UInt64 = 0
    private var sessionReadFloor: UInt64 = 0
    private let repository: any GroomerFavoritesRepository
    private let sessionIsCurrent: () -> Bool

    init(customerID: UUID, repository: any GroomerFavoritesRepository,
         sessionIsCurrent: @escaping () -> Bool = { true }) {
        self.customerID = customerID
        self.repository = repository
        self.sessionIsCurrent = sessionIsCurrent
    }

    var items: [FavoriteGroomer] {
        orderedIDs.compactMap { id in states[id]?.isFavorite == false ? nil : entities[id] }
    }

    func state(for id: UUID) -> GroomerFavoriteState? { states[id] }

    func merge(_ incoming: [UUID: GroomerFavoriteState], since epoch: UInt64) {
        guard sessionIsCurrent(), epoch >= sessionReadFloor else { return }
        for (id, state) in incoming where !mutatingIDs.contains(id) && stateEpochs[id, default: 0] <= epoch {
            states[id] = state
        }
    }

    func setFavorite(_ id: UUID, enabled: Bool) async {
        guard sessionIsCurrent(), !mutatingIDs.contains(id) else { return }
        let session = sessionGeneration
        let previous = states[id] ?? .init(isFavorite: false, revision: nil)
        readEpoch &+= 1
        stateEpochs[id] = readEpoch
        states[id] = .init(isFavorite: enabled, revision: previous.revision)
        mutatingIDs.insert(id)
        error = nil
        do {
            let accepted = try await repository.setFavorite(groomerID: id, isFavorite: enabled, expectedRevision: previous.revision)
            guard session == sessionGeneration, sessionIsCurrent() else { return }
            states[id] = accepted
            nextCursor = nil
            listNeedsReload = true
        } catch {
            guard session == sessionGeneration, sessionIsCurrent() else { return }
            let failure = normalizedError(error)
            if case let .favoriteChanged(actual) = failure { states[id] = actual }
            else { states[id] = previous }
            self.error = failure == .cancelled ? nil : failure
        }
        readEpoch &+= 1
        stateEpochs[id] = readEpoch
        mutatingIDs.remove(id)
    }

    func load(scope: GroomerDiscoveryScope?) async {
        listGeneration &+= 1
        if self.scope != scope {
            self.scope = scope
            entities = [:]
            orderedIDs = []
            hasLoaded = false
        }
        nextCursor = nil
        revision = nil
        await read(cursor: nil, generation: listGeneration)
    }

    func loadMore() async {
        if listNeedsReload { await load(scope: scope); return }
        guard !isLoading, let nextCursor else { return }
        await read(cursor: nextCursor, generation: listGeneration)
    }

    private func read(cursor: String?, generation: UInt64) async {
        guard sessionIsCurrent() else { return }
        let epoch = readEpoch, session = sessionGeneration
        isLoading = true
        error = nil
        defer { if generation == listGeneration { isLoading = false } }
        do {
            let page = try await repository.favorites(scope: scope, limit: 25, cursor: cursor)
            try Task.checkCancellation()
            guard generation == listGeneration, session == sessionGeneration, sessionIsCurrent() else { return }
            if cursor != nil && revision != page.revision { throw RequestDiscoveryError.listChanged }
            if cursor == nil { entities = [:]; orderedIDs = [] }
            for item in page.items {
                if entities[item.id] == nil { orderedIDs.append(item.id) }
                entities[item.id] = item
            }
            merge(Dictionary(uniqueKeysWithValues: page.items.map { ($0.id, $0.favoriteState) }), since: epoch)
            revision = page.revision
            nextCursor = readEpoch == epoch ? page.nextCursor : nil
            listNeedsReload = readEpoch != epoch
            hasLoaded = true
        } catch {
            guard generation == listGeneration, session == sessionGeneration, sessionIsCurrent() else { return }
            let failure = normalizedError(error)
            if failure != .cancelled { self.error = failure }
            if failure == .listChanged { nextCursor = nil; listNeedsReload = true }
        }
    }

    func clearSession() {
        sessionGeneration &+= 1
        listGeneration &+= 1
        readEpoch &+= 1
        sessionReadFloor = readEpoch
        states = [:]; stateEpochs = [:]; entities = [:]; orderedIDs = []
        mutatingIDs = []; nextCursor = nil; revision = nil; scope = nil
        isLoading = false; hasLoaded = false; listNeedsReload = false; error = nil
    }

    private func normalizedError(_ error: any Error) -> RequestDiscoveryError {
        if error is CancellationError { return .cancelled }
        return (error as? RequestDiscoveryError) ?? .unavailable
    }
}
