import Foundation

nonisolated struct BookingReviewContext: Decodable, Equatable, Sendable {
    let bookingID: UUID
    let contextRevision: UUID
    let evidenceContextVersion: Int
    let serviceAt: String?
    let allowedKeys: [ReviewEvidenceKey]

    var signals: [PetFitSignal] {
        guard evidenceContextVersion == 2 else { return [] }
        return allowedKeys.compactMap(\.signal)
    }

    private enum CodingKeys: String, CodingKey {
        case bookingID = "booking_id"
        case contextRevision = "context_revision"
        case evidenceContextVersion = "evidence_context_version"
        case serviceAt = "service_at"
        case allowedKeys = "allowed_keys"
    }
}

nonisolated struct ReviewEvidenceKey: Codable, Hashable, Sendable {
    let dimension: String
    let value: String

    var signal: PetFitSignal? {
        switch dimension {
        case "service":
            guard let service = GroomingServiceType(rawValue: value), service != .customRequest else { return nil }
            return PetFitSignal(group: .verifiedService, traitValue: value, title: service.title)
        case "coat":
            guard let coat = CustomerPetCoatType(storedValue: value), coat != .notSure, coat.rawValue == value else { return nil }
            return PetFitSignal(group: .verifiedCoat, traitValue: value, title: coat.title)
        case "size":
            guard let size = CustomerPetSizeCode(storedValue: value), size.rawValue == value else { return nil }
            return PetFitSignal(group: .verifiedSize, traitValue: value, title: size.title)
        case "care":
            let titles = ["anxious": "Anxious", "reactive": "Reactive", "puppy": "Puppy", "senior": "Senior", "matted": "Matted Coat"]
            guard let title = titles[value] else { return nil }
            return PetFitSignal(group: .verifiedCare, traitValue: value, title: title)
        default: return nil
        }
    }
}
