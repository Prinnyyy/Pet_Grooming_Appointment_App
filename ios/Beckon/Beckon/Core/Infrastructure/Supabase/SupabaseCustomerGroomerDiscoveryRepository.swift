import Foundation
import Supabase

@MainActor
final class SupabaseCustomerGroomerDiscoveryRepository: CustomerGroomerDiscoveryRepository {
    private let client: SupabaseClient
    #if DEBUG && targetEnvironment(simulator)
    private var faultScope: GroomerDiscoveryScope?
    private var didReadFaultScope = false
    #endif

    init(client: SupabaseClient) { self.client = client }

    func prepare(draftID: UUID, draft: GroomingRequestDraft) async throws -> DiscoverySession {
        do {
            let row: RequestDiscoverySessionRow = try await client.rpc("prepare_request_discovery_v1",
                params: PrepareRequestDiscoveryParameters(draftID: draftID, draft: draft)).execute().value
            let session = try row.session()
            #if DEBUG && targetEnvironment(simulator)
            if DebugDiscoveryBrowseFault.failsReadAfterInitialPage(draft: draft, customerID: client.auth.currentSession?.user.id,
                arguments: ProcessInfo.processInfo.arguments) {
                faultScope = session.scope
                didReadFaultScope = false
            }
            #endif
            return session
        } catch { throw RequestDiscoveryWireError.map(error) }
    }

    func candidates(scope: GroomerDiscoveryScope, page: RankedPageRequest<GroomerDiscoverySort>) async throws -> RankedPage<DiscoveredGroomer> {
        #if DEBUG && targetEnvironment(simulator)
        if faultScope == scope && didReadFaultScope {
            faultScope = nil
            throw RequestDiscoveryError.networkUnavailable
        }
        #endif
        do {
            let row: RankedPageRow<DiscoveredGroomerRow> = try await client.rpc("get_request_groomer_candidates_v1",
                params: RequestGroomerCandidatesParameters(p_scope: .init(scope: scope), p_sort: page.mode.rawValue,
                    p_limit: page.limit, p_cursor: page.cursor)).execute().value
            let result = try row.page()
            guard result.requestedMode == page.mode.rawValue,
                  result.effectiveMode == page.mode.rawValue || (page.mode == .fit && result.effectiveMode == "distance") else {
                throw RequestDiscoveryError.unavailable
            }
            let candidates = try result.mapping { try $0.groomer() }
            #if DEBUG && targetEnvironment(simulator)
            if faultScope == scope { didReadFaultScope = true }
            #endif
            return candidates
        } catch { throw RequestDiscoveryWireError.map(error) }
    }

    func profile(scope: GroomerDiscoveryScope, groomerID: UUID) async throws -> DiscoveredGroomer {
        do {
            let row: DiscoveredGroomerRow = try await client.rpc("get_discovery_groomer_profile_v1",
                params: DiscoveryGroomerProfileParameters(p_scope: .init(scope: scope), p_groomer_id: groomerID)).execute().value
            guard row.groomerID == groomerID else { throw RequestDiscoveryError.notAllowed }
            return try row.groomer()
        } catch { throw RequestDiscoveryWireError.map(error) }
    }
}

struct PrepareRequestDiscoveryParameters: Encodable {
    let draftID: UUID
    let draft: GroomingRequestDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draftID.uuidString.lowercased(), forKey: .draftID)
        try container.encode(GroomingRequestInput(draft: draft, includesDiscoveryContext: true), forKey: .input)
    }

    private enum CodingKeys: String, CodingKey { case draftID = "p_draft_id", input = "p_input" }
}

nonisolated struct RequestDiscoveryScopeParameters: Encodable, Sendable {
    let scope: GroomerDiscoveryScope

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch scope {
        case let .preview(id, digest):
            try container.encode("preview", forKey: .kind)
            try container.encode(id.uuidString.lowercased(), forKey: .id)
            try container.encode(digest, forKey: .inputDigest)
        case let .request(id, revision):
            try container.encode("request", forKey: .kind)
            try container.encode(id.uuidString.lowercased(), forKey: .id)
            try container.encode(revision.uuidString.lowercased(), forKey: .termsRevision)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind, id, inputDigest = "input_digest", termsRevision = "terms_revision"
    }
}

private struct RequestGroomerCandidatesParameters: Encodable {
    let p_scope: RequestDiscoveryScopeParameters
    let p_sort: String
    let p_limit: Int
    let p_cursor: String?
}

private struct DiscoveryGroomerProfileParameters: Encodable {
    let p_scope: RequestDiscoveryScopeParameters
    let p_groomer_id: UUID
}

nonisolated struct RequestDiscoverySessionRow: Decodable, Sendable {
    let sessionID: UUID
    let inputDigest: String
    let expiresAt: String

    func session() throws -> DiscoverySession {
        guard inputDigest.count == 64, inputDigest.allSatisfy({ $0.isHexDigit }),
              let expiry = GroomingRequestDateFormatting.parsedDate(from: expiresAt) else {
            throw RequestDiscoveryError.unavailable
        }
        return DiscoverySession(id: sessionID, inputDigest: inputDigest, expiresAt: expiry)
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", inputDigest = "input_digest", expiresAt = "expires_at"
    }
}

nonisolated struct GroomerFavoriteStateRow: Decodable, Sendable {
    let isFavorite: Bool
    let revision: UUID?
    var state: GroomerFavoriteState { .init(isFavorite: isFavorite, revision: revision) }
    private enum CodingKeys: String, CodingKey { case isFavorite = "is_favorite", revision }
}

nonisolated struct DiscoveredGroomerRow: Decodable, Sendable {
    let groomerID: UUID
    let safeProfile: MarketplaceGroomerSummaryRow
    let eligibility: MatchEligibilityEvaluation
    let matchingEvidence: MatchingEvidence?
    let distanceMiles: Double
    let referencePrice: ReferencePriceRow?
    let favoriteState: GroomerFavoriteStateRow
    let invitationState: RequestInvitationState

    func groomer() throws -> DiscoveredGroomer {
        guard groomerID == safeProfile.id else { throw RequestDiscoveryError.notAllowed }
        guard distanceMiles.isFinite, distanceMiles >= 0,
              ["estimated_fit", "assessment_required"].contains(eligibility.state) else {
            throw RequestDiscoveryError.unavailable
        }
        return DiscoveredGroomer(profile: try safeProfile.summary(), eligibility: eligibility,
            matchingEvidence: matchingEvidence, distanceMiles: distanceMiles,
            referencePrice: try referencePrice?.price(), favoriteState: favoriteState.state, invitationState: invitationState)
    }

    private enum CodingKeys: String, CodingKey {
        case eligibility
        case groomerID = "groomer_id", safeProfile = "safe_profile", matchingEvidence = "matching_evidence"
        case distanceMiles = "distance_miles", referencePrice = "reference_price"
        case favoriteState = "favorite_state", invitationState = "invitation_state"
    }
}

nonisolated struct ReferencePriceRow: Decodable, Sendable {
    let amount: Decimal
    let currency: String
    let serviceID: UUID
    let referenceOnly: Bool

    func price() throws -> GroomerReferencePrice {
        guard !amount.isNaN, amount >= 0, amount <= 100_000, currency == "USD", referenceOnly else {
            throw RequestDiscoveryError.unavailable
        }
        return GroomerReferencePrice(amount: amount, currency: currency, serviceID: serviceID)
    }

    private enum CodingKeys: String, CodingKey {
        case amount, currency, serviceID = "service_id", referenceOnly = "reference_only"
    }
}

enum RequestDiscoveryWireError {
    static func map(_ error: any Error) -> RequestDiscoveryError {
        if AppDebugErrorClassifier.isCancellation(error) { return .cancelled }
        if let known = error as? RequestDiscoveryError { return known }
        if let known = error as? MatchRankingError {
            return switch known { case .invalidCursor: .invalidCursor; case .listChanged: .listChanged; case .unavailable: .unavailable }
        }
        if let response = error as? PostgrestError {
            switch response.message {
            case "not_allowed", "authenticated_user_required", "customer_profile_required": return .notAllowed
            case "discovery_expired": return .discoveryExpired
            case "discovery_changed": return .discoveryChanged
            case "request_changed": return .requestChanged
            case "distribution_changed": return .distributionChanged
            case "list_changed": return .listChanged
            case "invalid_cursor": return .invalidCursor
            case "groomer_unavailable": return .groomerUnavailable
            case "invitation_limit_reached": return .invitationLimitReached
            case "favorite_limit_reached": return .favoriteLimitReached
            case "favorite_changed":
                if let detail = response.detail, let data = detail.data(using: .utf8),
                   let state = try? JSONDecoder().decode(GroomerFavoriteStateRow.self, from: data) {
                    return .favoriteChanged(state.state)
                }
                return .unavailable
            case "open_request_limit_exceeded": return .requestLimitExceeded
            case "discovery_session_limit_reached": return .previewLimitReached
            case "operation_intent_changed": return .operationIntentChanged
            case "client_update_required": return .clientUpdateRequired
            case "already_published":
                if let details = response.detail, let id = UUID(uuidString: details) { return .alreadyPublished(id) }
            default: break
            }
            if ["42501", "28000"].contains(response.code) { return .notAllowed }
            if response.code == "22023" { return .invalidInput }
        }
        if error is URLError { return .networkUnavailable }
        return .unavailable
    }
}
