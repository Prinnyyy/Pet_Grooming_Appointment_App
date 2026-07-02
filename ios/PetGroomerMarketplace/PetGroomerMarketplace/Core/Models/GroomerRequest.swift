import Foundation

struct GroomerMatchedRequest: Equatable, Hashable, Identifiable, Sendable {
    let match: GroomerRequestMatch
    let request: GroomerMatchedGroomingRequest
    let offer: GroomerOffer?

    var id: UUID {
        match.id
    }

    var title: String {
        "\(request.serviceType.title) for \(request.petSnapshot.name)"
    }

    var locationSummary: String {
        request.locationSummary
    }

    var matchSummary: String {
        if fitEvidencePresentation != nil {
            return "\(match.status.title) · Fit evidence available"
        }

        return match.status.title
    }

    var fitEvidencePresentation: GroomerMatchFitPresentation? {
        guard
            let rawReason = match.matchReason,
            !rawReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let reason = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return GroomerMatchFitPresentation(
            scoreText: nil,
            reason: reason
        )
    }

    var canCreateOffer: Bool {
        request.status.isOpenForOffers
            && match.status.isOfferable
            && offer?.status != .pending
    }

    func replacing(
        matchStatus: RequestMatchStatus? = nil,
        requestStatus: GroomingRequestStatus? = nil,
        offer: GroomerOffer?
    ) -> GroomerMatchedRequest {
        GroomerMatchedRequest(
            match: match.replacing(status: matchStatus ?? match.status),
            request: request.replacing(status: requestStatus ?? request.status),
            offer: offer
        )
    }
}

struct GroomerMatchFitPresentation:
    Equatable,
    Hashable,
    Sendable
{
    let scoreText: String?
    let reason: String

    var listSummary: String {
        MatchFitEvidenceReasonFormatter.explanationSummary(from: reason)
    }
}

nonisolated enum MatchFitEvidenceReasonFormatter {
    private struct Marker {
        let range: Range<String.Index>
        let title: String
    }

    static func explanationSummary(from reason: String) -> String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            return ""
        }

        let markers = [
            marker(
                in: trimmedReason,
                markerText: ". Pet-fit evidence: ",
                title: "Earned Evidence"
            ),
            marker(
                in: trimmedReason,
                markerText: ". Groomer fit signals: ",
                title: "Starter Signals"
            ),
        ]
        .compactMap(\.self)
        .sorted { $0.range.lowerBound < $1.range.lowerBound }

        guard !markers.isEmpty else {
            return "Fit Evidence: \(sentence(trimmedReason))"
        }

        var sections: [String] = []

        if let firstMarker = markers.first {
            let location = trimmedReason[..<firstMarker.range.lowerBound]
            appendSection(
                title: "Location And Service Fit",
                body: String(location),
                to: &sections
            )
        }

        for index in markers.indices {
            let marker = markers[index]
            let endIndex = markers.index(after: index) < markers.endIndex
                ? markers[markers.index(after: index)].range.lowerBound
                : trimmedReason.endIndex
            let body = trimmedReason[marker.range.upperBound..<endIndex]
            appendSection(
                title: marker.title,
                body: String(body),
                to: &sections
            )
        }

        guard !sections.isEmpty else {
            return "Fit Evidence: \(sentence(trimmedReason))"
        }

        return sections.joined(separator: " ")
    }

    private static func marker(
        in reason: String,
        markerText: String,
        title: String
    ) -> Marker? {
        guard let range = reason.range(of: markerText) else {
            return nil
        }

        return Marker(range: range, title: title)
    }

    private static func appendSection(
        title: String,
        body: String,
        to sections: inout [String]
    ) {
        let sectionBody = sentence(body)
        guard !sectionBody.isEmpty else {
            return
        }

        sections.append("\(title): \(sectionBody)")
    }

    private static func sentence(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return ""
        }

        if trimmedValue.hasSuffix(".") {
            return trimmedValue
        }

        return "\(trimmedValue)."
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

    var locationSummary: String {
        "\(streetAddress), \(city), \(state) \(zipCode)"
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

    var isOfferable: Bool {
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

struct GroomerOffer: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let matchID: UUID
    let customerID: UUID
    let groomerID: UUID
    let proposedStart: String
    let proposedEnd: String
    let priceEstimate: Double
    let message: String?
    let status: GroomerOfferStatus
    let expiresAt: String
    let withdrawnAt: String?
    let createdAt: String?
    let updatedAt: String?

    var priceSummary: String {
        priceEstimate.formatted(
            .currency(code: "USD").precision(.fractionLength(2))
        )
    }

    func replacing(
        status: GroomerOfferStatus,
        withdrawnAt: String?
    ) -> GroomerOffer {
        GroomerOffer(
            id: id,
            requestID: requestID,
            matchID: matchID,
            customerID: customerID,
            groomerID: groomerID,
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            priceEstimate: priceEstimate,
            message: message,
            status: status,
            expiresAt: expiresAt,
            withdrawnAt: withdrawnAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

nonisolated enum GroomerOfferStatus:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case pending
    case acceptedByCustomer = "accepted_by_customer"
    case declinedByCustomer = "declined_by_customer"
    case withdrawnByGroomer = "withdrawn_by_groomer"
    case expired

    var title: String {
        switch self {
        case .pending:
            "Pending"
        case .acceptedByCustomer:
            "Accepted"
        case .declinedByCustomer:
            "Declined"
        case .withdrawnByGroomer:
            "Withdrawn"
        case .expired:
            "Expired"
        }
    }
}

struct GroomerOfferDraft: Equatable, Sendable {
    let requestID: UUID
    let proposedStart: Date
    let proposedEnd: Date
    let priceEstimate: Double
    let message: String?
}

struct CreateGroomerOfferResult: Equatable, Sendable {
    let offerID: UUID
    let offerStatus: GroomerOfferStatus
    let requestStatus: GroomingRequestStatus
}

struct WithdrawGroomerOfferResult: Equatable, Sendable {
    let offerID: UUID
    let offerStatus: GroomerOfferStatus
    let withdrawnTimestamp: String
    let requestStatus: GroomingRequestStatus
}

extension GroomerRequestMatch {
    func replacing(status: RequestMatchStatus) -> GroomerRequestMatch {
        GroomerRequestMatch(
            id: id,
            requestID: requestID,
            groomerID: groomerID,
            customerID: customerID,
            matchScore: matchScore,
            matchReason: matchReason,
            dismissReason: dismissReason,
            status: status,
            viewedAt: viewedAt,
            dismissedAt: dismissedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension GroomerMatchedGroomingRequest {
    func replacing(status: GroomingRequestStatus) -> GroomerMatchedGroomingRequest {
        GroomerMatchedGroomingRequest(
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
            updatedAt: updatedAt
        )
    }
}
