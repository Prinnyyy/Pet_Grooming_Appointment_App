import Foundation

enum CustomerProfileRepositoryError: Error, Equatable, Sendable {
    case notAllowed
    case networkUnavailable
    case cancelled
    case unavailable
}

@MainActor
protocol CustomerProfileRepository: AnyObject {
    func profile(customerID: UUID) async throws -> CustomerProfileDetails

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft
    ) async throws -> CustomerProfileDetails

    func uploadAvatarPhoto(
        customerID: UUID,
        data: Data,
        contentType: CustomerAvatarPhotoContentType
    ) async throws -> String

    func avatarPhotoData(storagePath: String) async throws -> Data

    func latestAvatarPhotoPath(customerID: UUID) async throws -> String?
}

extension CustomerProfileRepository {
    func latestAvatarPhotoPath(customerID: UUID) async throws -> String? {
        nil
    }
}
