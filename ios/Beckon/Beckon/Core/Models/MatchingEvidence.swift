import Foundation

nonisolated struct MatchingEvidence: Decodable, Equatable, Hashable, Sendable {
    let state: String
    let algorithmVersion: String
    let scoreAsOf: String?
    let relatedReviewCount: Int
    let independentCustomers: Int
    let completedCount: Int
    let latestServiceAt: String?
    let coverage: [MatchingEvidenceCoverage]
    var sourceRevision: String? = nil

    var summary: String {
        guard algorithmVersion == "matching-v1" else { return "Evidence unavailable" }
        switch state {
        case "available":
            return "\(relatedReviewCount) related reviews from \(independentCustomers) customers"
        case "no_evidence": return "No verified related feedback yet"
        default: return "Evidence unavailable"
        }
    }

    var detail: String {
        guard state == "available", algorithmVersion == "matching-v1" else { return summary }
        let rows = coverage.map {
            "\($0.title): \($0.positiveCount) positive, \($0.negativeCount) negative, \($0.unknownCount) unreported"
        }
        let updated = scoreAsOf.flatMap(GroomingRequestDateFormatting.parsedDate(from:))
            .map { "Updated \($0.formatted(date: .abbreviated, time: .shortened))" }
        return ([summary] + rows + [updated].compactMap { $0 }).joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case state, coverage
        case algorithmVersion = "algorithm_version"
        case scoreAsOf = "score_as_of"
        case relatedReviewCount = "related_review_count"
        case independentCustomers = "independent_customers"
        case completedCount = "completed_count"
        case latestServiceAt = "latest_service_at"
        case sourceRevision = "source_revision"
    }
}

nonisolated struct MatchingEvidenceCoverage: Decodable, Equatable, Hashable, Sendable, Identifiable {
    let dimension: String
    let value: String
    let completedCount: Int
    let positiveCount: Int
    let negativeCount: Int
    let unknownCount: Int

    var id: String { "\(dimension):\(value)" }
    var title: String { ReviewEvidenceKey(dimension: dimension, value: value).signal?.title ?? "Other service detail" }

    private enum CodingKeys: String, CodingKey {
        case dimension, value
        case completedCount = "completed_count"
        case positiveCount = "positive_count"
        case negativeCount = "negative_count"
        case unknownCount = "unknown_count"
    }
}
