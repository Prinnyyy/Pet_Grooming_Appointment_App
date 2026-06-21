import Foundation

struct CustomerGroomingRequest: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let customerID: UUID
    let petID: UUID?
    let petSnapshot: GroomingRequestPetSnapshot
    let photoSnapshot: [GroomingRequestPhotoSnapshot]
    let serviceType: String
    let serviceNotes: String?
    let preferredStart: String
    let preferredEnd: String
    let city: String
    let state: String
    let zipCode: String
    let status: GroomingRequestStatus
    let expiresAt: String
    let createdAt: String
    let updatedAt: String

    var title: String {
        "\(serviceType) for \(petSnapshot.name)"
    }

    var locationSummary: String {
        "\(city), \(state) \(zipCode)"
    }
}

struct GroomingRequestPetSnapshot: Decodable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let species: String
    let breed: String?
    let size: String?
    let weightLbs: Double?
    let birthday: String?
    let temperament: String?
    let medicalNotes: String?
    let groomingNotes: String?
    let snapshotAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case species
        case breed
        case size
        case weightLbs = "weight_lbs"
        case birthday
        case temperament
        case medicalNotes = "medical_notes"
        case groomingNotes = "grooming_notes"
        case snapshotAt = "snapshot_at"
    }
}

struct GroomingRequestPhotoSnapshot:
    Decodable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let isPrimary: Bool
    let createdAt: String?

    var fileName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case storageBucket = "storage_bucket"
        case storagePath = "storage_path"
        case caption
        case sortOrder = "sort_order"
        case isPrimary = "is_primary"
        case createdAt = "created_at"
    }
}

nonisolated enum GroomingRequestStatus:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case open
    case hasOffers = "has_offers"
    case booked
    case cancelled
    case expired

    var title: String {
        switch self {
        case .open:
            "Open"
        case .hasOffers:
            "Has offers"
        case .booked:
            "Booked"
        case .cancelled:
            "Cancelled"
        case .expired:
            "Expired"
        }
    }

    var isOpenForOffers: Bool {
        switch self {
        case .open, .hasOffers:
            true
        case .booked, .cancelled, .expired:
            false
        }
    }
}

struct GroomingRequestDraft: Equatable, Sendable {
    let petID: UUID
    let serviceType: String
    let serviceNotes: String?
    let preferredStart: Date
    let preferredEnd: Date
    let city: String
    let state: String
    let zipCode: String
}

struct GroomingRequestPublishResult: Equatable, Sendable {
    let requestID: UUID
    let matchCount: Int
}

nonisolated enum GroomingRequestDateFormatting {
    static func serverString(from date: Date) -> String {
        serverFormatter().string(from: date)
    }

    static func displayString(from value: String) -> String {
        guard let date = date(from: value) else {
            return value
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    static func parsedDate(from value: String) -> Date? {
        date(from: value)
    }

    private static func serverFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private static func serverFormatterWithFractionalSeconds() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func date(from value: String) -> Date? {
        serverFormatter().date(from: value)
            ?? serverFormatterWithFractionalSeconds().date(from: value)
    }
}
