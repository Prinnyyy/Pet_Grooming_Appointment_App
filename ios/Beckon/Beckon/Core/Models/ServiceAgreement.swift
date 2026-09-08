import Foundation

struct ServiceAgreement: Decodable, Equatable, Hashable, Sendable {
    let schemaVersion: Int
    let requestRevision: UUID
    let quoteRevision: UUID
    let petID: UUID
    let petSnapshot: GroomingRequestPetSnapshot
    let serviceType: GroomingServiceType
    let serviceNotes: String?
    let locationMode: GroomingLocationMode
    let address: ServiceAgreementAddress
    let serviceTimeZoneIdentifier: String
    let scheduledStart: String
    let scheduledEnd: String
    let priceEstimate: Double
    let currency: String
    let capturedAt: String

    nonisolated var isSupported: Bool {
        schemaVersion == 1 && currency == "USD"
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case requestRevision = "request_revision"
        case quoteRevision = "quote_revision"
        case petID = "pet_id"
        case petSnapshot = "pet_snapshot"
        case serviceType = "service_type"
        case serviceNotes = "service_notes"
        case locationMode = "location_mode"
        case address
        case serviceTimeZoneIdentifier = "service_time_zone_identifier"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case priceEstimate = "price_estimate"
        case currency
        case capturedAt = "captured_at"
    }
}

nonisolated struct ServiceAgreementAddress: Decodable, Equatable, Hashable, Sendable {
    let streetAddress: String
    let addressLine2: String?
    let city: String
    let state: String
    let zipCode: String
    let countryCode: String

    var summary: String {
        [streetAddress, addressLine2, city, state, zipCode, countryCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private enum CodingKeys: String, CodingKey {
        case streetAddress = "street_address"
        case addressLine2 = "address_line_2"
        case city, state
        case zipCode = "zip_code"
        case countryCode = "country_code"
    }
}

nonisolated struct QuoteEvaluation: Decodable, Equatable, Hashable, Sendable {
    let termsValid: Bool
    let selectable: Bool
    let reason: String

    var summary: String {
        switch reason {
        case "available": "Available to confirm"
        case "capacity_unavailable": "This time is currently unavailable. Check again before the offer expires."
        case "expired": "This offer has expired. Request a new offer."
        case "superseded": "The request or agreed details changed. Request a new offer."
        case "withdrawn": "The groomer withdrew this offer."
        case "legacy_unverified": "These offer details need confirmation. Request a new offer."
        case "eligibility_revoked": "The service is no longer offered under these terms. Request a new offer."
        default: "Offer availability could not be confirmed. Refresh before continuing."
        }
    }

    private enum CodingKeys: String, CodingKey {
        case termsValid = "terms_valid"
        case selectable, reason
    }
}
