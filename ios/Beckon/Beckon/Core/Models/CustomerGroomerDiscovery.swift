import Foundation

nonisolated enum GroomerDiscoveryScope: Equatable, Sendable {
    case preview(sessionID: UUID, inputDigest: String)
    case request(id: UUID, termsRevision: UUID)
}

nonisolated enum GroomerDiscoverySort: String, Codable, CaseIterable, Sendable {
    case fit, distance
    var title: String { self == .fit ? "Recommended" : "Nearest" }
}

nonisolated struct DiscoverySession: Codable, Equatable, Sendable {
    let id: UUID
    let inputDigest: String
    let expiresAt: Date
    var scope: GroomerDiscoveryScope { .preview(sessionID: id, inputDigest: inputDigest) }
}

nonisolated struct GroomerReferencePrice: Equatable, Sendable {
    let amount: Decimal
    let currency: String
    let serviceID: UUID
}

nonisolated enum RequestInvitationState: String, Decodable, Hashable, Sendable {
    case notSent = "not_sent"
    case awaitingResponse = "awaiting_response"
    case offered, declined, withdrawn, expired, closed
}

nonisolated struct GroomerFavoriteState: Equatable, Sendable {
    let isFavorite: Bool
    let revision: UUID?
}

nonisolated struct DiscoveredGroomer: Equatable, Identifiable, Sendable {
    let profile: MarketplaceGroomerSummary
    let eligibility: MatchEligibilityEvaluation
    let matchingEvidence: MatchingEvidence?
    let distanceMiles: Double
    let referencePrice: GroomerReferencePrice?
    let favoriteState: GroomerFavoriteState
    let invitationState: RequestInvitationState
    var id: UUID { profile.id }
}

nonisolated enum RequestDiscoveryError: Error, Equatable, Sendable {
    case notAllowed, discoveryExpired, discoveryChanged, requestChanged, distributionChanged
    case listChanged, invalidCursor, groomerUnavailable, invitationLimitReached, requestLimitExceeded
    case operationIntentChanged, alreadyPublished(UUID), clientUpdateRequired
    case networkUnavailable, cancelled, unavailable
    case invalidInput, previewLimitReached
    case favoriteChanged(GroomerFavoriteState), favoriteLimitReached

    var message: String {
        switch self {
        case .notAllowed: "This request or profile is no longer available to this account."
        case .discoveryExpired: "This preview expired. Review your request to refresh the groomers."
        case .discoveryChanged: "Your pet or address details changed. Review the request before sending."
        case .requestChanged: "This request changed or closed. Refresh its current status."
        case .distributionChanged: "Invitations or pool settings changed on another device. Refresh and try again."
        case .listChanged, .invalidCursor: "Availability changed. Refresh the list before continuing."
        case .groomerUnavailable: "A selected groomer is no longer available for this request."
        case .invitationLimitReached: "You can have up to five active invited groomers. Withdraw an unanswered invitation first."
        case .requestLimitExceeded: "You already have three open requests. Close one before sending another."
        case .operationIntentChanged: "A previous action still needs confirmation. Retry that action first."
        case .alreadyPublished: "This request was already sent. Refresh to continue with the existing request."
        case .clientUpdateRequired: "Update Beckon to continue. Your saved request has not been changed."
        case .favoriteChanged: "Your favorites changed on another device. The latest state is shown."
        case .favoriteLimitReached: "You can save up to 500 groomers. Remove a favorite to add another."
        case .previewLimitReached: "You have several active previews. Continue an existing preview or try again later."
        case .invalidInput: "Check the request details and your selected groomers."
        case .networkUnavailable: "Could not connect. Your action has not been confirmed; retry to check it."
        case .cancelled: "The action was interrupted. Retry to check its status."
        case .unavailable: "Could not load the latest information. Please try again."
        }
    }

    var invalidatesBrowse: Bool {
        switch self {
        case .notAllowed, .discoveryExpired, .discoveryChanged, .requestChanged,
             .listChanged, .invalidCursor, .clientUpdateRequired: true
        default: false
        }
    }
}
