import Foundation
import UniformTypeIdentifiers

struct GroomerProfile: Equatable, Sendable {
    let userID: UUID
    var avatarPath: String? = nil
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    var baseStreetAddress: String? = nil
    let baseCity: String?
    let baseState: String?
    var baseZipCode: String? = nil
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    var serviceLocationModes: Set<GroomingLocationMode> = []
    let ratingAverage: Double
    let ratingCount: Int
    let isActive: Bool
    let isVerified: Bool

    var effectiveServiceLocationModes: Set<GroomingLocationMode> {
        if !serviceLocationModes.isEmpty {
            serviceLocationModes
        } else if let serviceLocationMode {
            [serviceLocationMode]
        } else {
            []
        }
    }
}

struct GroomerProfileDraft: Equatable, Sendable {
    let businessName: String?
    let bio: String?
    let yearsExperience: Int?
    var baseStreetAddress: String? = nil
    let baseCity: String?
    let baseStateCode: USStateCode?
    var baseZipCode: String? = nil
    let serviceRadiusMiles: Int?
    let serviceLocationMode: GroomingLocationMode?
    var serviceLocationModes: Set<GroomingLocationMode> = []
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

nonisolated struct GroomerFitClaim:
    Equatable,
    Identifiable,
    Sendable
{
    static let maximumActiveClaims = 6

    static var availableSignals: [PetFitSignal] {
        PetFitSignal.serviceFitSignals
            + PetFitSignal.breedGroupSignals
            + PetFitSignal.careFlagSignals
            + PetFitSignal.sizeBandSignals
    }

    let id: UUID
    let groomerID: UUID
    let signal: PetFitSignal
    let isActive: Bool
}

nonisolated struct GroomerFitClaimDraft:
    Equatable,
    Sendable
{
    let signal: PetFitSignal
    let isActive: Bool
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

struct GroomerBookingPreferences: Equatable, Sendable {
    let groomerID: UUID
    let maxAppointmentsPerDay: Int
    let minimumAdvanceNoticeDays: Int
    let autoAcceptBookings: Bool

    static func `default`(groomerID: UUID) -> GroomerBookingPreferences {
        GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 0,
            autoAcceptBookings: false
        )
    }
}

struct GroomerBookingPreferencesDraft: Equatable, Sendable {
    let maxAppointmentsPerDay: Int
    let minimumAdvanceNoticeDays: Int
    let autoAcceptBookings: Bool
}

struct GroomerTimeOffWindow: Equatable, Identifiable, Sendable {
    let id: UUID
    let groomerID: UUID
    let title: String
    let startDate: String
    let endDate: String

    var dateSummary: String {
        startDate == endDate ? Self.displayDate(startDate) : "\(Self.displayDate(startDate)) - \(Self.displayDate(endDate))"
    }

    private static func displayDate(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: value) else {
            return value
        }

        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct GroomerTimeOffDraft: Equatable, Sendable {
    let title: String
    let startDate: String
    let endDate: String
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

typealias GroomerAvatarPhotoContentType = GroomerPortfolioPhotoContentType

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

nonisolated enum GroomerAvatarPhotoPath {
    static func make(
        groomerID: UUID,
        fileID: UUID = UUID(),
        contentType: GroomerAvatarPhotoContentType
    ) -> String {
        [
            groomerID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}

extension Set where Element == GroomingLocationMode {
    var canonicalModes: [GroomingLocationMode] {
        GroomingLocationMode.allCases.filter { contains($0) }
    }

    var primaryMode: GroomingLocationMode? {
        canonicalModes.first
    }
}
