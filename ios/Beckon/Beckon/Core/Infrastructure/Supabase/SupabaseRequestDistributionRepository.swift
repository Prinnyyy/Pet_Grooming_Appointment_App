import Foundation
import Supabase

@MainActor
final class SupabaseRequestDistributionRepository: RequestDistributionRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool,
                 groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        try await write("publish_request_with_distribution_v1", params: PublishDistributionParameters(
            p_operation_id: operationID, p_session_id: session.id, p_input_digest: session.inputDigest,
            p_pool_enabled: poolEnabled, p_groomer_ids: groomerIDs), expectedRequest: nil)
    }

    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID,
                groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        try await write("invite_request_groomers_v1", params: InviteDistributionParameters(
            p_operation_id: operationID, p_request_id: requestID,
            p_expected_terms_revision: expectedTermsRevision, p_groomer_ids: groomerIDs), expectedRequest: requestID)
    }

    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID,
                 enabled: Bool) async throws -> RequestDistributionReceipt {
        try await write("set_request_pool_v1", params: PoolDistributionParameters(
            p_operation_id: operationID, p_request_id: requestID,
            p_expected_distribution_revision: expectedRevision, p_enabled: enabled), expectedRequest: requestID)
    }

    func withdrawInvitation(operationID: UUID, requestID: UUID,
                            groomerID: UUID) async throws -> RequestDistributionReceipt {
        try await write("withdraw_request_invitation_v1", params: WithdrawInvitationParameters(
            p_operation_id: operationID, p_request_id: requestID, p_groomer_id: groomerID), expectedRequest: requestID)
    }

    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress] {
        guard !requestIDs.isEmpty else { return [] }
        do {
            let rows: [CustomerRequestProgressRow] = try await client.rpc("get_customer_request_progress_v1",
                params: ["p_request_ids": requestIDs]).execute().value
            guard Set(rows.map(\.requestID)) == Set(requestIDs), rows.count == Set(requestIDs).count else {
                throw RequestDiscoveryError.unavailable
            }
            return try rows.map { try $0.progress() }
        } catch { throw RequestDiscoveryWireError.map(error) }
    }

    private func write<Parameters: Encodable>(_ rpc: String, params: Parameters,
                                              expectedRequest: UUID?) async throws -> RequestDistributionReceipt {
        do {
            let row: RequestDistributionReceiptRow = try await client.rpc(rpc, params: params).execute().value
            return try row.receipt(expectedRequest: expectedRequest)
        } catch { throw RequestDiscoveryWireError.map(error) }
    }
}

nonisolated private struct PublishDistributionParameters: Encodable {
    let p_operation_id: UUID
    let p_session_id: UUID
    let p_input_digest: String
    let p_pool_enabled: Bool
    let p_groomer_ids: [UUID]
}
nonisolated private struct InviteDistributionParameters: Encodable {
    let p_operation_id: UUID
    let p_request_id: UUID
    let p_expected_terms_revision: UUID
    let p_groomer_ids: [UUID]
}
nonisolated private struct PoolDistributionParameters: Encodable {
    let p_operation_id: UUID
    let p_request_id: UUID
    let p_expected_distribution_revision: UUID
    let p_enabled: Bool
}
nonisolated private struct WithdrawInvitationParameters: Encodable {
    let p_operation_id: UUID
    let p_request_id: UUID
    let p_groomer_id: UUID
}

nonisolated struct RequestDistributionReceiptRow: Decodable, Sendable {
    let requestID: UUID
    let termsRevision: UUID
    let distributionRevision: UUID
    let poolEnabled: Bool
    let invitedGroomerIDs: [UUID]

    func receipt(expectedRequest: UUID?) throws -> RequestDistributionReceipt {
        guard expectedRequest == nil || expectedRequest == requestID else { throw RequestDiscoveryError.notAllowed }
        guard Set(invitedGroomerIDs).count == invitedGroomerIDs.count else { throw RequestDiscoveryError.unavailable }
        return .init(requestID: requestID, termsRevision: termsRevision, distributionRevision: distributionRevision,
                     poolEnabled: poolEnabled, invitedGroomerIDs: invitedGroomerIDs)
    }
    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id", termsRevision = "terms_revision", distributionRevision = "distribution_revision"
        case poolEnabled = "pool_enabled", invitedGroomerIDs = "invited_groomer_ids"
    }
}

nonisolated struct CustomerRequestProgressRow: Decodable, Sendable {
    let requestID: UUID
    let termsRevision: UUID
    let distributionRevision: UUID
    let poolEnabled: Bool
    let status: GroomingRequestStatus
    let expiresAt: String
    let checkedAt: String
    let evaluationPending: Bool
    let validOfferCount: Int
    let invitations: [RequestInvitationRow]
    var poolCandidateCount: Int? = nil

    func progress() throws -> CustomerRequestProgress {
        guard let expiry = GroomingRequestDateFormatting.parsedDate(from: expiresAt),
              let checked = GroomingRequestDateFormatting.parsedDate(from: checkedAt),
              status != .unknown, validOfferCount >= 0, (poolCandidateCount.map { $0 >= 0 } ?? true),
              Set(invitations.map(\.groomerID)).count == invitations.count else { throw RequestDiscoveryError.unavailable }
        return .init(requestID: requestID, termsRevision: termsRevision, distributionRevision: distributionRevision,
                     poolEnabled: poolEnabled, status: status, expiresAt: expiry, checkedAt: checked,
                     evaluationPending: evaluationPending, validOfferCount: validOfferCount,
                     invitations: try invitations.map { try $0.invitation() }, poolCandidateCount: poolCandidateCount)
    }
    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id", termsRevision = "terms_revision", distributionRevision = "distribution_revision"
        case poolEnabled = "pool_enabled", status, expiresAt = "expires_at", checkedAt = "checked_at"
        case evaluationPending = "evaluation_pending", validOfferCount = "valid_offer_count", invitations
        case poolCandidateCount = "pool_candidate_count"
    }
}

nonisolated struct RequestInvitationRow: Decodable, Sendable {
    let groomerID: UUID
    let safeProfile: MarketplaceGroomerSummaryRow?
    let sentAt: String
    let replyBy: String
    let state: RequestInvitationState

    func invitation() throws -> RequestInvitation {
        guard safeProfile == nil || safeProfile?.id == groomerID,
              let sent = GroomingRequestDateFormatting.parsedDate(from: sentAt),
              let reply = GroomingRequestDateFormatting.parsedDate(from: replyBy),
              reply > sent, reply.timeIntervalSince(sent) <= 24 * 60 * 60,
              state != .notSent else { throw RequestDiscoveryError.unavailable }
        return .init(groomerID: groomerID, profile: try safeProfile?.summary(), sentAt: sent, replyBy: reply, state: state)
    }
    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id", safeProfile = "safe_profile", sentAt = "sent_at", replyBy = "reply_by", state
    }
}
