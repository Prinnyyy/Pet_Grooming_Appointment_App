import Foundation

nonisolated enum FavoriteGroomerAvailability: String, Decodable, Sendable {
    case available, paused, unavailable
}

nonisolated struct FavoriteGroomer: Identifiable, Equatable, Sendable {
    let groomerID: UUID
    let favoritedAt: Date
    let profile: MarketplaceGroomerSummary?
    let availability: FavoriteGroomerAvailability
    let eligibility: MatchEligibilityEvaluation?
    let favoriteState: GroomerFavoriteState
    let invitationState: RequestInvitationState
    var id: UUID { groomerID }
}

nonisolated struct GroomerFavoritesPage: Sendable {
    let items: [FavoriteGroomer]
    let nextCursor: String?
    let revision: String
    let asOf: Date
}
