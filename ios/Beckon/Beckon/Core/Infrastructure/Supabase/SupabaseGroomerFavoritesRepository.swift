import Foundation
import Supabase

@MainActor
final class SupabaseGroomerFavoritesRepository: GroomerFavoritesRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func setFavorite(groomerID: UUID, isFavorite: Bool, expectedRevision: UUID?) async throws -> GroomerFavoriteState {
        do {
            let row: GroomerFavoriteStateRow = try await client.rpc("set_groomer_favorite_v1",
                params: SetGroomerFavoriteParameters(p_groomer_id: groomerID,
                    p_is_favorite: isFavorite, p_expected_revision: expectedRevision)).execute().value
            guard row.isFavorite == isFavorite, !isFavorite || row.revision != nil else { throw RequestDiscoveryError.unavailable }
            return row.state
        } catch { throw RequestDiscoveryWireError.map(error) }
    }

    func favorites(scope: GroomerDiscoveryScope?, limit: Int, cursor: String?) async throws -> GroomerFavoritesPage {
        do {
            let row: GroomerFavoritesPageRow = try await client.rpc("get_my_favorite_groomers_v1",
                params: FavoriteGroomerPageParameters(p_scope: scope.map { .init(scope: $0) },
                    p_limit: limit, p_cursor: cursor)).execute().value
            return try row.page()
        } catch { throw RequestDiscoveryWireError.map(error) }
    }
}

nonisolated private struct SetGroomerFavoriteParameters: Encodable {
    let p_groomer_id: UUID
    let p_is_favorite: Bool
    let p_expected_revision: UUID?
}
nonisolated private struct FavoriteGroomerPageParameters: Encodable {
    let p_scope: RequestDiscoveryScopeParameters?
    let p_limit: Int
    let p_cursor: String?
}

nonisolated struct GroomerFavoritesPageRow: Decodable, Sendable {
    let items: [FavoriteGroomerRow]
    let nextCursor: String?
    let revision: String
    let asOf: String
    func page() throws -> GroomerFavoritesPage {
        guard !revision.isEmpty, let date = GroomingRequestDateFormatting.parsedDate(from: asOf),
              Set(items.map(\.groomerID)).count == items.count else { throw RequestDiscoveryError.unavailable }
        return .init(items: try items.map { try $0.favorite() }, nextCursor: nextCursor, revision: revision, asOf: date)
    }
    private enum CodingKeys: String, CodingKey { case items, nextCursor = "next_cursor", revision, asOf = "as_of" }
}

nonisolated struct FavoriteGroomerRow: Decodable, Sendable {
    let groomerID: UUID
    let favoritedAt: String
    let safeProfile: MarketplaceGroomerSummaryRow?
    let availability: FavoriteGroomerAvailability
    let eligibility: MatchEligibilityEvaluation?
    let favoriteState: GroomerFavoriteStateRow
    let invitationState: RequestInvitationState
    func favorite() throws -> FavoriteGroomer {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: favoritedAt), favoriteState.isFavorite,
              favoriteState.revision != nil, safeProfile == nil || safeProfile?.id == groomerID,
              (availability == .available) == (safeProfile != nil) else { throw RequestDiscoveryError.unavailable }
        return .init(groomerID: groomerID, favoritedAt: date, profile: try safeProfile?.summary(),
            availability: availability, eligibility: eligibility, favoriteState: favoriteState.state, invitationState: invitationState)
    }
    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id", favoritedAt = "favorited_at", safeProfile = "safe_profile", availability, eligibility
        case favoriteState = "favorite_state", invitationState = "invitation_state"
    }
}
