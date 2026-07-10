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

nonisolated struct GroomerServicesWorkspacePresentation: Equatable, Sendable {
    let summary: String

    init(serviceCount: Int) {
        let count = max(0, serviceCount)
        summary = switch count {
        case 0:
            "No services"
        case 1:
            "1 service"
        default:
            "\(count) services"
        }
    }
}

nonisolated struct GroomerAvailabilityWorkspacePresentation: Equatable, Sendable {
    let openDaysSummary: String
    let capacitySummary: String
    let advanceNoticeSummary: String
    let saveActionTitle: String
    let isSaveDisabled: Bool

    init(
        enabledDayCount: Int,
        maxAppointmentsPerDay: Int,
        minimumAdvanceNoticeDays: Int,
        isSaving: Bool,
        isBusy: Bool
    ) {
        let openDays = max(0, enabledDayCount)
        openDaysSummary = switch openDays {
        case 0:
            "No open days"
        case 1:
            "1 day open"
        default:
            "\(openDays) days open"
        }

        let capacity = max(1, maxAppointmentsPerDay)
        capacitySummary = capacity == 1
            ? "1 appointment per day"
            : "\(capacity) appointments per day"

        let noticeDays = min(max(minimumAdvanceNoticeDays, 0), 2)
        advanceNoticeSummary = switch noticeDays {
        case 0:
            "Same-day notice"
        case 1:
            "1 day notice"
        default:
            "\(noticeDays) days notice"
        }

        saveActionTitle = isSaving ? "Saving..." : "Save Availability"
        isSaveDisabled = isBusy
    }
}

nonisolated struct GroomerServiceFormPresentation: Equatable, Sendable {
    let saveActionTitle: String
    let isSaveDisabled: Bool

    init(isSaving: Bool, isBusy: Bool) {
        saveActionTitle = isSaving ? "Saving..." : "Save Service"
        isSaveDisabled = isBusy
    }
}

nonisolated struct GroomerFitSignalsWorkspacePresentation: Equatable, Sendable {
    let selectionSummary: String
    let saveActionTitle: String
    let isSaveDisabled: Bool

    init(
        selectedCoreFitClaimCount: Int,
        maximumActiveClaims: Int,
        isSaving: Bool,
        isBusy: Bool
    ) {
        let maximum = max(1, maximumActiveClaims)
        let selected = min(max(selectedCoreFitClaimCount, 0), maximum)

        selectionSummary = "\(selected) of \(maximum) core skills"
        saveActionTitle = isSaving ? "Saving..." : "Save Fit Signals"
        isSaveDisabled = isBusy
    }
}

nonisolated struct GroomerEvidenceWorkspacePresentation: Equatable, Sendable {
    let signalSummary: String
    let completedSummary: String
    let positiveSummary: String
    let highConfidenceSummary: String
    let isEmpty: Bool

    init(
        signalCount: Int,
        completedBookingCount: Int,
        positiveOutcomeCount: Int,
        highConfidenceCount: Int
    ) {
        let signals = max(0, signalCount)
        let completed = max(0, completedBookingCount)
        let positive = max(0, positiveOutcomeCount)
        let highConfidence = max(0, highConfidenceCount)

        signalSummary = signals == 1 ? "1 signal" : "\(signals) signals"
        completedSummary = "\(completed) completed"
        positiveSummary = "\(positive) positive"
        highConfidenceSummary = highConfidence == 1
            ? "1 high confidence"
            : "\(highConfidence) high confidence"
        isEmpty = signals == 0
    }
}

nonisolated struct GroomerPortfolioWorkspacePresentation: Equatable, Sendable {
    let photoSummary: String
    let uploadStatus: String?
    let isAddDisabled: Bool

    init(photoCount: Int, isUploading: Bool, isBusy: Bool) {
        let photos = max(0, photoCount)
        photoSummary = switch photos {
        case 0:
            "No work photos"
        case 1:
            "1 work photo"
        default:
            "\(photos) work photos"
        }
        uploadStatus = isUploading ? "Updating gallery..." : nil
        isAddDisabled = isBusy
    }
}

nonisolated struct GroomerPortfolioFitNotesPresentation: Equatable, Sendable {
    let selectionSummary: String
    let saveActionTitle: String
    let isSaveDisabled: Bool

    init(
        selectedTagCount: Int,
        maximumTagCount: Int,
        isSaving: Bool,
        isBusy: Bool
    ) {
        let maximum = max(1, maximumTagCount)
        let selected = min(max(selectedTagCount, 0), maximum)

        selectionSummary = "\(selected) of \(maximum) fit notes"
        saveActionTitle = isSaving ? "Saving..." : "Save Fit Notes"
        isSaveDisabled = isBusy
    }
}
