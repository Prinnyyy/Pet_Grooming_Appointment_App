import Foundation
import Supabase

@MainActor
final class SupabaseCustomerRequestRepository: CustomerRequestRepository {
    private static let requestColumns = """
        id,customer_id,pet_id,pet_snapshot,photo_snapshot,service_type,service_notes,\
        preferred_start,preferred_end,location_mode,street_address,city,state,zip_code,\
        travel_radius_miles,status,expires_at,created_at,updated_at
        """
    private static let offerColumns = """
        id,request_id,match_id,customer_id,groomer_id,proposed_start,proposed_end,\
        price_estimate,message,status,expires_at,withdrawn_at,created_at,updated_at
        """
    private static let offerMatchEvidenceColumns =
        "id,match_score,match_reason"
    private static let groomerProfileColumns =
        "user_id,business_name,bio,years_experience,base_city,base_state,service_radius_miles,service_location_mode,rating_avg,rating_count,is_active,is_verified"
    private static let requestPhotoColumns =
        "id,request_id,customer_id,storage_bucket,storage_path,caption,sort_order,created_at"
    fileprivate static let requestPhotoBucketID = "request-photos"

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

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        do {
            let offerRows: [CustomerOfferRow] = try await client
                .from("groomer_offers")
                .select(Self.offerColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .eq("request_id", value: requestID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value

            guard !offerRows.isEmpty else { return [] }

            let groomerIDs = Set(offerRows.map(\.groomerID))
                .map { $0.uuidString.lowercased() }
            let matchIDs = Set(offerRows.map(\.matchID))
                .map { $0.uuidString.lowercased() }

            let profileRows: [CustomerOfferGroomerProfileRow] = try await client
                .from("groomer_profiles")
                .select(Self.groomerProfileColumns)
                .in("user_id", values: groomerIDs)
                .execute()
                .value

            let matchRows: [CustomerOfferMatchEvidenceRow] = try await client
                .from("request_matches")
                .select(Self.offerMatchEvidenceColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .eq("request_id", value: requestID.uuidString.lowercased())
                .in("id", values: matchIDs)
                .execute()
                .value

            let profilesByID = Dictionary(
                uniqueKeysWithValues: profileRows.map { ($0.userID, $0.profile) }
            )
            let matchEvidenceByID = Dictionary(
                uniqueKeysWithValues: matchRows.map { ($0.id, $0) }
            )

            return offerRows.map { row in
                let matchEvidence = matchEvidenceByID[row.matchID]
                return CustomerOfferReview(
                    offer: row.offer,
                    groomerProfile: profilesByID[row.groomerID],
                    matchScore: matchEvidence?.matchScore,
                    matchReason: matchEvidence?.matchReason
                )
            }
        } catch {
            throw Self.map(error)
        }
    }

    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        let ids = Self.uniqueLowercaseStrings(from: requestIDs)
        guard !ids.isEmpty else { return [] }

        do {
            let rows: [GroomingRequestPhotoRow] = try await client
                .from("request_photos")
                .select(Self.requestPhotoColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
                .in("request_id", values: ids)
                .order("sort_order")
                .order("created_at")
                .execute()
                .value

            return rows.map(\.photo)
        } catch {
            throw Self.map(error)
        }
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        do {
            return try await client.storage
                .from(Self.requestPhotoBucketID)
                .download(path: photo.storagePath)
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

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        let storagePath = GroomingRequestPhotoPath.make(
            customerID: customerID,
            requestID: requestID,
            contentType: contentType
        )

        do {
            try await client.storage
                .from(Self.requestPhotoBucketID)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(
                        contentType: contentType.mimeType,
                        upsert: false
                    )
                )

            let rows: [GroomingRequestPhotoRow] = try await client
                .from("request_photos")
                .insert(
                    GroomingRequestPhotoInsertRow(
                        requestID: requestID,
                        customerID: customerID,
                        storagePath: storagePath,
                        caption: Self.normalized(caption)
                    )
                )
                .select(Self.requestPhotoColumns)
                .execute()
                .value

            guard rows.count == 1, let photo = rows.first?.photo else {
                _ = try? await client.storage
                    .from(Self.requestPhotoBucketID)
                    .remove(paths: [storagePath])
                throw CustomerRequestRepositoryError.unavailable
            }

            return photo
        } catch let error as CustomerRequestRepositoryError {
            throw error
        } catch {
            _ = try? await client.storage
                .from(Self.requestPhotoBucketID)
                .remove(paths: [storagePath])
            throw Self.map(error)
        }
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        do {
            let rows: [CancelGroomingRequestRow] = try await client
                .rpc(
                    "cancel_grooming_request",
                    params: CancelGroomingRequestParameters(requestID: requestID)
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
                case "request_not_found":
                    return .requestNotFound
                case "request_not_cancellable":
                    return .requestNotCancellable
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

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func uniqueLowercaseStrings(from ids: [UUID]) -> [String] {
        Array(Set(ids)).map { $0.uuidString.lowercased() }
    }
}

private struct GroomingRequestRow: Decodable {
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

private struct CancelGroomingRequestRow: Decodable {
    let requestID: UUID
    let requestStatus: GroomingRequestStatus
    let cancelledTimestamp: String

    var result: CancelGroomingRequestResult {
        CancelGroomingRequestResult(
            requestID: requestID,
            requestStatus: requestStatus,
            cancelledTimestamp: cancelledTimestamp
        )
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case requestStatus = "request_status"
        case cancelledTimestamp = "cancelled_timestamp"
    }
}

private struct CustomerOfferRow: Decodable {
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

private struct CustomerOfferGroomerProfileRow: Decodable {
    let userID: UUID
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    let baseCity: String?
    let baseState: String?
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    let ratingAverage: Double
    let ratingCount: Int
    let isActive: Bool
    let isVerified: Bool

    var profile: GroomerProfile {
        GroomerProfile(
            userID: userID,
            businessName: businessName,
            bio: bio,
            yearsExperience: yearsExperience,
            baseCity: baseCity,
            baseState: baseState,
            serviceRadiusMiles: serviceRadiusMiles,
            serviceLocationMode: serviceLocationMode,
            ratingAverage: ratingAverage,
            ratingCount: ratingCount,
            isActive: isActive,
            isVerified: isVerified
        )
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case businessName = "business_name"
        case bio
        case yearsExperience = "years_experience"
        case baseCity = "base_city"
        case baseState = "base_state"
        case serviceRadiusMiles = "service_radius_miles"
        case serviceLocationMode = "service_location_mode"
        case ratingAverage = "rating_avg"
        case ratingCount = "rating_count"
        case isActive = "is_active"
        case isVerified = "is_verified"
    }
}

private struct CustomerOfferMatchEvidenceRow: Decodable {
    let id: UUID
    let matchScore: Double?
    let matchReason: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case matchScore = "match_score"
        case matchReason = "match_reason"
    }
}

private struct CreateGroomingRequestParameters: Encodable {
    let draft: GroomingRequestDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draft.petID.uuidString.lowercased(), forKey: .petID)
        try container.encode(draft.serviceType.rawValue, forKey: .serviceType)
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
        try container.encode(draft.locationMode.rawValue, forKey: .locationMode)
        try container.encode(draft.streetAddress, forKey: .streetAddress)
        try container.encode(draft.city, forKey: .city)
        try container.encode(draft.stateCode.rawValue, forKey: .state)
        try container.encode(draft.zipCode, forKey: .zipCode)
        if let travelRadiusMiles = draft.travelRadiusMiles {
            try container.encode(travelRadiusMiles, forKey: .travelRadiusMiles)
        } else {
            try container.encodeNil(forKey: .travelRadiusMiles)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case petID = "p_pet_id"
        case serviceType = "p_service_type"
        case serviceNotes = "p_service_notes"
        case preferredStart = "p_preferred_start"
        case preferredEnd = "p_preferred_end"
        case locationMode = "p_location_mode"
        case streetAddress = "p_street_address"
        case city = "p_city"
        case state = "p_state"
        case zipCode = "p_zip_code"
        case travelRadiusMiles = "p_travel_radius_miles"
    }
}

private struct GroomingRequestPhotoRow: Decodable {
    let id: UUID
    let requestID: UUID
    let customerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let createdAt: String?

    var photo: GroomingRequestPhoto {
        GroomingRequestPhoto(
            id: id,
            requestID: requestID,
            customerID: customerID,
            storageBucket: storageBucket,
            storagePath: storagePath,
            caption: caption,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case customerID = "customer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

private struct GroomingRequestPhotoInsertRow: Encodable {
    let requestID: UUID
    let customerID: UUID
    let storagePath: String
    let caption: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestID.uuidString.lowercased(), forKey: .requestID)
        try container.encode(customerID.uuidString.lowercased(), forKey: .customerID)
        try container.encode(SupabaseCustomerRequestRepository.requestPhotoBucketID, forKey: .storageBucket)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encodeIfPresent(caption, forKey: .caption)
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case customerID = "customer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
    }
}

private struct CancelGroomingRequestParameters: Encodable {
    let requestID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestID.uuidString.lowercased(), forKey: .requestID)
    }

    private enum CodingKeys: String, CodingKey {
        case requestID = "p_request_id"
    }
}
