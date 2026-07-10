import Foundation
import Supabase

@MainActor
final class SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select("id,role,display_name")
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value

            return rows.first?.profile
        } catch {
            throw Self.map(error)
        }
    }

    func createProfile(
        role: UserRole,
        displayName: String
    ) async throws -> MarketplaceProfile {
        do {
            let rows: [ProfileRow] = try await client
                .rpc(
                    "create_my_profile",
                    params: CreateProfileParameters(
                        role: role,
                        displayName: displayName
                    )
                )
                .execute()
                .value

            guard rows.count == 1, let profile = rows.first?.profile else {
                throw ProfileRepositoryError.unavailable
            }

            return profile
        } catch let error as ProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> ProfileRepositoryError {
        if let postgrestError = error as? PostgrestError,
           postgrestError.code == "P0001",
           postgrestError.message == "profile_role_immutable" {
            return .roleImmutable
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let role: UserRole
    let displayName: String

    var profile: MarketplaceProfile {
        MarketplaceProfile(
            userID: id,
            role: role,
            displayName: displayName
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case displayName = "display_name"
    }
}

private struct CreateProfileParameters: Encodable {
    let role: UserRole
    let displayName: String

    private enum CodingKeys: String, CodingKey {
        case role = "p_role"
        case displayName = "p_display_name"
    }
}
