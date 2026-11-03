import Foundation
import Observation

@MainActor
@Observable
final class GroomerOfferFormState {
    private let store: GroomerRequestsStore
    var didInitializeOfferForm = false
    private var activeInitializationID: UUID?
    var serviceTimeZone: TimeZone?
    var selectedOccurrence: Date?
    var timeZoneError: String?
    private var activeTimeZoneLoadID: UUID?
    private var initialStart: (wall: Date, instant: Date, zone: String)?
    var proposedStart = Date().addingTimeInterval(24 * 60 * 60)
    var durationMinutesText = ""
    var priceEstimateText = ""
    var message = ""
    var confirmedAssessmentKeys: Set<String> = []

    init(store: GroomerRequestsStore) {
        self.store = store
    }

    func cancelPendingLoads() {
        activeInitializationID = nil
        activeTimeZoneLoadID = nil
    }

    func submitOffer(for matchedRequest: GroomerMatchedRequest) async {
        guard didInitializeOfferForm, let proposedEnd, let start = resolvedProposedStart,
              confirmedAssessmentKeys == (matchedRequest.match.eligibilityEvaluation?.confirmationKeys ?? []) else { return }
        await store.submitOffer(for: matchedRequest, proposedStart: start, proposedEnd: proposedEnd,
            priceEstimateText: priceEstimateText, message: message, confirmedAssessmentKeys: confirmedAssessmentKeys)
    }

    // The UI edits components; transport and timing validation keep the existing total-minute representation.
    private var pickerDuration: Int { Int(durationMinutesText) ?? 60 }
    var durationHours: Int {
        get { pickerDuration / 60 }
        set { setPickerDuration(newValue * 60 + durationMinutePart) }
    }
    var durationMinutePart: Int {
        get { pickerDuration % 60 }
        set { setPickerDuration(durationHours * 60 + newValue) }
    }
    var availableDurationMinutes: ClosedRange<Int> {
        durationHours == 0 ? 15...59 : (durationHours == 12 ? 0...0 : 0...59)
    }
    private func setPickerDuration(_ minutes: Int) {
        durationMinutesText = String(min(max(minutes, GroomingServiceTiming.durationBounds.lowerBound),
            GroomingServiceTiming.durationBounds.upperBound))
    }

    var proposedEnd: Date? {
        guard let start = resolvedProposedStart else { return nil }
        return GroomerRequestsStore.proposedEnd(start: start, durationText: durationMinutesText)
    }

    var proposedStartResolution: GroomingWallTimeResolution? {
        guard let serviceTimeZone else { return nil }
        return try? GroomingServiceTiming.resolveWallInput(proposedStart,
            timeZoneIdentifier: serviceTimeZone.identifier)
    }

    var resolvedProposedStart: Date? {
        switch proposedStartResolution {
        case let .unique(date): return preservingInitialPrecision(date)
        case let .ambiguous(first, last):
            guard let selectedOccurrence, selectedOccurrence == first || selectedOccurrence == last else { return nil }
            return preservingInitialPrecision(selectedOccurrence)
        case .nonexistent, nil: return nil
        }
    }

    // DatePicker edits minutes; an untouched server/window instant may also contain seconds.
    // Preserve that precision only within the chosen occurrence, never across a wall-time edit.
    private func preservingInitialPrecision(_ date: Date) -> Date {
        guard let initialStart, initialStart.wall == proposedStart,
              initialStart.zone == serviceTimeZone?.identifier,
              initialStart.instant >= date, initialStart.instant.timeIntervalSince(date) < 60 else { return date }
        return initialStart.instant
    }

    var isInitializingOfferForm: Bool { activeInitializationID != nil }
    var isLoadingTimeZone: Bool { activeTimeZoneLoadID != nil }

    func loadServiceTimeZone(for matchedRequest: GroomerMatchedRequest) async {
        let loadID = UUID()
        activeTimeZoneLoadID = loadID
        timeZoneError = nil
        defer {
            if activeTimeZoneLoadID == loadID { activeTimeZoneLoadID = nil }
        }
        do {
            let zone = try await store.serviceTimeZoneForOffer(for: matchedRequest.request)
            guard !Task.isCancelled, activeTimeZoneLoadID == loadID else { return }
            if serviceTimeZone == nil, let zone {
                let instant = proposedStart
                proposedStart = try GroomingServiceTiming.wallInput(for: instant, timeZoneIdentifier: zone.identifier)
                initialStart = (proposedStart, instant, zone.identifier)
            }
            serviceTimeZone = zone
        } catch {
            guard !Task.isCancelled, activeTimeZoneLoadID == loadID else { return }
            timeZoneError = "Service time zone could not be loaded. Try again."
        }
    }

    func initializeOfferFormIfNeeded(
        for matchedRequest: GroomerMatchedRequest
    ) async {
        guard !didInitializeOfferForm else { return }
        let initializationID = UUID()
        activeInitializationID = initializationID
        defer {
            if activeInitializationID == initializationID { activeInitializationID = nil }
        }
        guard matchedRequest.canCreateOffer else {
            didInitializeOfferForm = true
            return
        }
        let service = await store.serviceForOffer(for: matchedRequest.request)
        guard !Task.isCancelled, activeInitializationID == initializationID else { return }
        let range = GroomerRequestsStore.defaultOfferRange(
            for: matchedRequest.request,
            durationMinutes: service?.durationMinutes
        )
        serviceTimeZone = nil
        initialStart = nil
        selectedOccurrence = nil
        proposedStart = range?.start ?? max(
            GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart) ?? Date(),
            Date().addingTimeInterval(GroomerRequestsStore.minimumProposedStartLeadTime)
        )
        await loadServiceTimeZone(for: matchedRequest)
        guard !Task.isCancelled, activeInitializationID == initializationID else { return }
        if durationMinutesText.isEmpty {
            durationMinutesText = String(service?.durationMinutes ?? 60)
        }
        if priceEstimateText.isEmpty, let service {
            priceEstimateText = String(service.basePrice)
        }
        didInitializeOfferForm = true
    }
}
