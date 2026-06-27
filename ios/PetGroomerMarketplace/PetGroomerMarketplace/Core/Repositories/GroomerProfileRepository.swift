import Foundation

enum GroomerProfileRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case networkUnavailable
    case unavailable
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
    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim]
    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary]

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
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
    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        throw GroomerProfileRepositoryError.unavailable
    }

    func latestAvatarPhotoPath(groomerID: UUID) async throws -> String? {
        nil
    }
}
