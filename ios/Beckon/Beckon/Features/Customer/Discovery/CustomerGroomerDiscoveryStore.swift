import Foundation
import Observation

@MainActor
@Observable
final class CustomerGroomerDiscoveryStore {
    private(set) var scope: GroomerDiscoveryScope
    private(set) var actionScope: GroomerDiscoveryScope
    private(set) var sort: GroomerDiscoverySort = .fit
    private(set) var isShowingAll = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: RequestDiscoveryError?
    private(set) var page: RankedPage<DiscoveredGroomer>?
    var deckSelection: GroomerDiscoveryDeckSelection?
    private(set) var deckRevision = UUID()

    private var entities: [UUID: DiscoveredGroomer] = [:]
    private var orderedIDs: [UUID] = []
    @ObservationIgnored private let repository: any CustomerGroomerDiscoveryRepository
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var sessionIsValid = true
    @ObservationIgnored private var readTask: Task<RankedPage<DiscoveredGroomer>, any Error>?

    init(scope: GroomerDiscoveryScope, repository: any CustomerGroomerDiscoveryRepository) {
        self.scope = scope
        self.actionScope = scope
        self.repository = repository
    }

    var candidates: [DiscoveredGroomer] { orderedIDs.compactMap { entities[$0] } }
    var recommended: [DiscoveredGroomer] { orderedIDs.prefix(8).compactMap { entities[$0] } }
    var pendingCount: Int { page?.pendingCount ?? 0 }
    var canLoadMore: Bool {
        sessionIsValid && !isLoading && !isLoadingMore && page?.nextCursor != nil
            && page.map { $0.validUntil > Date() } == true && error?.invalidatesBrowse != true
    }

    func showAll() {
        isShowingAll = true
    }
    func showRecommendations() { isShowingAll = false }

    func load() async {
        guard sessionIsValid else { return }
        readTask?.cancel()
        generation = UUID()
        let operation = generation
        scope = actionScope
        isLoading = true
        isLoadingMore = false
        error = nil
        defer { if generation == operation { isLoading = false; readTask = nil } }
        await read(cursor: nil, operation: operation)
    }

    func loadNextPage() async {
        guard canLoadMore, let cursor = page?.nextCursor else { return }
        let operation = generation
        isLoadingMore = true
        error = nil
        defer { if generation == operation { isLoadingMore = false; readTask = nil } }
        await read(cursor: cursor, operation: operation)
    }

    func changeSort(to value: GroomerDiscoverySort) async {
        guard value != sort, sessionIsValid else { return }
        sort = value
        clearBrowse()
        await load()
    }

    func changeScope(to value: GroomerDiscoveryScope) async {
        guard value != actionScope, sessionIsValid else { return }
        actionScope = value
        clearBrowse()
        await load()
    }

    func publicationConfirmed(requestScope: GroomerDiscoveryScope) {
        guard sessionIsValid, case .request = requestScope else { return }
        // The server keeps the original preview scope as a bounded read alias.
        actionScope = requestScope
    }

    func detail(for id: UUID) async throws -> DiscoveredGroomer {
        guard sessionIsValid else { throw RequestDiscoveryError.cancelled }
        let current = generation
        let result = try await repository.profile(scope: actionScope, groomerID: id)
        guard sessionIsValid, current == generation, !Task.isCancelled else { throw RequestDiscoveryError.cancelled }
        guard result.id == id else { throw RequestDiscoveryError.notAllowed }
        return result
    }

    func invalidateSession() {
        sessionIsValid = false
        generation = UUID()
        readTask?.cancel()
        readTask = nil
        clearBrowse()
        isLoading = false
        isLoadingMore = false
        error = nil
    }

    private func read(cursor: String?, operation: UUID) async {
        let requestScope = scope
        let mode = sort
        let task = Task { try await repository.candidates(scope: requestScope,
            page: RankedPageRequest(mode: mode, cursor: cursor)) }
        readTask = task
        do {
            let result = try await task.value
            guard sessionIsValid, operation == generation, !Task.isCancelled else { return }
            guard result.requestedMode == mode.rawValue,
                  Set(result.items.map(\.id)).count == result.items.count,
                  result.items.allSatisfy({ ["estimated_fit", "assessment_required"].contains($0.eligibility.state)
                      && $0.distanceMiles.isFinite && $0.distanceMiles >= 0 }) else {
                throw RequestDiscoveryError.listChanged
            }
            if cursor != nil {
                guard let page, page.canAppend(result),
                      result.items.allSatisfy({ entities[$0.id] == nil }) else { throw RequestDiscoveryError.listChanged }
            } else {
                entities = [:]
                orderedIDs = []
            }
            for item in result.items { entities[item.id] = item; orderedIDs.append(item.id) }
            page = result
            if cursor == nil { deckRevision = UUID() }
            if recommended.isEmpty {
                deckSelection = nil
            } else if case .groomer(let id) = deckSelection,
                      recommended.contains(where: { $0.id == id }) {
                // A refresh may reorder candidates without changing the visible identity.
            } else if deckSelection != .more {
                deckSelection = recommended.first.map { .groomer($0.id) }
            }
        } catch {
            guard sessionIsValid, operation == generation else { return }
            if error is CancellationError || (error as? RequestDiscoveryError) == .cancelled { return }
            let failure = (error as? RequestDiscoveryError) ?? .unavailable
            self.error = failure
            if failure.invalidatesBrowse { clearBrowse() }
        }
    }

    private func clearBrowse() {
        entities = [:]
        orderedIDs = []
        page = nil
        deckSelection = nil
        deckRevision = UUID()
    }
}
