import Foundation
import Supabase

@MainActor
final class SupabaseGroomerRequestRepository: GroomerRequestRepository {
    private static let matchColumns = """
        id,request_id,groomer_id,customer_id,match_score,match_reason,dismiss_reason,\
        status,viewed_at,dismissed_at,created_at,updated_at
        """
    private static let requestColumns = """
        id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,service_notes,\
        preferred_start,preferred_end,location_mode,street_address,city,state,zip_code,\
        travel_radius_miles,status,expires_at,created_at,updated_at
        """
    private static let offerColumns = """
        id,request_id,match_id,customer_id,groomer_id,proposed_start,proposed_end,\
        price_estimate,message,status,expires_at,withdrawn_at,created_at,updated_at
        """

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        do {
            let matchRows: [GroomerRequestMatchRow] = try await client
                .from("request_matches")
                .select(Self.matchColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .in("status", values: RequestMatchStatus.activeValues)
                .order("created_at", ascending: false)
                .execute()
                .value

            guard !matchRows.isEmpty else { return [] }

            let requestIDs = matchRows.map {
                $0.requestID.uuidString.lowercased()
            }

            let requestRows: [GroomerMatchedGroomingRequestRow] = try await client
                .from("grooming_requests")
                .select(Self.requestColumns)
                .in("id", values: requestIDs)
                .in(
                    "status",
                    values: [
                        GroomingRequestStatus.open.rawValue,
                        GroomingRequestStatus.hasOffers.rawValue,
                    ]
                )
                .execute()
                .value

            let requestsByID = Dictionary(
                uniqueKeysWithValues: requestRows.map { ($0.id, $0.request) }
            )

            let offerRows: [GroomerOfferRow] = try await client
                .from("groomer_offers")
                .select(Self.offerColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .in("request_id", values: requestIDs)
                .order("created_at", ascending: false)
                .execute()
                .value

            var latestOffersByRequestID: [UUID: GroomerOffer] = [:]
            for row in offerRows where latestOffersByRequestID[row.requestID] == nil {
                latestOffersByRequestID[row.requestID] = row.offer
            }

            return matchRows.compactMap { row in
                guard let request = requestsByID[row.requestID] else {
                    return nil
                }

                return GroomerMatchedRequest(
                    match: row.match,
                    request: request,
                    offer: latestOffersByRequestID[row.requestID]
                )
            }
        } catch {
            throw Self.map(error)
        }
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        do {
            let rows: [DismissRequestMatchRow] = try await client
                .rpc(
                    "dismiss_request_match",
                    params: DismissRequestMatchParameters(
                        matchID: matchID,
                        reason: reason
                    )
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw GroomerRequestRepositoryError.unavailable
            }

            return result
        } catch let error as GroomerRequestRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        do {
            let rows: [CreateGroomerOfferRow] = try await client
                .rpc(
                    "create_groomer_offer",
                    params: CreateGroomerOfferParameters(draft: draft)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw GroomerRequestRepositoryError.unavailable
            }

            return result
        } catch let error as GroomerRequestRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        do {
            let rows: [WithdrawGroomerOfferRow] = try await client
                .rpc(
                    "withdraw_groomer_offer",
                    params: WithdrawGroomerOfferParameters(offerID: offerID)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw GroomerRequestRepositoryError.unavailable
            }

            return result
        } catch let error as GroomerRequestRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> GroomerRequestRepositoryError {
        if let repositoryError = error as? GroomerRequestRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "28000":
                return .notAllowed
            case "22023":
                return .invalidInput
            case "P0001":
                switch postgrestError.message {
                case "groomer_profile_required":
                    return .notAllowed
                case "match_not_found":
                    return .matchNotFound
                case "match_not_dismissible":
                    return .noLongerDismissible
                case "request_not_open":
                    return .requestNoLongerOpen
                case "match_not_offerable":
                    return .noLongerOfferable
                case "active_offer_exists":
                    return .activeOfferExists
                case "groomer_unavailable":
                    return .groomerUnavailable
                case "offer_not_found", "invalid_offer":
                    return .offerNotFound
                case "offer_not_withdrawable":
                    return .noLongerWithdrawable
                default:
                    return .unavailable
                }
            default:
                return .unavailable
            }
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

private struct GroomerOfferRow: Decodable {
    let id: UUID
    let requestID: UUID
    let matchID: UUID
    let customerID: UUID
    let groomerID: UUID
    let proposedStart: String
    let proposedEnd: String
    let priceEstimate: Double
    let message: String?
    let status: GroomerOfferStatus
    let expiresAt: String
    let withdrawnAt: String?
    let createdAt: String?
    let updatedAt: String?

    var offer: GroomerOffer {
        GroomerOffer(
            id: id,
            requestID: requestID,
            matchID: matchID,
            customerID: customerID,
            groomerID: groomerID,
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            priceEstimate: priceEstimate,
            message: message,
            status: status,
            expiresAt: expiresAt,
            withdrawnAt: withdrawnAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case matchID = "match_id"
        case customerID = "customer_id"
        case groomerID = "groomer_id"
        case proposedStart = "proposed_start"
        case proposedEnd = "proposed_end"
        case priceEstimate = "price_estimate"
        case message
        case status
        case expiresAt = "expires_at"
        case withdrawnAt = "withdrawn_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct GroomerRequestMatchRow: Decodable {
    let id: UUID
    let requestID: UUID
    let groomerID: UUID
    let customerID: UUID
    let matchScore: Double?
    let matchReason: String?
    let dismissReason: String?
    let status: RequestMatchStatus
    let viewedAt: String?
    let dismissedAt: String?
    let createdAt: String
    let updatedAt: String

    var match: GroomerRequestMatch {
        GroomerRequestMatch(
            id: id,
            requestID: requestID,
            groomerID: groomerID,
            customerID: customerID,
            matchScore: matchScore,
            matchReason: matchReason,
            dismissReason: dismissReason,
            status: status,
            viewedAt: viewedAt,
            dismissedAt: dismissedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case groomerID = "groomer_id"
        case customerID = "customer_id"
        case matchScore = "match_score"
        case matchReason = "match_reason"
        case dismissReason = "dismiss_reason"
        case status
        case viewedAt = "viewed_at"
        case dismissedAt = "dismissed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct GroomerMatchedGroomingRequestRow: Decodable {
    let id: UUID
    let customerID: UUID
    let petID: UUID?
    let petSnapshot: GroomingRequestPetSnapshot
    let photoSnapshot: [GroomingRequestPhotoSnapshot]
    let serviceType: GroomingServiceType
    let serviceNotes: String?
    let preferredStart: String
    let preferredEnd: String
    let locationMode: GroomingLocationMode
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
    let travelRadiusMiles: Int?
    let status: GroomingRequestStatus
    let expiresAt: String
    let createdAt: String
    let updatedAt: String

    var request: GroomerMatchedGroomingRequest {
        GroomerMatchedGroomingRequest(
            id: id,
            customerID: customerID,
            petID: petID,
            petSnapshot: petSnapshot,
            photoSnapshot: photoSnapshot,
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            locationMode: locationMode,
            streetAddress: streetAddress,
            city: city,
            state: state,
            zipCode: zipCode,
            travelRadiusMiles: travelRadiusMiles,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customer_id"
        case petID = "pet_id"
        case petSnapshot = "pet_snapshot"
        case photoSnapshot = "photo_snapshot"
        case serviceType = "service_type"
        case serviceNotes = "service_notes"
        case preferredStart = "preferred_start"
        case preferredEnd = "preferred_end"
        case locationMode = "location_mode"
        case streetAddress = "street_address"
        case city
        case state
        case zipCode = "zip_code"
        case travelRadiusMiles = "travel_radius_miles"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct DismissRequestMatchRow: Decodable {
    let matchID: UUID
    let status: RequestMatchStatus
    let dismissedAt: String

    var result: DismissRequestMatchResult {
        DismissRequestMatchResult(
            matchID: matchID,
            status: status,
            dismissedAt: dismissedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case status
        case dismissedAt = "dismissed_at"
    }
}

private struct DismissRequestMatchParameters: Encodable {
    let matchID: UUID
    let reason: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchID.uuidString.lowercased(), forKey: .matchID)

        let normalizedReason = reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedReason, !normalizedReason.isEmpty {
            try container.encode(normalizedReason, forKey: .reason)
        } else {
            try container.encodeNil(forKey: .reason)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case matchID = "p_match_id"
        case reason = "p_reason"
    }
}

private struct CreateGroomerOfferRow: Decodable {
    let offerID: UUID
    let offerStatus: GroomerOfferStatus
    let requestStatus: GroomingRequestStatus

    var result: CreateGroomerOfferResult {
        CreateGroomerOfferResult(
            offerID: offerID,
            offerStatus: offerStatus,
            requestStatus: requestStatus
        )
    }

    private enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case offerStatus = "offer_status"
        case requestStatus = "request_status"
    }
}

private struct WithdrawGroomerOfferRow: Decodable {
    let offerID: UUID
    let offerStatus: GroomerOfferStatus
    let withdrawnTimestamp: String
    let requestStatus: GroomingRequestStatus

    var result: WithdrawGroomerOfferResult {
        WithdrawGroomerOfferResult(
            offerID: offerID,
            offerStatus: offerStatus,
            withdrawnTimestamp: withdrawnTimestamp,
            requestStatus: requestStatus
        )
    }

    private enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case offerStatus = "offer_status"
        case withdrawnTimestamp = "withdrawn_timestamp"
        case requestStatus = "request_status"
    }
}

private struct CreateGroomerOfferParameters: Encodable {
    let draft: GroomerOfferDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            draft.requestID.uuidString.lowercased(),
            forKey: .requestID
        )
        try container.encode(
            GroomingRequestDateFormatting.serverString(from: draft.proposedStart),
            forKey: .proposedStart
        )
        try container.encode(
            GroomingRequestDateFormatting.serverString(from: draft.proposedEnd),
            forKey: .proposedEnd
        )
        try container.encode(draft.priceEstimate, forKey: .priceEstimate)

        if let message = draft.message {
            try container.encode(message, forKey: .message)
        } else {
            try container.encodeNil(forKey: .message)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "p_request_id"
        case proposedStart = "p_proposed_start"
        case proposedEnd = "p_proposed_end"
        case priceEstimate = "p_price_estimate"
        case message = "p_message"
    }
}

private struct WithdrawGroomerOfferParameters: Encodable {
    let offerID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(offerID.uuidString.lowercased(), forKey: .offerID)
    }

    private enum CodingKeys: String, CodingKey {
        case offerID = "p_offer_id"
    }
}
