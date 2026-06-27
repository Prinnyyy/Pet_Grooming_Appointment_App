import Foundation
import UniformTypeIdentifiers

nonisolated enum GroomingServiceType:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case fullGroom = "full_groom"
    case bathAndBrush = "bath_and_brush"
    case haircutOnly = "haircut_only"
    case nailTrim = "nail_trim"
    case deShedding = "de_shedding"
    case customRequest = "custom_request"

    var id: Self { self }

    var title: String {
        switch self {
        case .fullGroom:
            "Full Groom"
        case .bathAndBrush:
            "Bath & Brush"
        case .haircutOnly:
            "Haircut Only"
        case .nailTrim:
            "Nail Trim"
        case .deShedding:
            "De-shedding"
        case .customRequest:
            "Custom Request"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGroom:
            "Bath, haircut, nail trim, ear cleaning"
        case .bathAndBrush:
            "Bath, blow dry, brushing"
        case .haircutOnly:
            "Trim and style shaping"
        case .nailTrim:
            "Quick clip and file"
        case .deShedding:
            "Deshed treatment and blow out"
        case .customRequest:
            "Describe exactly what you need"
        }
    }
}

nonisolated enum PetBreedGroup:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case poodle
    case terrier

    var id: Self { self }

    static func group(forBreed breed: String?) -> Self? {
        guard let normalizedBreed = normalized(breed), !normalizedBreed.isEmpty else {
            return nil
        }

        if normalizedBreed.contains("poodle") {
            return .poodle
        }

        if normalizedBreed.contains("terrier")
            || normalizedBreed.contains("westie")
            || normalizedBreed.contains("west highland")
        {
            return .terrier
        }

        return nil
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

nonisolated enum PetCareFlag:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case anxious
    case reactive
    case puppy
    case senior

    var id: Self { self }

    static func flags(
        for pet: GroomingRequestPetSnapshot,
        referenceDate: Date = Date()
    ) -> Set<Self> {
        var flags = Set<Self>()

        let temperamentFlags = temperamentFlags(pet.temperament)
        if temperamentFlags.contains(.anxious) {
            flags.insert(.anxious)
        }
        if temperamentFlags.contains(.reactive) {
            flags.insert(.reactive)
        }

        if isPuppy(birthday: pet.birthday, referenceDate: referenceDate) {
            flags.insert(.puppy)
        } else if isSenior(birthday: pet.birthday, referenceDate: referenceDate) {
            flags.insert(.senior)
        }

        return flags
    }

    private static func temperamentFlags(_ temperament: String?) -> Set<Self> {
        guard let normalizedTemperament = normalized(temperament) else {
            return []
        }

        if ["reactive", "protective"].contains(normalizedTemperament) {
            return [.reactive]
        }

        if ["anxious", "nervous", "shy"].contains(normalizedTemperament) {
            return [.anxious]
        }

        return []
    }

    private static func isPuppy(
        birthday: String?,
        referenceDate: Date
    ) -> Bool {
        guard
            let birthday,
            let birthdayDate = birthdayDate(from: birthday)
        else {
            return false
        }

        let age = Calendar(identifier: .gregorian).dateComponents(
            [.month],
            from: birthdayDate,
            to: referenceDate
        )
        return (age.month ?? Int.max) < 18
    }

    private static func isSenior(
        birthday: String?,
        referenceDate: Date
    ) -> Bool {
        guard
            let birthday,
            let birthdayDate = birthdayDate(from: birthday)
        else {
            return false
        }

        let age = Calendar(identifier: .gregorian).dateComponents(
            [.year],
            from: birthdayDate,
            to: referenceDate
        )
        return (age.year ?? 0) >= 10
    }

    private static func birthdayDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

nonisolated enum PetFitTrait:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case curlyCoat = "curly_coat"
    case deSheddingTreatment = "de_shedding_treatment"
    case fullHaircutStyling = "full_haircut_styling"
    case gentleHandling = "gentle_handling"
    case handStrippingCarding = "hand_stripping_carding"
    case mattedCoatHandling = "matted_coat_handling"
    case nailPawCare = "nail_paw_care"
    case puppyFirstGroom = "puppy_first_groom"
    case reactiveLowTolerance = "reactive_low_tolerance"
    case seniorCare = "senior_care"
    case terrierCoat = "terrier_coat"

    var id: Self { self }

    static func serviceFit(
        for pet: GroomingRequestPetSnapshot,
        serviceType: GroomingServiceType,
        referenceDate: Date = Date()
    ) -> Set<Self> {
        var traits = Set<Self>()

        switch serviceType {
        case .fullGroom, .haircutOnly:
            traits.insert(.fullHaircutStyling)
        case .deShedding:
            traits.insert(.deSheddingTreatment)
        case .nailTrim:
            traits.insert(.nailPawCare)
        case .bathAndBrush, .customRequest:
            break
        }

        switch PetBreedGroup.group(forBreed: pet.breed) {
        case .poodle:
            if serviceType.involvesCoatWork {
                traits.insert(.curlyCoat)
            }
        case .terrier:
            if serviceType.involvesCoatWork {
                traits.insert(.terrierCoat)
            }
        case nil:
            break
        }

        if coatType(for: pet) == .wire && serviceType.involvesCoatWork {
            traits.insert(.handStrippingCarding)
        }

        let careFlags = PetCareFlag.flags(
            for: pet,
            referenceDate: referenceDate
        )
        if careFlags.contains(.anxious) {
            traits.insert(.gentleHandling)
        }
        if careFlags.contains(.reactive) {
            traits.insert(.reactiveLowTolerance)
        }
        if careFlags.contains(.puppy) {
            traits.insert(.puppyFirstGroom)
        }
        if careFlags.contains(.senior) {
            traits.insert(.seniorCare)
        }

        if groomingNotesMentionMats(pet.groomingNotes) {
            traits.insert(.mattedCoatHandling)
        }

        return traits
    }

    private static func groomingNotesMentionMats(_ value: String?) -> Bool {
        guard let normalizedValue = normalized(value) else {
            return false
        }
        return normalizedValue.contains("mat")
            || normalizedValue.contains("tangle")
            || normalizedValue.contains("knot")
    }

    private static func coatType(
        for pet: GroomingRequestPetSnapshot
    ) -> CustomerPetCoatType? {
        if
            let storedCoatType = pet.coatType.flatMap(CustomerPetCoatType.init(storedValue:)),
            storedCoatType != .notSure
        {
            return storedCoatType
        }

        return CustomerPetCoatType.recommended(forBreed: pet.breed)
    }

    private static func normalized(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

nonisolated struct PetFitSignal:
    Hashable,
    Identifiable,
    Sendable
{
    nonisolated enum Group:
        String,
        CaseIterable,
        Hashable,
        Identifiable,
        Sendable
    {
        case coatType = "coat_type"
        case breedGroup = "breed_group"
        case sizeBand = "size_band"
        case careFlag = "care_flag"
        case serviceFit = "service_fit"

        var id: Self { self }
        var traitType: String { rawValue }

        var title: String {
            switch self {
            case .coatType:
                "Coat Type"
            case .breedGroup:
                "Breed Group"
            case .sizeBand:
                "Size Band"
            case .careFlag:
                "Care Flag"
            case .serviceFit:
                "Service Fit"
            }
        }

        var sortOrder: Int {
            switch self {
            case .coatType:
                10
            case .breedGroup:
                20
            case .sizeBand:
                30
            case .careFlag:
                40
            case .serviceFit:
                50
            }
        }
    }

    let group: Group
    let traitValue: String
    let title: String

    var id: String { "\(traitType):\(traitValue)" }
    var traitType: String { group.traitType }
    var groupTitle: String { group.title }
    var sortOrder: Int { group.sortOrder }

    static var allCases: [Self] {
        coatTypeSignals
            + breedGroupSignals
            + sizeBandSignals
            + careFlagSignals
            + serviceFitSignals
    }

    static var coatTypeSignals: [Self] {
        CustomerPetCoatType.fitSignalOptions.map { Self.coatType($0) }
    }

    static var breedGroupSignals: [Self] {
        PetBreedGroup.allCases.map { Self.breedGroup($0) }
    }

    static var sizeBandSignals: [Self] {
        CustomerPetSizeCode.allCases.map { Self.sizeBand($0) }
    }

    static var careFlagSignals: [Self] {
        PetCareFlag.allCases.map { Self.careFlag($0) }
    }

    static var serviceFitSignals: [Self] {
        PetFitTrait.allCases.map { Self.serviceFit($0) }
    }

    static func stored(traitType: String, traitValue: String) -> Self? {
        allCases.first {
            $0.traitType == traitType && $0.traitValue == traitValue
        }
    }

    static func coatType(_ value: CustomerPetCoatType) -> Self {
        Self(
            group: .coatType,
            traitValue: value.rawValue,
            title: value.title
        )
    }

    static func breedGroup(_ value: PetBreedGroup) -> Self {
        Self(
            group: .breedGroup,
            traitValue: value.rawValue,
            title: title(for: value)
        )
    }

    static func sizeBand(_ value: CustomerPetSizeCode) -> Self {
        Self(
            group: .sizeBand,
            traitValue: value.rawValue,
            title: value.title
        )
    }

    static func careFlag(_ value: PetCareFlag) -> Self {
        Self(
            group: .careFlag,
            traitValue: value.rawValue,
            title: title(for: value)
        )
    }

    static func serviceFit(_ value: PetFitTrait) -> Self {
        Self(
            group: .serviceFit,
            traitValue: value.rawValue,
            title: title(for: value)
        )
    }

    static func signals(
        for pet: GroomingRequestPetSnapshot,
        serviceType: GroomingServiceType,
        referenceDate: Date = Date()
    ) -> [Self] {
        var signals: [Self] = []

        if let coatType = coatType(for: pet) {
            signals.append(Self.coatType(coatType))
        }

        if let breedGroup = PetBreedGroup.group(forBreed: pet.breed) {
            signals.append(Self.breedGroup(breedGroup))
        }

        if let sizeBand = sizeBand(for: pet) {
            signals.append(Self.sizeBand(sizeBand))
        }

        let careFlags = PetCareFlag.flags(
            for: pet,
            referenceDate: referenceDate
        )
        signals.append(
            contentsOf: PetCareFlag.allCases
                .filter { careFlags.contains($0) }
                .map { Self.careFlag($0) }
        )

        let serviceFitTraits = PetFitTrait.serviceFit(
            for: pet,
            serviceType: serviceType,
            referenceDate: referenceDate
        )
        signals.append(
            contentsOf: PetFitTrait.allCases
                .filter { serviceFitTraits.contains($0) }
                .map { Self.serviceFit($0) }
        )

        return signals
    }

    private static func coatType(
        for pet: GroomingRequestPetSnapshot
    ) -> CustomerPetCoatType? {
        if
            let storedCoatType = pet.coatType.flatMap(CustomerPetCoatType.init(storedValue:)),
            storedCoatType != .notSure
        {
            return storedCoatType
        }

        return CustomerPetCoatType.recommended(forBreed: pet.breed)
    }

    private static func sizeBand(
        for pet: GroomingRequestPetSnapshot
    ) -> CustomerPetSizeCode? {
        if let weightLbs = pet.weightLbs {
            return CustomerPetSizeCode.code(forWeightLbs: weightLbs)
        }

        if
            let size = pet.size,
            let storedSize = CustomerPetSizeCode(storedValue: size)
        {
            return storedSize
        }

        return nil
    }

    private static func title(for value: PetBreedGroup) -> String {
        switch value {
        case .poodle:
            "Poodle"
        case .terrier:
            "Terrier"
        }
    }

    private static func title(for value: PetCareFlag) -> String {
        switch value {
        case .anxious:
            "Anxious"
        case .reactive:
            "Reactive"
        case .puppy:
            "Puppy"
        case .senior:
            "Senior"
        }
    }

    private static func title(for value: PetFitTrait) -> String {
        switch value {
        case .curlyCoat:
            "Curly Coat"
        case .deSheddingTreatment:
            "De-shedding Treatment"
        case .fullHaircutStyling:
            "Full Haircut & Styling"
        case .gentleHandling:
            "Gentle Handling"
        case .handStrippingCarding:
            "Hand Stripping / Carding"
        case .mattedCoatHandling:
            "Matted Coat Handling"
        case .nailPawCare:
            "Nail Trim & Paw Care"
        case .puppyFirstGroom:
            "Puppy / First Groom"
        case .reactiveLowTolerance:
            "Reactive / Low-Tolerance Dogs"
        case .seniorCare:
            "Senior Care"
        case .terrierCoat:
            "Terrier Coat"
        }
    }
}

private extension GroomingServiceType {
    nonisolated var involvesCoatWork: Bool {
        switch self {
        case .fullGroom, .bathAndBrush, .haircutOnly, .deShedding, .customRequest:
            true
        case .nailTrim:
            false
        }
    }
}

nonisolated enum GroomingLocationMode:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case groomerComesToCustomer = "groomer_comes_to_customer"
    case customerComesToGroomer = "customer_comes_to_groomer"

    var id: Self { self }

    var customerTitle: String {
        switch self {
        case .groomerComesToCustomer:
            "Mobile Groomer Comes To Me"
        case .customerComesToGroomer:
            "I Can Visit The Groomer"
        }
    }

    var groomerTitle: String {
        switch self {
        case .groomerComesToCustomer:
            "I Travel To Customers"
        case .customerComesToGroomer:
            "Customers Visit My Place"
        }
    }

    var icon: String {
        switch self {
        case .groomerComesToCustomer:
            "🚐"
        case .customerComesToGroomer:
            "🏠"
        }
    }
}

nonisolated enum USStateCode:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case alabama = "AL"
    case alaska = "AK"
    case arizona = "AZ"
    case arkansas = "AR"
    case california = "CA"
    case colorado = "CO"
    case connecticut = "CT"
    case delaware = "DE"
    case districtOfColumbia = "DC"
    case florida = "FL"
    case georgia = "GA"
    case hawaii = "HI"
    case idaho = "ID"
    case illinois = "IL"
    case indiana = "IN"
    case iowa = "IA"
    case kansas = "KS"
    case kentucky = "KY"
    case louisiana = "LA"
    case maine = "ME"
    case maryland = "MD"
    case massachusetts = "MA"
    case michigan = "MI"
    case minnesota = "MN"
    case mississippi = "MS"
    case missouri = "MO"
    case montana = "MT"
    case nebraska = "NE"
    case nevada = "NV"
    case newHampshire = "NH"
    case newJersey = "NJ"
    case newMexico = "NM"
    case newYork = "NY"
    case northCarolina = "NC"
    case northDakota = "ND"
    case ohio = "OH"
    case oklahoma = "OK"
    case oregon = "OR"
    case pennsylvania = "PA"
    case rhodeIsland = "RI"
    case southCarolina = "SC"
    case southDakota = "SD"
    case tennessee = "TN"
    case texas = "TX"
    case utah = "UT"
    case vermont = "VT"
    case virginia = "VA"
    case washington = "WA"
    case westVirginia = "WV"
    case wisconsin = "WI"
    case wyoming = "WY"

    var id: Self { self }
}

struct GroomingRequestPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let customerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let createdAt: String?

    var fileName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }
}

nonisolated enum GroomingRequestPhotoContentType:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
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

nonisolated enum GroomingRequestPhotoPath {
    static func make(
        customerID: UUID,
        requestID: UUID,
        fileID: UUID = UUID(),
        contentType: GroomingRequestPhotoContentType
    ) -> String {
        [
            customerID.uuidString.lowercased(),
            requestID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}
