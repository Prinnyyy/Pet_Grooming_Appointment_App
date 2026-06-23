import Foundation
import Supabase

@MainActor
final class SupabaseGroomerProfileRepository: GroomerProfileRepository {
    private static let profileColumns =
        "user_id,business_name,bio,years_experience,base_city,base_state,service_radius_miles,service_location_mode,rating_avg,rating_count,is_active,is_verified"
    private static let serviceColumns =
        "id,groomer_id,service_type,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active"
    private static let portfolioColumns =
        "id,groomer_id,storage_bucket,storage_path,caption,sort_order"
    fileprivate static let bucketID = "groomer-portfolio"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        do {
            let rows: [GroomerProfileRow] = try await client
                .from("groomer_profiles")
                .select(Self.profileColumns)
                .eq("user_id", value: groomerID.uuidString.lowercased())
                .execute()
                .value

            guard rows.count == 1, let profile = rows.first?.profile else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return profile
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        do {
            let rows: [GroomerServiceRow] = try await client
                .from("groomer_services")
                .select(Self.serviceColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value

            return rows.map(\.service)
        } catch {
            throw Self.map(error)
        }
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        do {
            let rows: [GroomerPortfolioPhotoRow] = try await client
                .from("groomer_portfolio_photos")
                .select(Self.portfolioColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("sort_order")
                .order("created_at")
                .execute()
                .value

            return rows.map(\.photo)
        } catch {
            throw Self.map(error)
        }
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        do {
            let rows: [GroomerProfileRow] = try await client
                .from("groomer_profiles")
                .update(GroomerProfileUpdateRow(draft: draft))
                .eq("user_id", value: groomerID.uuidString.lowercased())
                .select(Self.profileColumns)
                .execute()
                .value

            guard rows.count == 1, let profile = rows.first?.profile else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return profile
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        do {
            let rows: [GroomerServiceRow] = try await client
                .from("groomer_services")
                .insert(GroomerServiceInsertRow(groomerID: groomerID, draft: draft))
                .select(Self.serviceColumns)
                .execute()
                .value

            guard rows.count == 1, let service = rows.first?.service else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return service
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        do {
            let rows: [GroomerServiceRow] = try await client
                .from("groomer_services")
                .update(GroomerServiceUpdateRow(draft: draft))
                .eq("id", value: service.id.uuidString.lowercased())
                .eq("groomer_id", value: service.groomerID.uuidString.lowercased())
                .select(Self.serviceColumns)
                .execute()
                .value

            guard rows.count == 1, let service = rows.first?.service else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return service
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func deleteService(_ service: GroomerService) async throws {
        do {
            try await client
                .from("groomer_services")
                .delete()
                .eq("id", value: service.id.uuidString.lowercased())
                .eq("groomer_id", value: service.groomerID.uuidString.lowercased())
                .execute()
        } catch {
            throw Self.map(error)
        }
    }

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        let storagePath = GroomerPortfolioPhotoPath.make(
            groomerID: groomerID,
            contentType: contentType
        )

        do {
            try await client.storage
                .from(Self.bucketID)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(
                        contentType: contentType.mimeType,
                        upsert: false
                    )
                )

            let rows: [GroomerPortfolioPhotoRow] = try await client
                .from("groomer_portfolio_photos")
                .insert(
                    GroomerPortfolioPhotoInsertRow(
                        groomerID: groomerID,
                        storagePath: storagePath,
                        caption: Self.normalized(caption)
                    )
                )
                .select(Self.portfolioColumns)
                .execute()
                .value

            guard rows.count == 1, let photo = rows.first?.photo else {
                _ = try? await client.storage
                    .from(Self.bucketID)
                    .remove(paths: [storagePath])
                throw GroomerProfileRepositoryError.unavailable
            }

            return photo
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            _ = try? await client.storage
                .from(Self.bucketID)
                .remove(paths: [storagePath])
            throw Self.map(error)
        }
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        do {
            try await client.storage
                .from(Self.bucketID)
                .remove(paths: [photo.storagePath])

            try await client
                .from("groomer_portfolio_photos")
                .delete()
                .eq("id", value: photo.id.uuidString.lowercased())
                .eq("groomer_id", value: photo.groomerID.uuidString.lowercased())
                .execute()
        } catch {
            throw Self.map(error)
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func map(_ error: any Error) -> GroomerProfileRepositoryError {
        if let repositoryError = error as? GroomerProfileRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501":
                return .notAllowed
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

private struct GroomerProfileRow: Decodable {
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

private struct GroomerServiceRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let serviceType: GroomingServiceType
    let title: String
    let description: String?
    let basePrice: Double
    let durationMinutes: Int
    let acceptedPetSizes: [String]
    let isActive: Bool

    var service: GroomerService {
        GroomerService(
            id: id,
            groomerID: groomerID,
            serviceType: serviceType,
            title: title,
            description: description,
            basePrice: basePrice,
            durationMinutes: durationMinutes,
            acceptedPetSizes: acceptedPetSizes.compactMap(GroomerServicePetSize.init(rawValue:)),
            isActive: isActive
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case serviceType = "service_type"
        case title
        case description
        case basePrice = "base_price"
        case durationMinutes = "duration_minutes"
        case acceptedPetSizes = "accepted_pet_sizes"
        case isActive = "is_active"
    }
}

private struct GroomerPortfolioPhotoRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int

    var photo: GroomerPortfolioPhoto {
        GroomerPortfolioPhoto(
            id: id,
            groomerID: groomerID,
            storageBucket: storageBucket,
            storagePath: storagePath,
            caption: caption,
            sortOrder: sortOrder
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
        case sortOrder = "sort_order"
    }
}

private struct GroomerProfileUpdateRow: Encodable {
    let draft: GroomerProfileDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeNullable(draft.businessName, forKey: .businessName, in: &container)
        try encodeNullable(draft.bio, forKey: .bio, in: &container)
        try encodeNullable(
            draft.yearsExperience,
            forKey: .yearsExperience,
            in: &container
        )
        try encodeNullable(draft.baseCity, forKey: .baseCity, in: &container)
        try encodeNullable(draft.baseStateCode?.rawValue, forKey: .baseState, in: &container)
        try encodeNullable(
            draft.serviceRadiusMiles,
            forKey: .serviceRadiusMiles,
            in: &container
        )
        try encodeNullable(
            draft.serviceLocationMode?.rawValue,
            forKey: .serviceLocationMode,
            in: &container
        )
        try container.encode(draft.isActive, forKey: .isActive)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case businessName = "business_name"
        case bio
        case yearsExperience = "years_experience"
        case baseCity = "base_city"
        case baseState = "base_state"
        case serviceRadiusMiles = "service_radius_miles"
        case serviceLocationMode = "service_location_mode"
        case isActive = "is_active"
    }
}

private struct GroomerServiceInsertRow: Encodable {
    let groomerID: UUID
    let draft: GroomerServiceDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.serviceType.rawValue, forKey: .serviceType)
        try container.encode(draft.title, forKey: .title)
        try container.encodeIfPresent(draft.description, forKey: .description)
        try container.encode(draft.basePrice, forKey: .basePrice)
        try container.encode(draft.durationMinutes, forKey: .durationMinutes)
        try container.encode(draft.acceptedPetSizes.map(\.rawValue), forKey: .acceptedPetSizes)
        try container.encode(draft.isActive, forKey: .isActive)
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case serviceType = "service_type"
        case title
        case description
        case basePrice = "base_price"
        case durationMinutes = "duration_minutes"
        case acceptedPetSizes = "accepted_pet_sizes"
        case isActive = "is_active"
    }
}

private struct GroomerServiceUpdateRow: Encodable {
    let draft: GroomerServiceDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draft.serviceType.rawValue, forKey: .serviceType)
        try container.encode(draft.title, forKey: .title)
        try encodeNullable(draft.description, forKey: .description, in: &container)
        try container.encode(draft.basePrice, forKey: .basePrice)
        try container.encode(draft.durationMinutes, forKey: .durationMinutes)
        try container.encode(draft.acceptedPetSizes.map(\.rawValue), forKey: .acceptedPetSizes)
        try container.encode(draft.isActive, forKey: .isActive)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case serviceType = "service_type"
        case title
        case description
        case basePrice = "base_price"
        case durationMinutes = "duration_minutes"
        case acceptedPetSizes = "accepted_pet_sizes"
        case isActive = "is_active"
    }
}

private struct GroomerPortfolioPhotoInsertRow: Encodable {
    let groomerID: UUID
    let storagePath: String
    let caption: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(SupabaseGroomerProfileRepository.bucketID, forKey: .storageBucket)
        try container.encode(storagePath, forKey: .storagePath)
        try container.encodeIfPresent(caption, forKey: .caption)
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
    }
}
