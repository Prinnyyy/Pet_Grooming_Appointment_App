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

    var displaySpecies: String {
        CustomerPetSpecies(storedValue: species)?.title ?? species
    }

    var displayBreed: String? {
        guard let breed else { return nil }
        return CustomerPetBreed(storedValue: breed)?.title ?? breed
    }

    var displaySize: String? {
        guard let size else { return nil }
        return CustomerPetSizeCode(storedValue: size)?.title ?? size
    }
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

nonisolated enum CustomerPetSpecies: String, CaseIterable, Identifiable, Sendable {
    case dog = "Dog"
    case cat = "Cat"

    var id: Self { self }
    var title: String { rawValue }

    init?(storedValue: String) {
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            return nil
        }
        self = value
    }
}

nonisolated enum CustomerPetBreed: String, CaseIterable, Identifiable, Sendable {
    case unspecified = "Unspecified"
    case mixedBreed = "Mixed Breed"
    case labradorRetriever = "Labrador Retriever"
    case goldenRetriever = "Golden Retriever"
    case germanShepherd = "German Shepherd"
    case frenchBulldog = "French Bulldog"
    case bulldog = "Bulldog"
    case poodle = "Poodle"
    case toyPoodle = "Toy Poodle"
    case standardPoodle = "Standard Poodle"
    case beagle = "Beagle"
    case rottweiler = "Rottweiler"
    case dachshund = "Dachshund"
    case corgi = "Corgi"
    case yorkshireTerrier = "Yorkshire Terrier"
    case boxer = "Boxer"
    case shihTzu = "Shih Tzu"
    case shibaInu = "Shiba Inu"
    case siberianHusky = "Siberian Husky"
    case australianShepherd = "Australian Shepherd"
    case borderCollie = "Border Collie"
    case chihuahua = "Chihuahua"
    case pomeranian = "Pomeranian"
    case maltese = "Maltese"
    case bostonTerrier = "Boston Terrier"
    case cavalierKingCharlesSpaniel = "Cavalier King Charles Spaniel"
    case greatDane = "Great Dane"
    case dobermanPinscher = "Doberman Pinscher"
    case miniatureSchnauzer = "Miniature Schnauzer"
    case pitBull = "Pit Bull"
    case bichonFrise = "Bichon Frise"
    case cockerSpaniel = "Cocker Spaniel"
    case domesticShorthair = "Domestic Shorthair"
    case domesticLonghair = "Domestic Longhair"
    case siamese = "Siamese"
    case persian = "Persian"
    case maineCoon = "Maine Coon"
    case ragdoll = "Ragdoll"
    case britishShorthair = "British Shorthair"
    case bengal = "Bengal"
    case sphynx = "Sphynx"
    case scottishFold = "Scottish Fold"
    case russianBlue = "Russian Blue"

    var id: Self { self }
    var title: String { rawValue }

    var species: CustomerPetSpecies? {
        switch self {
        case .unspecified:
            nil
        case .domesticShorthair,
             .domesticLonghair,
             .siamese,
             .persian,
             .maineCoon,
             .ragdoll,
             .britishShorthair,
             .bengal,
             .sphynx,
             .scottishFold,
             .russianBlue:
            .cat
        default:
            .dog
        }
    }

    static func options(for species: CustomerPetSpecies) -> [Self] {
        allCases.filter { option in
            option.species == nil || option.species == species
        }
    }

    init?(storedValue: String) {
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            return nil
        }
        self = value
    }
}

nonisolated enum CustomerPetSizeCode: String, CaseIterable, Identifiable, Sendable {
    case xs = "XS"
    case s = "S"
    case m = "M"
    case l = "L"
    case xl = "XL"
    case xxl = "XXL"
    case giant = "Giant"

    var id: Self { self }
    var title: String { rawValue }

    static func code(forWeightLbs weight: Double) -> Self {
        switch weight {
        case ..<10:
            .xs
        case 10..<20:
            .s
        case 20..<40:
            .m
        case 40..<60:
            .l
        case 60..<80:
            .xl
        case 80...100:
            .xxl
        default:
            .giant
        }
    }

    init?(storedValue: String) {
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            return nil
        }
        self = value
    }
}

nonisolated enum CustomerPetTemperament: String, CaseIterable, Identifiable, Sendable {
    case notSure = "Not Sure"
    case friendly = "Friendly"
    case playful = "Playful"
    case calm = "Calm"
    case gentle = "Gentle"
    case energetic = "Energetic"
    case shy = "Shy"
    case anxious = "Anxious"
    case reactive = "Reactive"
    case independent = "Independent"
    case affectionate = "Affectionate"
    case protective = "Protective"
    case social = "Social"
    case nervous = "Nervous"

    var id: Self { self }
    var title: String { rawValue }

    init?(storedValue: String) {
        let normalized = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            return nil
        }
        self = value
    }
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
