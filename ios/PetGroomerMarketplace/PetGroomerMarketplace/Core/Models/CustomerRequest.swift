import Foundation

struct CustomerGroomingRequest: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let customerID: UUID
    let petID: UUID?
    let petSnapshot: GroomingRequestPetSnapshot
    let photoSnapshot: [GroomingRequestPhotoSnapshot]
    let serviceType: GroomingServiceType
    let serviceNotes: String?
    let preferredStart: String
    let preferredEnd: String
    let locationMode: GroomingLocationMode
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
    let travelRadiusMiles: Int?
    let status: GroomingRequestStatus
    let expiresAt: String
    let createdAt: String
    let updatedAt: String

    var title: String {
        "\(serviceType.title) for \(petSnapshot.name)"
    }

    var locationSummary: String {
        "\(streetAddress), \(city), \(state) \(zipCode)"
    }

    var compactLocationSummary: String {
        "\(city), \(state) \(zipCode)"
    }

    func replacing(
        status: GroomingRequestStatus,
        updatedAt: String? = nil
    ) -> CustomerGroomingRequest {
        CustomerGroomingRequest(
            id: id,
            customerID: customerID,
            petID: petID,
            petSnapshot: petSnapshot,
            photoSnapshot: photoSnapshot,
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            locationMode: locationMode,
            streetAddress: streetAddress,
            city: city,
            state: state,
            zipCode: zipCode,
            travelRadiusMiles: travelRadiusMiles,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
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
    let serviceType: GroomingServiceType
    let serviceNotes: String?
    let preferredStart: Date
    let preferredEnd: Date
    let locationMode: GroomingLocationMode
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
    let travelRadiusMiles: Int?
}

struct GroomingRequestPublishResult: Equatable, Sendable {
    let requestID: UUID
    let matchCount: Int
}

struct CancelGroomingRequestResult: Equatable, Sendable {
    let requestID: UUID
    let requestStatus: GroomingRequestStatus
    let cancelledTimestamp: String
}

struct CustomerOfferReview: Equatable, Identifiable, Sendable {
    let offer: GroomerOffer
    let groomerProfile: GroomerProfile?
    let matchScore: Double?
    let matchReason: String?

    nonisolated init(
        offer: GroomerOffer,
        groomerProfile: GroomerProfile?,
        matchScore: Double? = nil,
        matchReason: String? = nil
    ) {
        self.offer = offer
        self.groomerProfile = groomerProfile
        self.matchScore = matchScore
        self.matchReason = matchReason
    }

    var id: UUID {
        offer.id
    }

    var groomerTitle: String {
        groomerProfile?.businessName ?? "Groomer"
    }

    var groomerLocationSummary: String {
        let parts = [
            groomerProfile?.baseCity,
            groomerProfile?.baseState,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.isEmpty ? "Location unavailable" : parts.joined(separator: ", ")
    }

    var ratingSummary: String {
        guard let groomerProfile else {
            return "Rating unavailable"
        }

        guard groomerProfile.ratingCount > 0 else {
            return "No reviews yet"
        }

        let average = groomerProfile.ratingAverage.formatted(
            .number.precision(.fractionLength(1))
        )
        return "\(average) · \(groomerProfile.ratingCount) reviews"
    }

    var proposedTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: offer.proposedStart)) – \(GroomingRequestDateFormatting.displayString(from: offer.proposedEnd))"
    }

    var statusSummary: String {
        "\(offer.status.title) · \(offer.priceSummary)"
    }

    var isPending: Bool {
        offer.status == .pending
    }

    var fitEvidencePresentation: CustomerOfferFitPresentation? {
        guard
            let rawReason = matchReason,
            !rawReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let reason = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return CustomerOfferFitPresentation(
            scoreText: matchScore.map { "\(Int($0.rounded())) match" },
            reason: reason
        )
    }
}

struct CustomerOfferFitPresentation:
    Equatable,
    Hashable,
    Sendable
{
    let scoreText: String?
    let reason: String

    var listSummary: String {
        reason
    }
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
