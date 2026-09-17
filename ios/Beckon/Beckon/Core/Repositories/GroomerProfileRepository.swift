import Foundation

enum GroomerProfileRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case networkUnavailable
    case cancelled
    case unavailable
    case availabilityConflict
    case bookingOccupancyConflict
    case availabilityUpdateRequired
}

@MainActor
protocol GroomerProfileRepository: AnyObject {
    func profile(groomerID: UUID) async throws -> GroomerProfile
    func services(groomerID: UUID) async throws -> [GroomerService]
    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto]
    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag]
    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow]
    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences
    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow]
    func availabilitySnapshot(groomerID: UUID) async throws -> GroomerAvailabilitySnapshot
    func saveAvailability(
        groomerID: UUID,
        expectedRevision: String,
        windows: [GroomerAvailabilityDraft],
        preferences: GroomerBookingPreferencesDraft,
        timeOff: [GroomerTimeOffWindow]
    ) async throws -> GroomerAvailabilitySnapshot
    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim]
    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary]

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> GroomerProfile

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService

    func deleteService(_ service: GroomerService) async throws

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String

    func avatarPhotoData(storagePath: String) async throws -> Data

    func latestAvatarPhotoPath(groomerID: UUID) async throws -> String?

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow]

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim]

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag]

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws
}

extension GroomerProfileRepository {
    func availabilitySnapshot(groomerID: UUID) async throws -> GroomerAvailabilitySnapshot {
        let windows = try await availabilityWindows(groomerID: groomerID)
        let preferences = try await bookingPreferences(groomerID: groomerID)
        let timeOff = try await timeOffWindows(groomerID: groomerID)
        return GroomerAvailabilitySnapshot(revision: nil, windows: windows, preferences: preferences, timeOff: timeOff)
    }

    func saveAvailability(
        groomerID: UUID,
        expectedRevision: String,
        windows: [GroomerAvailabilityDraft],
        preferences: GroomerBookingPreferencesDraft,
        timeOff: [GroomerTimeOffWindow]
    ) async throws -> GroomerAvailabilitySnapshot {
        throw GroomerProfileRepositoryError.availabilityUpdateRequired
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> GroomerProfile {
        try await updateProfile(groomerID: groomerID, draft: draft)
    }

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        throw GroomerProfileRepositoryError.unavailable
    }

    func latestAvatarPhotoPath(groomerID: UUID) async throws -> String? {
        nil
    }
}
