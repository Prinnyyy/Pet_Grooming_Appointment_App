import Foundation

@MainActor
protocol CustomerGroomerDiscoveryRepository: AnyObject {
    func prepare(draftID: UUID, draft: GroomingRequestDraft) async throws -> DiscoverySession
    func candidates(scope: GroomerDiscoveryScope,
                    page: RankedPageRequest<GroomerDiscoverySort>) async throws -> RankedPage<DiscoveredGroomer>
    func profile(scope: GroomerDiscoveryScope, groomerID: UUID) async throws -> DiscoveredGroomer
}
