import Foundation

extension GroomerProfileStore {
    func required(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(trimmed.count) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound) characters."
            )
        }
        return trimmed
    }

    func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    func optionalInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try integer(trimmed, field: field, range: range)
    }

    func requiredInteger(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return try integer(trimmed, field: field, range: range)
    }

    func optionalZipCode(_ value: String) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pattern = #"^[0-9]{5}(-[0-9]{4})?$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            throw GroomerProfileFormError(
                message: "ZIP must be a valid 5-digit ZIP code."
            )
        }

        return trimmed
    }

    func integer(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let integer = Int(value), range.contains(integer) else {
            throw GroomerProfileFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound)."
            )
        }
        return integer
    }

    func price(from value: String) throws -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let price = Double(trimmed),
              price >= 0,
              price <= 100000 else {
            throw GroomerProfileFormError(
                message: "Base price must be between 0 and 100000."
            )
        }

        if let decimals = trimmed.split(separator: ".").dropFirst().first,
           decimals.count > 2 {
            throw GroomerProfileFormError(
                message: "Base price can use at most 2 decimal places."
            )
        }

        return price
    }

    static func sortFitClaims(
        _ lhs: GroomerFitClaim,
        _ rhs: GroomerFitClaim
    ) -> Bool {
        sortFitSignals(lhs.signal, rhs.signal)
    }

    static func sortPortfolioFitTags(
        _ lhs: GroomerPortfolioFitTag,
        _ rhs: GroomerPortfolioFitTag
    ) -> Bool {
        if lhs.portfolioPhotoID == rhs.portfolioPhotoID {
            return sortFitSignals(lhs.signal, rhs.signal)
        }
        return lhs.portfolioPhotoID.uuidString < rhs.portfolioPhotoID.uuidString
    }

    static func sortPetFitEvidenceSummary(
        _ lhs: GroomerPetFitEvidenceSummary,
        _ rhs: GroomerPetFitEvidenceSummary
    ) -> Bool {
        if lhs.confidenceTier.sortOrder != rhs.confidenceTier.sortOrder {
            return lhs.confidenceTier.sortOrder < rhs.confidenceTier.sortOrder
        }
        if lhs.completedBookingCount != rhs.completedBookingCount {
            return lhs.completedBookingCount > rhs.completedBookingCount
        }
        if lhs.positiveReviewOutcomeCount != rhs.positiveReviewOutcomeCount {
            return lhs.positiveReviewOutcomeCount > rhs.positiveReviewOutcomeCount
        }
        if lhs.structuredReviewOutcomeCount != rhs.structuredReviewOutcomeCount {
            return lhs.structuredReviewOutcomeCount > rhs.structuredReviewOutcomeCount
        }
        return sortFitSignals(lhs.signal, rhs.signal)
    }

    static func sortFitSignals(
        _ lhs: PetFitSignal,
        _ rhs: PetFitSignal
    ) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            if lhs.title == rhs.title {
                return lhs.id < rhs.id
            }
            return lhs.title < rhs.title
        }
        return lhs.sortOrder < rhs.sortOrder
    }

    func message(
        for error: GroomerProfileRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) groomer profile details."
        case .networkUnavailable:
            "Check your connection and try again."
        case .cancelled:
            "The profile action was cancelled."
        case .unavailable:
            "We could not \(action) groomer profile details. Please try again."
        }
    }

    var debugScope: String {
        "groomer.profile"
    }

    func recordStoreStart(
        _ operation: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["groomerID"] = groomerID.uuidString
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerProfileStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: eventMetadata
        )
    }

    func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerProfileStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .error,
            category: .store,
            source: "GroomerProfileStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }

    func recordStoreCancelled(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "GroomerProfileStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

}

extension CustomerPetSizeCode {
    var lowerWeightLabel: String {
        switch self {
        case .xs:
            "<10lb"
        case .s:
            "10lb"
        case .m:
            "20lb"
        case .l:
            "40lb"
        case .xl:
            "60lb"
        case .xxl:
            "80lb"
        case .giant:
            "101lb"
        }
    }

    var upperWeightLabel: String {
        switch self {
        case .xs:
            "9lb"
        case .s:
            "19lb"
        case .m:
            "39lb"
        case .l:
            "59lb"
        case .xl:
            "79lb"
        case .xxl:
            "100lb"
        case .giant:
            "101+lb"
        }
    }
}

struct GroomerProfileFormError: Error {
    let message: String
}

struct GroomerAvailabilityDayState: Equatable, Identifiable {
    let weekday: GroomerAvailabilityWeekday
    var isEnabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    var id: GroomerAvailabilityWeekday { weekday }

    var summary: String {
        isEnabled
            ? "\(GroomerAvailabilityWindow.displayTime(fromMinutes: startMinutes)) - \(GroomerAvailabilityWindow.displayTime(fromMinutes: endMinutes))"
            : "Unavailable"
    }

    static func defaultStates() -> [GroomerAvailabilityDayState] {
        GroomerAvailabilityWeekday.allCases.map {
            GroomerAvailabilityDayState(
                weekday: $0,
                isEnabled: false,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60
            )
        }
    }
}
