import Foundation

struct CustomerProfileDetails: Equatable, Sendable {
    let userID: UUID
    var nickname: String
    var avatarPath: String?
    var streetAddress: String?
    var city: String?
    var stateCode: USStateCode?
    var zipCode: String?
    var contactEmail: String?
    var phoneNumber: String?
}

struct CustomerProfileDraft: Equatable, Sendable {
    let nickname: String
    let streetAddress: String?
    let city: String?
    let stateCode: USStateCode?
    let zipCode: String?
    let contactEmail: String?
    let phoneNumber: String?
}

typealias CustomerAvatarPhotoContentType = CustomerPetPhotoContentType

nonisolated enum CustomerAvatarPhotoPath {
    static func make(
        customerID: UUID,
        fileID: UUID = UUID(),
        contentType: CustomerAvatarPhotoContentType
    ) -> String {
        [
            customerID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}
