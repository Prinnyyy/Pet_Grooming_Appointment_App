import Foundation

enum CustomerPetRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case networkUnavailable
    case unavailable
}

@MainActor
protocol CustomerPetRepository: AnyObject {
    func pets(customerID: UUID) async throws -> [CustomerPet]
    func photos(customerID: UUID) async throws -> [CustomerPetPhoto]

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet

    func updatePet(
        pet: CustomerPet,
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
    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        throw CustomerPetRepositoryError.unavailable
    }
}
