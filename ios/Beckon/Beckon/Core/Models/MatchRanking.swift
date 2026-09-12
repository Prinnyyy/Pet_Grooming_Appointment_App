import Foundation

nonisolated enum GroomerMatchSort: String, Codable, CaseIterable, Sendable {
    case fit, distance, newest

    var title: String {
        switch self {
        case .fit: "Relevant experience"
        case .distance: "Nearest"
        case .newest: "Newest"
        }
    }
}

nonisolated enum CustomerOfferSort: String, Codable, CaseIterable, Sendable {
    case balanced, distance, earliest, price

    var title: String {
        switch self {
        case .balanced: "Recommended"
        case .distance: "Nearest"
        case .earliest: "Earliest appointment"
        case .price: "Lowest price"
        }
    }
}

nonisolated enum MatchRankingError: Error, Equatable, Sendable {
    case listChanged
    case invalidCursor
    case unavailable
}

nonisolated struct RankedPageRequest<Sort: Sendable>: Sendable {
    let mode: Sort
    let limit: Int
    let cursor: String?

    init(mode: Sort, limit: Int = 25, cursor: String? = nil) {
        self.mode = mode
        self.limit = min(50, max(1, limit))
        self.cursor = cursor
    }
}

nonisolated struct RankedPage<Item: Sendable>: Sendable {
    let items: [Item]
    let rankingRevision: String
    let scoreAsOf: Date
    let validUntil: Date
    let algorithmVersion: String
    let requestedMode: String
    let effectiveMode: String
    let pendingCount: Int
    let assessmentCount: Int
    let nextCursor: String?

    func canAppend(_ page: Self) -> Bool {
        rankingRevision == page.rankingRevision
            && scoreAsOf == page.scoreAsOf
            && validUntil == page.validUntil
            && algorithmVersion == page.algorithmVersion
            && requestedMode == page.requestedMode
            && effectiveMode == page.effectiveMode
    }

    func mapping<NewItem: Sendable>(_ transform: (Item) throws -> NewItem) rethrows -> RankedPage<NewItem> {
        RankedPage<NewItem>(items: try items.map(transform), rankingRevision: rankingRevision,
            scoreAsOf: scoreAsOf, validUntil: validUntil, algorithmVersion: algorithmVersion,
            requestedMode: requestedMode, effectiveMode: effectiveMode, pendingCount: pendingCount,
            assessmentCount: assessmentCount, nextCursor: nextCursor)
    }
}

// RPC timestamps use the same fractional-second parser as the booking and request rows.
nonisolated struct RankedPageRow<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let rankingRevision: String
    let scoreAsOf: String
    let validUntil: String
    let algorithmVersion: String
    let requestedMode: String
    let effectiveMode: String
    let pendingCount: Int
    let assessmentCount: Int
    let nextCursor: String?

    func page() throws -> RankedPage<Item> {
        guard let asOf = GroomingRequestDateFormatting.parsedDate(from: scoreAsOf),
              let until = GroomingRequestDateFormatting.parsedDate(from: validUntil),
              until > asOf, algorithmVersion == "matching-v1", !rankingRevision.isEmpty,
              pendingCount >= 0, assessmentCount >= 0 else { throw MatchRankingError.unavailable }
        return RankedPage(items: items, rankingRevision: rankingRevision, scoreAsOf: asOf,
            validUntil: until, algorithmVersion: algorithmVersion, requestedMode: requestedMode,
            effectiveMode: effectiveMode, pendingCount: pendingCount,
            assessmentCount: assessmentCount, nextCursor: nextCursor)
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case rankingRevision = "ranking_revision"
        case scoreAsOf = "score_as_of"
        case validUntil = "valid_until"
        case algorithmVersion = "algorithm_version"
        case requestedMode = "requested_mode"
        case effectiveMode = "effective_mode"
        case pendingCount = "pending_count"
        case assessmentCount = "assessment_count"
        case nextCursor = "next_cursor"
    }
}
