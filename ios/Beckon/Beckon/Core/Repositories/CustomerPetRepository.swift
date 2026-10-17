import Foundation

enum CustomerPetRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case networkUnavailable
    case cancelled
    case unavailable
    case revisionConflict
    case operationIntentChanged
    case petNotFound
    case clientUpdateRequired
    case invalidInput
}

@MainActor
protocol CustomerPetRepository: AnyObject {
    func pets(customerID: UUID) async throws -> [CustomerPet]
    func pet(customerID: UUID, petID: UUID) async throws -> CustomerPet?
    func photos(customerID: UUID) async throws -> [CustomerPetPhoto]

    func createPet(
        customerID: UUID,
        operationID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPetSaveResult

    func updatePet(
        petID: UUID,
        expectedRevision: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet

    func softDeletePet(_ pet: CustomerPet) async throws

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data

    func deletePhoto(_ photo: CustomerPetPhoto) async throws
}

extension CustomerPetRepository {
    func pet(customerID: UUID, petID: UUID) async throws -> CustomerPet? {
        try await pets(customerID: customerID).first { $0.id == petID }
    }

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        throw CustomerPetRepositoryError.unavailable
    }
}
