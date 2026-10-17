import Foundation

nonisolated struct MarketplaceGroomerSummary: Equatable, Identifiable, Sendable {
    let id: UUID
    let businessName: String?
    var bio: String? = nil
    var yearsExperience: Int? = nil
    var city: String? = nil
    var state: String? = nil
    var ratingSum: Int? = nil
    var ratingCount: Int = 0
    var isVerified: Bool = false
    var avatarPath: String? = nil

    var displayName: String { businessName ?? "Groomer \(id.uuidString.prefix(8))" }

    var ratingAverage: Double? {
        guard let ratingSum, ratingCount > 0, ratingSum >= ratingCount,
              Double(ratingSum) <= 5 * Double(ratingCount) else { return nil }
        return Double(ratingSum) / Double(ratingCount)
    }
}
