import Foundation

nonisolated struct MarketplaceGroomerSummaryRow: Decodable, Sendable {
    let id: UUID
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    let city: String?
    let state: String?
    let ratingSum: Int?
    let ratingCount: Int
    let isVerified: Bool
    let avatarPath: String?

    func summary() throws -> MarketplaceGroomerSummary {
        guard ratingCount >= 0,
              yearsExperience.map({ (0...80).contains($0) }) ?? true,
              avatarPath.map({ $0.split(separator: "/").count == 2 && $0.hasPrefix(id.uuidString.lowercased() + "/") }) ?? true
        else { throw RequestDiscoveryError.unavailable }
        return MarketplaceGroomerSummary(id: id, businessName: businessName, bio: bio,
            yearsExperience: yearsExperience, city: city, state: state, ratingSum: ratingSum,
            ratingCount: ratingCount, isVerified: isVerified, avatarPath: avatarPath)
    }

    private enum CodingKeys: String, CodingKey {
        case id, bio, city, state
        case businessName = "business_name", yearsExperience = "years_experience"
        case ratingSum = "rating_sum", ratingCount = "rating_count", isVerified = "is_verified", avatarPath = "avatar_path"
    }
}
