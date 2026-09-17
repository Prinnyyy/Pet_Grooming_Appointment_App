import Foundation

struct MarketplaceProfile: Equatable, Sendable {
    let userID: UUID
    let role: UserRole
    let displayName: String
}
