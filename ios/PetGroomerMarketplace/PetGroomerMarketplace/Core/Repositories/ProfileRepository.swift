import Foundation

enum ProfileRepositoryError: Error, Equatable, Sendable {
    case roleImmutable
    case networkUnavailable
    case unavailable
}

@MainActor
protocol ProfileRepository: AnyObject {
    func profile(userID: UUID) async throws -> MarketplaceProfile?

    func createProfile(
        role: UserRole,
        displayName: String
    ) async throws -> MarketplaceProfile
}
