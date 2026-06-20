import Foundation
import UniformTypeIdentifiers

struct CustomerPet: Equatable, Identifiable, Sendable {
    let id: UUID
    let customerID: UUID
    let name: String
    let species: String
    let breed: String?
    let size: String?
    let weightLbs: Double?
    let birthday: String?
    let temperament: String?
    let medicalNotes: String?
    let groomingNotes: String?
    let isActive: Bool
}

struct CustomerPetDraft: Equatable, Sendable {
    let name: String
    let species: String
    let breed: String?
    let size: String?
    let weightLbs: Double?
    let birthday: String?
    let temperament: String?
    let medicalNotes: String?
    let groomingNotes: String?
}

struct CustomerPetPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let petID: UUID
    let customerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let isPrimary: Bool

    var fileName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }
}

nonisolated enum CustomerPetPhotoContentType: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case heic
    case heif

    var id: Self { self }

    var fileExtension: String {
        switch self {
        case .jpeg:
            "jpg"
        case .png:
            "png"
        case .heic:
            "heic"
        case .heif:
            "heif"
        }
    }

    var mimeType: String {
        switch self {
        case .jpeg:
            "image/jpeg"
        case .png:
            "image/png"
        case .heic:
            "image/heic"
        case .heif:
            "image/heif"
        }
    }

    init?(uniformType: UTType) {
        if uniformType.conforms(to: .jpeg) {
            self = .jpeg
        } else if uniformType.conforms(to: .png) {
            self = .png
        } else if uniformType.identifier == "public.heic" {
            self = .heic
        } else if uniformType.identifier == "public.heif" {
            self = .heif
        } else {
            return nil
        }
    }
}

nonisolated enum CustomerPetPhotoPath {
    static func make(
        customerID: UUID,
        petID: UUID,
        fileID: UUID = UUID(),
        contentType: CustomerPetPhotoContentType
    ) -> String {
        [
            customerID.uuidString.lowercased(),
            petID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}
