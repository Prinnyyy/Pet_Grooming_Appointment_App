import Foundation
import UniformTypeIdentifiers

struct CustomerPet: Equatable, Identifiable, Sendable {
    let id: UUID
    let customerID: UUID
    let name: String
    let species: String
    let breed: String?
    let coatType: String?
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

    var displayCoatType: String? {
        guard let coatType else { return nil }
        return CustomerPetCoatType(storedValue: coatType)?.title ?? coatType
    }

    var displaySize: String? {
        guard let size else { return nil }
        return CustomerPetSizeCode(storedValue: size)?.title ?? size
    }

    var displayWeightAndSize: String? {
        let sizeTitle = displaySize
            ?? weightLbs.map { CustomerPetSizeCode.code(forWeightLbs: $0).title }

        guard let weightLbs else {
            return sizeTitle
        }

        let roundedWeight = Int(weightLbs.rounded())
        let weightTitle = "\(roundedWeight)lb"
        guard let sizeTitle, !sizeTitle.isEmpty else {
            return weightTitle
        }
        return "\(weightTitle) • \(sizeTitle)"
    }
}

struct CustomerPetDraft: Equatable, Sendable {
    let name: String
    let species: String
    let breed: String?
    let coatType: String?
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

    var recommendedCoatType: CustomerPetCoatType? {
        switch self {
        case .unspecified,
             .mixedBreed:
            nil
        case .poodle,
             .toyPoodle,
             .standardPoodle,
             .bichonFrise:
            .curlyWavy
        case .miniatureSchnauzer:
            .wire
        case .labradorRetriever,
             .goldenRetriever,
             .germanShepherd,
             .rottweiler,
             .corgi,
             .shibaInu,
             .siberianHusky,
             .australianShepherd,
             .borderCollie,
             .pomeranian:
            .doubleCoat
        case .yorkshireTerrier,
             .shihTzu,
             .maltese:
            .dropCoat
        case .cockerSpaniel,
             .cavalierKingCharlesSpaniel,
             .domesticLonghair,
             .persian,
             .maineCoon,
             .ragdoll:
            .longSilky
        case .frenchBulldog,
             .bulldog,
             .beagle,
             .dachshund,
             .boxer,
             .chihuahua,
             .bostonTerrier,
             .greatDane,
             .dobermanPinscher,
             .pitBull,
             .domesticShorthair,
             .siamese,
             .britishShorthair,
             .bengal,
             .scottishFold,
             .russianBlue:
            .shortSmooth
        case .sphynx:
            .hairlessLowCoat
        }
    }

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
        let matchingOptions = allCases.filter { option in
            option.species == nil || option.species == species
        }
        let sortedOptions = matchingOptions
            .filter { $0 != .unspecified }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        return [.unspecified] + sortedOptions
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

nonisolated enum CustomerPetCoatType: String, CaseIterable, Identifiable, Sendable {
    case notSure = "not_sure"
    case curlyWavy = "curly_wavy"
    case wire
    case doubleCoat = "double_coat"
    case dropCoat = "drop_coat"
    case longSilky = "long_silky"
    case shortSmooth = "short_smooth"
    case hairlessLowCoat = "hairless_low_coat"

    var id: Self { self }

    var title: String {
        switch self {
        case .notSure:
            "Not Sure"
        case .curlyWavy:
            "Curly / Wavy"
        case .wire:
            "Wire / Terrier"
        case .doubleCoat:
            "Double Coat / Heavy Shedding"
        case .dropCoat:
            "Drop Coat"
        case .longSilky:
            "Long Silky / Feathered"
        case .shortSmooth:
            "Short Smooth"
        case .hairlessLowCoat:
            "Hairless / Very Low Coat"
        }
    }

    var subtitle: String {
        switch self {
        case .notSure:
            "Use when you cannot identify the coat"
        case .curlyWavy:
            "Poodles, doodles, bichons, similar coats"
        case .wire:
            "Wire terriers, schnauzers, hand-strip candidates"
        case .doubleCoat:
            "Huskies, shepherds, retrievers, spitz coats"
        case .dropCoat:
            "Shih Tzu, Maltese, Yorkie-style coats"
        case .longSilky:
            "Spaniel, feathered, and long flowing coats"
        case .shortSmooth:
            "Short coated breeds with simpler brushing"
        case .hairlessLowCoat:
            "Hairless or very low coat maintenance"
        }
    }

    static var displayOptions: [Self] {
        [
            .notSure,
            .curlyWavy,
            .wire,
            .doubleCoat,
            .dropCoat,
            .longSilky,
            .shortSmooth,
            .hairlessLowCoat
        ]
    }

    static var fitSignalOptions: [Self] {
        displayOptions.filter { $0 != .notSure }
    }

    static func recommended(forBreed breed: String?) -> Self? {
        guard let normalizedBreed = normalized(breed), !normalizedBreed.isEmpty else {
            return nil
        }

        if let fixedBreed = CustomerPetBreed(storedValue: normalizedBreed) {
            return fixedBreed.recommendedCoatType
        }

        if normalizedBreed.contains("poodle")
            || normalizedBreed.contains("doodle")
            || normalizedBreed.contains("bichon")
        {
            return .curlyWavy
        }

        if normalizedBreed.contains("schnauzer")
            || normalizedBreed.contains("wire")
            || normalizedBreed.contains("westie")
            || normalizedBreed.contains("west highland")
        {
            return .wire
        }

        if normalizedBreed.contains("husky")
            || normalizedBreed.contains("shepherd")
            || normalizedBreed.contains("retriever")
            || normalizedBreed.contains("corgi")
            || normalizedBreed.contains("shiba")
            || normalizedBreed.contains("spitz")
            || normalizedBreed.contains("pomeranian")
            || normalizedBreed.contains("collie")
        {
            return .doubleCoat
        }

        if normalizedBreed.contains("shih")
            || normalizedBreed.contains("maltese")
            || normalizedBreed.contains("york")
        {
            return .dropCoat
        }

        if normalizedBreed.contains("spaniel")
            || normalizedBreed.contains("cavalier")
            || normalizedBreed.contains("setter")
        {
            return .longSilky
        }

        if normalizedBreed.contains("bulldog")
            || normalizedBreed.contains("beagle")
            || normalizedBreed.contains("boxer")
            || normalizedBreed.contains("dachshund")
            || normalizedBreed.contains("doberman")
            || normalizedBreed.contains("great dane")
            || normalizedBreed.contains("boston")
            || normalizedBreed.contains("pit bull")
        {
            return .shortSmooth
        }

        if normalizedBreed.contains("sphynx")
            || normalizedBreed.contains("hairless")
        {
            return .hairlessLowCoat
        }

        return nil
    }

    init?(storedValue: String) {
        let normalized = Self.normalized(storedValue) ?? ""
        guard let value = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame
                || $0.title.caseInsensitiveCompare(storedValue.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) else {
            return nil
        }
        self = value
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
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

    static var displayOptions: [Self] {
        [.notSure] + allCases
            .filter { $0 != .notSure }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
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
