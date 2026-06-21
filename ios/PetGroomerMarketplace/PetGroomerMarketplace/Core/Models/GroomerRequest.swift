import Foundation

struct GroomerMatchedRequest: Equatable, Hashable, Identifiable, Sendable {
    let match: GroomerRequestMatch
    let request: GroomerMatchedGroomingRequest

    var id: UUID {
        match.id
    }

    var title: String {
        "\(request.serviceType) for \(request.petSnapshot.name)"
    }

    var locationSummary: String {
        request.locationSummary
    }

    var matchSummary: String {
        if let score = match.matchScore {
            return "\(match.status.title) · \(Int(score.rounded())) match"
        }

        return match.status.title
    }
}

struct GroomerRequestMatch: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let groomerID: UUID
    let customerID: UUID
    let matchScore: Double?
    let matchReason: String?
    let dismissReason: String?
    let status: RequestMatchStatus
    let viewedAt: String?
    let dismissedAt: String?
    let createdAt: String
    let updatedAt: String
}

struct GroomerMatchedGroomingRequest:
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
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

    var locationSummary: String {
        "\(city), \(state) \(zipCode)"
    }
}

nonisolated enum RequestMatchStatus:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case visible
    case viewed
    case dismissed
    case offered
    case hidden
    case expired

    static let activeValues = [
        visible.rawValue,
        viewed.rawValue,
        offered.rawValue,
    ]

    var title: String {
        switch self {
        case .visible:
            "New"
        case .viewed:
            "Viewed"
        case .dismissed:
            "Dismissed"
        case .offered:
            "Offer sent"
        case .hidden:
            "Hidden"
        case .expired:
            "Expired"
        }
    }

    var isDismissible: Bool {
        switch self {
        case .visible, .viewed:
            true
        case .dismissed, .offered, .hidden, .expired:
            false
        }
    }
}

struct DismissRequestMatchResult: Equatable, Sendable {
    let matchID: UUID
    let status: RequestMatchStatus
    let dismissedAt: String
}
