import Foundation
import UniformTypeIdentifiers

struct GroomerProfile: Equatable, Sendable {
    let userID: UUID
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    let baseCity: String?
    let baseState: String?
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    let ratingAverage: Double
    let ratingCount: Int
    let isActive: Bool
    let isVerified: Bool
}

struct GroomerProfileDraft: Equatable, Sendable {
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    let baseCity: String?
    let baseStateCode: USStateCode?
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    let isActive: Bool
}

struct GroomerService: Equatable, Identifiable, Sendable {
    let id: UUID
    let groomerID: UUID
    let serviceType: GroomingServiceType
    let title: String
    let description: String?
    let basePrice: Double
    let durationMinutes: Int
    let acceptedPetSizes: [GroomerServicePetSize]
    let isActive: Bool

    var acceptedPetSizeSummary: String {
        acceptedPetSizes.isEmpty
            ? "All pet sizes"
            : acceptedPetSizes.map(\.title).joined(separator: ", ")
    }
}

struct GroomerServiceDraft: Equatable, Sendable {
    let serviceType: GroomingServiceType
    let title: String
    let description: String?
    let basePrice: Double
    let durationMinutes: Int
    let acceptedPetSizes: [GroomerServicePetSize]
    let isActive: Bool
}

nonisolated enum GroomerServicePetSize:
    String,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case small
    case medium
    case large
    case giant

    var id: Self { self }

    var title: String {
        switch self {
        case .small:
            "Small"
        case .medium:
            "Medium"
        case .large:
            "Large"
        case .giant:
            "Giant"
        }
    }
}

struct GroomerPortfolioPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let groomerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int

    var fileName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }
}

nonisolated enum GroomerAvailabilityWeekday:
    Int,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    var id: Self { self }

    var title: String {
        switch self {
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        case .sunday:
            "Sunday"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday:
            "Mon"
        case .tuesday:
            "Tue"
        case .wednesday:
            "Wed"
        case .thursday:
            "Thu"
        case .friday:
            "Fri"
        case .saturday:
            "Sat"
        case .sunday:
            "Sun"
        }
    }
}

struct GroomerAvailabilityWindow: Equatable, Identifiable, Sendable {
    let id: UUID
    let groomerID: UUID
    let weekday: GroomerAvailabilityWeekday
    let startMinutes: Int
    let endMinutes: Int
    let isEnabled: Bool
    let timezone: String

    var timeRangeSummary: String {
        "\(Self.displayTime(fromMinutes: startMinutes)) - \(Self.displayTime(fromMinutes: endMinutes))"
    }

    static func displayTime(fromMinutes minutes: Int) -> String {
        let clampedMinutes = max(0, min(minutes, 23 * 60 + 59))
        let hour = clampedMinutes / 60
        let minute = clampedMinutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

struct GroomerAvailabilityDraft: Equatable, Sendable {
    let weekday: GroomerAvailabilityWeekday
    let startMinutes: Int
    let endMinutes: Int
    let isEnabled: Bool
    let timezone: String
}

nonisolated enum GroomerPortfolioPhotoContentType:
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

nonisolated enum GroomerPortfolioPhotoPath {
    static func make(
        groomerID: UUID,
        fileID: UUID = UUID(),
        contentType: GroomerPortfolioPhotoContentType
    ) -> String {
        [
            groomerID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}
