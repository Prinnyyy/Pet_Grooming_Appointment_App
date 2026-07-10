import Foundation

nonisolated struct GroomerAccountPresentation: Equatable, Sendable {
    let identitySubtitle: String
    let profileSummary: String
    let servicesSummary: String
    let portfolioSummary: String
    let availabilitySummary: String
    let fitSignalsSummary: String
    let evidenceSummary: String

    init(
        city: String?,
        state: String?,
        fallbackDetail: String,
        hasProfile: Bool,
        isProfileActive: Bool,
        serviceCount: Int,
        activeServiceCount: Int,
        portfolioPhotoCount: Int,
        enabledAvailabilityDayCount: Int,
        selectedFitSignalCount: Int,
        evidenceSignalCount: Int
    ) {
        let normalizedCity = Self.normalized(city)
        let normalizedState = Self.normalized(state)
        identitySubtitle = switch (normalizedCity, normalizedState) {
        case let (.some(city), .some(state)):
            "\(city), \(state)"
        case let (.some(city), nil):
            city
        case let (nil, .some(state)):
            state
        case (nil, nil):
            fallbackDetail
        }

        profileSummary = hasProfile
            ? (isProfileActive ? "Active" : "Hidden")
            : "Set up"

        let validServiceCount = max(0, serviceCount)
        let activeServices = min(max(0, activeServiceCount), validServiceCount)
        servicesSummary = Self.countSummary(
            activeServices,
            zero: "No active services",
            singular: "1 active",
            plural: "active"
        )
        portfolioSummary = Self.countSummary(
            portfolioPhotoCount,
            zero: "No photos",
            singular: "1 photo",
            plural: "photos"
        )
        availabilitySummary = Self.countSummary(
            enabledAvailabilityDayCount,
            zero: "No availability",
            singular: "1 day open",
            plural: "days open"
        )
        fitSignalsSummary = Self.countSummary(
            selectedFitSignalCount,
            zero: "No signals",
            singular: "1 selected",
            plural: "selected"
        )
        evidenceSummary = Self.countSummary(
            evidenceSignalCount,
            zero: "No evidence",
            singular: "1 signal",
            plural: "signals"
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func countSummary(
        _ value: Int,
        zero: String,
        singular: String,
        plural: String
    ) -> String {
        let count = max(0, value)
        return switch count {
        case 0:
            zero
        case 1:
            singular
        default:
            "\(count) \(plural)"
        }
    }
}

nonisolated struct GroomerProfileEditorPresentation: Equatable, Sendable {
    let actionTitle: String
    let isActionDisabled: Bool

    init(isSaving: Bool, isBusy: Bool) {
        actionTitle = isSaving ? "Saving..." : "Save Profile"
        isActionDisabled = isBusy
    }
}
