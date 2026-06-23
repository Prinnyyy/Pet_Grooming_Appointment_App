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
    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow]

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

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow]
}
