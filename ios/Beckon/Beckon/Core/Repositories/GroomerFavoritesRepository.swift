import Foundation

@MainActor
protocol GroomerFavoritesRepository: AnyObject {
    func setFavorite(groomerID: UUID, isFavorite: Bool, expectedRevision: UUID?) async throws -> GroomerFavoriteState
    func favorites(scope: GroomerDiscoveryScope?, limit: Int, cursor: String?) async throws -> GroomerFavoritesPage
}
