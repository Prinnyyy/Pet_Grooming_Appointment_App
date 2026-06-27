import Foundation
import Supabase

@MainActor
final class SupabaseGroomerProfileRepository: GroomerProfileRepository {
    private static let profileColumns =
        "user_id,business_name,bio,years_experience,base_street_address,base_city,base_state,base_zip_code,service_radius_miles,service_location_mode,service_location_modes,rating_avg,rating_count,is_active,is_verified"
    private static let accountProfileColumns = "id,avatar_path"
    private static let serviceColumns =
        "id,groomer_id,service_type,title,description,base_price,duration_minutes,accepted_pet_sizes,is_active"
    private static let portfolioColumns =
        "id,groomer_id,storage_bucket,storage_path,caption,sort_order"
    private static let portfolioFitTagColumns =
        "id,portfolio_photo_id,groomer_id,trait_type,trait_value"
    private static let availabilityColumns =
        "id,groomer_id,weekday,start_time,end_time,is_enabled,timezone"
    private static let bookingPreferencesColumns =
        "groomer_id,max_appointments_per_day,minimum_advance_notice_days,auto_accept_bookings"
    private static let timeOffColumns =
        "id,groomer_id,title,start_date,end_date"
    private static let fitClaimColumns =
        "id,groomer_id,trait_type,trait_value,is_active"
    private static let petFitEvidenceSummaryRPC =
        "get_my_groomer_pet_fit_evidence_summary"
    fileprivate static let bucketID = "groomer-portfolio"
    fileprivate static let avatarBucketID = "avatars"

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

            guard rows.count == 1, var profile = rows.first?.profile else {
                throw GroomerProfileRepositoryError.unavailable
            }

            profile.avatarPath = try await avatarPath(groomerID: groomerID)

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

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        do {
            return try await portfolioFitTags(
                groomerID: groomerID,
                photoID: nil
            )
        } catch {
            throw Self.map(error)
        }
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        do {
            let rows: [GroomerAvailabilityWindowRow] = try await client
                .from("groomer_availability_windows")
                .select(Self.availabilityColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("weekday")
                .execute()
                .value

            return rows.compactMap(\.window)
        } catch {
            throw Self.map(error)
        }
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        do {
            let rows: [GroomerBookingPreferencesRow] = try await client
                .from("groomer_booking_preferences")
                .select(Self.bookingPreferencesColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .limit(1)
                .execute()
                .value

            guard rows.count <= 1 else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return rows.first?.preferences
                ?? GroomerBookingPreferences.default(groomerID: groomerID)
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        do {
            let rows: [GroomerTimeOffWindowRow] = try await client
                .from("groomer_time_off_windows")
                .select(Self.timeOffColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("start_date")
                .order("end_date")
                .execute()
                .value

            return rows.map(\.window)
        } catch {
            throw Self.map(error)
        }
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        do {
            let rows: [GroomerFitClaimRow] = try await client
                .from("groomer_fit_claims")
                .select(Self.fitClaimColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("trait_type")
                .order("trait_value")
                .execute()
                .value

            return rows.compactMap(\.claim)
        } catch {
            throw Self.map(error)
        }
    }

    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] {
        do {
            let rows: [GroomerPetFitEvidenceSummaryRow] = try await client
                .rpc(Self.petFitEvidenceSummaryRPC)
                .execute()
                .value

            return rows
                .compactMap(\.summary)
                .filter { $0.groomerID == groomerID }
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

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        do {
            return try await client.storage
                .from(Self.bucketID)
                .download(path: photo.storagePath)
        } catch {
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

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        let storagePath = GroomerAvatarPhotoPath.make(
            groomerID: groomerID,
            contentType: contentType
        )

        do {
            let oldAvatarPath = try? await avatarPath(groomerID: groomerID)

            try await client.storage
                .from(Self.avatarBucketID)
                .upload(
                    storagePath,
                    data: data,
                    options: FileOptions(
                        contentType: contentType.mimeType,
                        upsert: false
                    )
                )

            let rows: [GroomerAccountProfileRow] = try await client
                .from("profiles")
                .update(GroomerAvatarUpdateRow(avatarPath: storagePath))
                .eq("id", value: groomerID.uuidString.lowercased())
                .select(Self.accountProfileColumns)
                .execute()
                .value

            guard rows.count == 1, rows.first?.avatarPath == storagePath else {
                _ = try? await client.storage
                    .from(Self.avatarBucketID)
                    .remove(paths: [storagePath])
                throw GroomerProfileRepositoryError.unavailable
            }

            if let oldAvatarPath,
               oldAvatarPath != storagePath {
                _ = try? await client.storage
                    .from(Self.avatarBucketID)
                    .remove(paths: [oldAvatarPath])
            }

            return storagePath
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            _ = try? await client.storage
                .from(Self.avatarBucketID)
                .remove(paths: [storagePath])
            throw Self.map(error)
        }
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        do {
            return try await client.storage
                .from(Self.avatarBucketID)
                .download(path: storagePath)
        } catch {
            throw Self.map(error)
        }
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        do {
            try await client
                .from("groomer_availability_windows")
                .delete()
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .execute()

            let rows: [GroomerAvailabilityWindowRow] = try await client
                .from("groomer_availability_windows")
                .insert(
                    drafts.map {
                        GroomerAvailabilityWindowInsertRow(
                            groomerID: groomerID,
                            draft: $0
                        )
                    }
                )
                .select(Self.availabilityColumns)
                .order("weekday")
                .execute()
                .value

            return rows.compactMap(\.window)
        } catch {
            throw Self.map(error)
        }
    }

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences {
        do {
            let rows: [GroomerBookingPreferencesRow] = try await client
                .from("groomer_booking_preferences")
                .upsert(
                    GroomerBookingPreferencesUpsertRow(
                        groomerID: groomerID,
                        draft: draft
                    ),
                    onConflict: "groomer_id"
                )
                .select(Self.bookingPreferencesColumns)
                .execute()
                .value

            guard rows.count == 1, let preferences = rows.first?.preferences else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return preferences
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim] {
        do {
            if !drafts.isEmpty {
                try await client
                    .from("groomer_fit_claims")
                    .upsert(
                        drafts.map {
                            GroomerFitClaimUpsertRow(
                                groomerID: groomerID,
                                draft: $0
                            )
                        },
                        onConflict: "groomer_id,trait_type,trait_value"
                    )
                    .execute()
            }

            return try await fitClaims(groomerID: groomerID)
        } catch {
            throw Self.map(error)
        }
    }

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag] {
        do {
            let selectedIDs = Set(drafts.map { $0.signal.id })
            let canonicalDrafts = GroomerPortfolioFitTag.availableSignals
                .filter { selectedIDs.contains($0.id) }
                .sorted { lhs, rhs in
                    if lhs.sortOrder == rhs.sortOrder {
                        return lhs.id < rhs.id
                    }
                    return lhs.sortOrder < rhs.sortOrder
                }
                .map { GroomerPortfolioFitTagDraft(signal: $0) }
            let currentTags = try await portfolioFitTags(
                groomerID: groomerID,
                photoID: photoID
            )
            let selectedSignals = Set(canonicalDrafts.map(\.signal))
            let currentSignals = Set(currentTags.map(\.signal))
            let tagsToAdd = canonicalDrafts.filter {
                !currentSignals.contains($0.signal)
            }
            let tagsToDelete = currentTags.filter {
                !selectedSignals.contains($0.signal)
            }

            if !tagsToAdd.isEmpty {
                try await client
                    .from("groomer_portfolio_fit_tags")
                    .insert(
                        tagsToAdd.map {
                            GroomerPortfolioFitTagInsertRow(
                                groomerID: groomerID,
                                photoID: photoID,
                                draft: $0
                            )
                        }
                    )
                    .execute()
            }

            for tag in tagsToDelete {
                try await client
                    .from("groomer_portfolio_fit_tags")
                    .delete()
                    .eq("id", value: tag.id.uuidString.lowercased())
                    .eq("portfolio_photo_id", value: photoID.uuidString.lowercased())
                    .eq("groomer_id", value: groomerID.uuidString.lowercased())
                    .execute()
            }

            return try await portfolioFitTags(
                groomerID: groomerID,
                photoID: photoID
            )
        } catch {
            throw Self.map(error)
        }
    }

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow {
        do {
            let rows: [GroomerTimeOffWindowRow] = try await client
                .from("groomer_time_off_windows")
                .insert(GroomerTimeOffWindowInsertRow(groomerID: groomerID, draft: draft))
                .select(Self.timeOffColumns)
                .execute()
                .value

            guard rows.count == 1 else {
                throw GroomerProfileRepositoryError.unavailable
            }

            return rows[0].window
        } catch let error as GroomerProfileRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws {
        do {
            try await client
                .from("groomer_time_off_windows")
                .delete()
                .eq("id", value: window.id.uuidString.lowercased())
                .eq("groomer_id", value: window.groomerID.uuidString.lowercased())
                .execute()
        } catch {
            throw Self.map(error)
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func avatarPath(groomerID: UUID) async throws -> String? {
        let rows: [GroomerAccountProfileRow] = try await client
            .from("profiles")
            .select(Self.accountProfileColumns)
            .eq("id", value: groomerID.uuidString.lowercased())
            .limit(1)
            .execute()
            .value

        guard rows.count <= 1 else {
            throw GroomerProfileRepositoryError.unavailable
        }

        return rows.first?.avatarPath
    }

    private func portfolioFitTags(
        groomerID: UUID,
        photoID: UUID?
    ) async throws -> [GroomerPortfolioFitTag] {
        var query = client
            .from("groomer_portfolio_fit_tags")
            .select(Self.portfolioFitTagColumns)
            .eq("groomer_id", value: groomerID.uuidString.lowercased())

        if let photoID {
            query = query.eq("portfolio_photo_id", value: photoID.uuidString.lowercased())
        }

        let rows: [GroomerPortfolioFitTagRow] = try await query
            .order("portfolio_photo_id")
            .order("trait_type")
            .order("trait_value")
            .execute()
            .value

        return rows.compactMap(\.tag)
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
    let baseStreetAddress: String?
    let baseCity: String?
    let baseState: String?
    let baseZipCode: String?
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    let serviceLocationModes: [String]?
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
            baseStreetAddress: baseStreetAddress,
            baseCity: baseCity,
            baseState: baseState,
            baseZipCode: baseZipCode,
            serviceRadiusMiles: serviceRadiusMiles,
            serviceLocationMode: serviceLocationMode,
            serviceLocationModes: Set(
                (serviceLocationModes ?? [])
                    .compactMap(GroomingLocationMode.init(rawValue:))
            ),
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
        case baseStreetAddress = "base_street_address"
        case baseCity = "base_city"
        case baseState = "base_state"
        case baseZipCode = "base_zip_code"
        case serviceRadiusMiles = "service_radius_miles"
        case serviceLocationMode = "service_location_mode"
        case serviceLocationModes = "service_location_modes"
        case ratingAverage = "rating_avg"
        case ratingCount = "rating_count"
        case isActive = "is_active"
        case isVerified = "is_verified"
    }
}

private struct GroomerAccountProfileRow: Decodable {
    let id: UUID
    let avatarPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case avatarPath = "avatar_path"
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

private struct GroomerPortfolioFitTagRow: Decodable {
    let id: UUID
    let portfolioPhotoID: UUID
    let groomerID: UUID
    let traitType: String
    let traitValue: String

    var tag: GroomerPortfolioFitTag? {
        guard let signal = PetFitSignal.allCases.first(where: {
            $0.traitType == traitType && $0.traitValue == traitValue
        }) else {
            return nil
        }

        return GroomerPortfolioFitTag(
            id: id,
            portfolioPhotoID: portfolioPhotoID,
            groomerID: groomerID,
            signal: signal
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case portfolioPhotoID = "portfolio_photo_id"
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
    }
}

private struct GroomerAvailabilityWindowRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let weekday: Int
    let startTime: String
    let endTime: String
    let isEnabled: Bool
    let timezone: String

    var window: GroomerAvailabilityWindow? {
        guard let weekday = GroomerAvailabilityWeekday(rawValue: weekday),
              let startMinutes = Self.minutes(fromTime: startTime),
              let endMinutes = Self.minutes(fromTime: endTime) else {
            return nil
        }

        return GroomerAvailabilityWindow(
            id: id,
            groomerID: groomerID,
            weekday: weekday,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            isEnabled: isEnabled,
            timezone: timezone
        )
    }

    private static func minutes(fromTime value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case weekday
        case startTime = "start_time"
        case endTime = "end_time"
        case isEnabled = "is_enabled"
        case timezone
    }
}

private struct GroomerBookingPreferencesRow: Decodable {
    let groomerID: UUID
    let maxAppointmentsPerDay: Int
    let minimumAdvanceNoticeDays: Int
    let autoAcceptBookings: Bool

    var preferences: GroomerBookingPreferences {
        GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: minimumAdvanceNoticeDays,
            autoAcceptBookings: autoAcceptBookings
        )
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case maxAppointmentsPerDay = "max_appointments_per_day"
        case minimumAdvanceNoticeDays = "minimum_advance_notice_days"
        case autoAcceptBookings = "auto_accept_bookings"
    }
}

private struct GroomerTimeOffWindowRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let title: String
    let startDate: String
    let endDate: String

    var window: GroomerTimeOffWindow {
        GroomerTimeOffWindow(
            id: id,
            groomerID: groomerID,
            title: title,
            startDate: startDate,
            endDate: endDate
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct GroomerFitClaimRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let traitType: String
    let traitValue: String
    let isActive: Bool

    var claim: GroomerFitClaim? {
        guard let signal = PetFitSignal.allCases.first(where: {
            $0.traitType == traitType && $0.traitValue == traitValue
        }) else {
            return nil
        }

        return GroomerFitClaim(
            id: id,
            groomerID: groomerID,
            signal: signal,
            isActive: isActive
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
        case isActive = "is_active"
    }
}

private struct GroomerPetFitEvidenceSummaryRow: Decodable {
    let groomerID: UUID
    let traitType: String
    let traitValue: String
    let completedBookingCount: Int
    let positiveReviewOutcomeCount: Int
    let negativeReviewOutcomeCount: Int
    let structuredReviewOutcomeCount: Int
    let lastCompletedAt: String?
    let lastReviewOutcomeAt: String?
    let evidenceUpdatedAt: String?
    let confidenceTier: String

    var summary: GroomerPetFitEvidenceSummary? {
        guard let signal = PetFitSignal.allCases.first(where: {
            $0.traitType == traitType && $0.traitValue == traitValue
        }) else {
            return nil
        }

        return GroomerPetFitEvidenceSummary(
            groomerID: groomerID,
            signal: signal,
            completedBookingCount: completedBookingCount,
            positiveReviewOutcomeCount: positiveReviewOutcomeCount,
            negativeReviewOutcomeCount: negativeReviewOutcomeCount,
            structuredReviewOutcomeCount: structuredReviewOutcomeCount,
            lastCompletedAt: lastCompletedAt,
            lastReviewOutcomeAt: lastReviewOutcomeAt,
            evidenceUpdatedAt: evidenceUpdatedAt,
            confidenceTier: GroomerPetFitEvidenceConfidenceTier(rawValue: confidenceTier) ?? .low
        )
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
        case completedBookingCount = "completed_booking_count"
        case positiveReviewOutcomeCount = "positive_review_outcome_count"
        case negativeReviewOutcomeCount = "negative_review_outcome_count"
        case structuredReviewOutcomeCount = "structured_review_outcome_count"
        case lastCompletedAt = "last_completed_at"
        case lastReviewOutcomeAt = "last_review_outcome_at"
        case evidenceUpdatedAt = "evidence_updated_at"
        case confidenceTier = "confidence_tier"
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
        try encodeNullable(
            draft.baseStreetAddress,
            forKey: .baseStreetAddress,
            in: &container
        )
        try encodeNullable(draft.baseCity, forKey: .baseCity, in: &container)
        try encodeNullable(draft.baseStateCode?.rawValue, forKey: .baseState, in: &container)
        try encodeNullable(draft.baseZipCode, forKey: .baseZipCode, in: &container)
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
        let locationModeValues = draft.serviceLocationModes.canonicalModes.map(\.rawValue)
        if locationModeValues.isEmpty {
            try container.encodeNil(forKey: .serviceLocationModes)
        } else {
            try container.encode(locationModeValues, forKey: .serviceLocationModes)
        }
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
        case baseStreetAddress = "base_street_address"
        case baseCity = "base_city"
        case baseState = "base_state"
        case baseZipCode = "base_zip_code"
        case serviceRadiusMiles = "service_radius_miles"
        case serviceLocationMode = "service_location_mode"
        case serviceLocationModes = "service_location_modes"
        case isActive = "is_active"
    }
}

private struct GroomerBookingPreferencesUpsertRow: Encodable {
    let groomerID: UUID
    let draft: GroomerBookingPreferencesDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.maxAppointmentsPerDay, forKey: .maxAppointmentsPerDay)
        try container.encode(
            draft.minimumAdvanceNoticeDays,
            forKey: .minimumAdvanceNoticeDays
        )
        try container.encode(draft.autoAcceptBookings, forKey: .autoAcceptBookings)
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case maxAppointmentsPerDay = "max_appointments_per_day"
        case minimumAdvanceNoticeDays = "minimum_advance_notice_days"
        case autoAcceptBookings = "auto_accept_bookings"
    }
}

private struct GroomerFitClaimUpsertRow: Encodable {
    let groomerID: UUID
    let draft: GroomerFitClaimDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.signal.traitType, forKey: .traitType)
        try container.encode(draft.signal.traitValue, forKey: .traitValue)
        try container.encode(draft.isActive, forKey: .isActive)
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
        case isActive = "is_active"
    }
}

private struct GroomerAvatarUpdateRow: Encodable {
    let avatarPath: String

    private enum CodingKeys: String, CodingKey {
        case avatarPath = "avatar_path"
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

private struct GroomerPortfolioFitTagInsertRow: Encodable {
    let groomerID: UUID
    let photoID: UUID
    let draft: GroomerPortfolioFitTagDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photoID.uuidString.lowercased(), forKey: .portfolioPhotoID)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.signal.traitType, forKey: .traitType)
        try container.encode(draft.signal.traitValue, forKey: .traitValue)
    }

    private enum CodingKeys: String, CodingKey {
        case portfolioPhotoID = "portfolio_photo_id"
        case groomerID = "groomer_id"
        case traitType = "trait_type"
        case traitValue = "trait_value"
    }
}

private struct GroomerAvailabilityWindowInsertRow: Encodable {
    let groomerID: UUID
    let draft: GroomerAvailabilityDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.weekday.rawValue, forKey: .weekday)
        try container.encode(Self.timeString(fromMinutes: draft.startMinutes), forKey: .startTime)
        try container.encode(Self.timeString(fromMinutes: draft.endMinutes), forKey: .endTime)
        try container.encode(draft.isEnabled, forKey: .isEnabled)
        try container.encode(draft.timezone, forKey: .timezone)
    }

    private static func timeString(fromMinutes minutes: Int) -> String {
        let clampedMinutes = max(0, min(minutes, 23 * 60 + 59))
        let hour = clampedMinutes / 60
        let minute = clampedMinutes % 60
        return "\(String(format: "%02d", hour)):\(String(format: "%02d", minute)):00"
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case weekday
        case startTime = "start_time"
        case endTime = "end_time"
        case isEnabled = "is_enabled"
        case timezone
    }
}

private struct GroomerTimeOffWindowInsertRow: Encodable {
    let groomerID: UUID
    let draft: GroomerTimeOffDraft

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groomerID.uuidString.lowercased(), forKey: .groomerID)
        try container.encode(draft.title, forKey: .title)
        try container.encode(draft.startDate, forKey: .startDate)
        try container.encode(draft.endDate, forKey: .endDate)
    }

    private enum CodingKeys: String, CodingKey {
        case groomerID = "groomer_id"
        case title
        case startDate = "start_date"
        case endDate = "end_date"
    }
}
