import Foundation
import Supabase

@MainActor
final class SupabaseCustomerRequestRepository: CustomerRequestRepository {
    private static let requestColumns = """
        id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,service_notes,\
        preferred_start,preferred_end,city,state,zip_code,status,expires_at,created_at,updated_at
        """

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        do {
            let rows: [GroomingRequestRow] = try await client
                .from("grooming_requests")
                .select(Self.requestColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value

            return rows.map(\.request)
        } catch {
            throw Self.map(error)
        }
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        do {
            let rows: [CreateGroomingRequestRow] = try await client
                .rpc(
                    "create_grooming_request",
                    params: CreateGroomingRequestParameters(draft: draft)
                )
                .execute()
                .value

            guard rows.count == 1, let result = rows.first?.result else {
                throw CustomerRequestRepositoryError.unavailable
            }

            return result
        } catch let error as CustomerRequestRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: any Error) -> CustomerRequestRepositoryError {
        if let repositoryError = error as? CustomerRequestRepositoryError {
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
                case "open_request_limit_exceeded":
                    return .requestLimitExceeded
                case "pet_not_found":
                    return .petNotFound
                case "customer_profile_required":
                    return .notAllowed
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

private struct GroomingRequestRow: Decodable {
    let id: UUID
    let customerID: UUID
    let petID: UUID?
    let petSnapshot: GroomingRequestPetSnapshot
    let photoSnapshot: [GroomingRequestPhotoSnapshot]
    let serviceType: String
    let serviceNotes: String?
    let preferredStart: String
    let preferredEnd: String
    let city: String
    let state: String
    let zipCode: String
    let status: GroomingRequestStatus
    let expiresAt: String
    let createdAt: String
    let updatedAt: String

    var request: CustomerGroomingRequest {
        CustomerGroomingRequest(
            id: id,
            customerID: customerID,
            petID: petID,
            petSnapshot: petSnapshot,
            photoSnapshot: photoSnapshot,
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            city: city,
            state: state,
            zipCode: zipCode,
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
        case city
        case state
        case zipCode = "zip_code"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct CreateGroomingRequestRow: Decodable {
    let requestID: UUID
    let matchCount: Int

    var result: GroomingRequestPublishResult {
        GroomingRequestPublishResult(
            requestID: requestID,
            matchCount: matchCount
        )
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case matchCount = "match_count"
    }
}

private struct CreateGroomingRequestParameters: Encodable {
    let draft: GroomingRequestDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draft.petID.uuidString.lowercased(), forKey: .petID)
        try container.encode(draft.serviceType, forKey: .serviceType)
        if let serviceNotes = draft.serviceNotes {
            try container.encode(serviceNotes, forKey: .serviceNotes)
        } else {
            try container.encodeNil(forKey: .serviceNotes)
        }
        try container.encode(
            GroomingRequestDateFormatting.serverString(from: draft.preferredStart),
            forKey: .preferredStart
        )
        try container.encode(
            GroomingRequestDateFormatting.serverString(from: draft.preferredEnd),
            forKey: .preferredEnd
        )
        try container.encode(draft.city, forKey: .city)
        try container.encode(draft.state, forKey: .state)
        try container.encode(draft.zipCode, forKey: .zipCode)
    }

    private enum CodingKeys: String, CodingKey {
        case petID = "p_pet_id"
        case serviceType = "p_service_type"
        case serviceNotes = "p_service_notes"
        case preferredStart = "p_preferred_start"
        case preferredEnd = "p_preferred_end"
        case city = "p_city"
        case state = "p_state"
        case zipCode = "p_zip_code"
    }
}
