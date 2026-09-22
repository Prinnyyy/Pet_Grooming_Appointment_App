import Foundation
import Observation

enum CustomerRequestTimeWindowOption: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case detailed

    var id: Self { self }

    var title: String {
        switch self {
        case .morning:
            "Morning"
        case .afternoon:
            "Afternoon"
        case .evening:
            "Evening"
        case .detailed:
            "Detailed Time"
        }
    }

    func range(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        switch self {
        case .morning:
            Self.range(
                on: date,
                startHour: 6,
                startMinute: 0,
                endHour: 11,
                endMinute: 59,
                calendar: calendar
            )
        case .afternoon:
            Self.range(
                on: date,
                startHour: 12,
                startMinute: 0,
                endHour: 16,
                endMinute: 59,
                calendar: calendar
            )
        case .evening:
            Self.range(
                on: date,
                startHour: 17,
                startMinute: 0,
                endHour: 21,
                endMinute: 0,
                calendar: calendar
            )
        case .detailed:
            nil
        }
    }

    static func flexibleRange(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        range(
            on: date,
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            calendar: calendar
        )
    }

    private static func range(
        on date: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        ) ?? date
        let end = calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        ) ?? start.addingTimeInterval(60 * 60)
        return (start, end)
    }
}

@MainActor
@Observable
final class CustomerRequestWizardState {
    enum ProfileAddressResult: Equatable { case applied, missing, unavailable, cancelled }

    private let store: CustomerRequestsStore
    private let profileRepository: (any CustomerProfileRepository)?
    private var profileAddressReadID: UUID?
    var currentStep: CustomerRequestWizardStep
    var selectedDate: Date
    var selectedTimeWindow: CustomerRequestTimeWindowOption
    var isFlexibleWithTime = false
    var invalidFields: Set<CustomerRequestWizardValidationField> = []
    private(set) var isApplyingProfileAddress = false
    var isContinuingAfterAddressConfirmation = false

    init(store: CustomerRequestsStore, profileRepository: (any CustomerProfileRepository)? = nil) {
        self.store = store
        self.profileRepository = profileRepository
        currentStep = store.wizardInitialStep
        selectedDate = store.preferredStart
        selectedTimeWindow = store.wizardInitialStep == .review ? .detailed : .afternoon
    }

    func cancelPendingLoads() {
        profileAddressReadID = nil
        isApplyingProfileAddress = false
        isContinuingAfterAddressConfirmation = false
    }

    func applyProfileAddress() async -> ProfileAddressResult {
        guard !isApplyingProfileAddress else { return .cancelled }
        isContinuingAfterAddressConfirmation = false
        guard let profileRepository else { return .missing }
        let readID = UUID()
        let initialInput = store.addressEditorState.input
        profileAddressReadID = readID
        isApplyingProfileAddress = true
        defer {
            if profileAddressReadID == readID {
                profileAddressReadID = nil
                isApplyingProfileAddress = false
            }
        }
        do {
            let profile = try await profileRepository.profile(customerID: store.customerID)
            guard !Task.isCancelled, profileAddressReadID == readID,
                  store.addressEditorState.input == initialInput else { return .cancelled }
            guard let autofill = CustomerProfileAddressAutofill.make(from: profile) else { return .missing }
            store.applyProfileAddressAutofill(autofill)
            for field: CustomerRequestWizardValidationField in [.streetAddress, .city, .state, .zipCode] {
                clearInvalidField(field)
            }
            return .applied
        } catch {
            guard !Task.isCancelled, profileAddressReadID == readID,
                  !(error is CancellationError),
                  (error as? CustomerProfileRepositoryError) != .cancelled else { return .cancelled }
            return .unavailable
        }
    }

    func addressConfirmationChanged(from oldAddress: BeckonConfirmedAddress?, to confirmedAddress: BeckonConfirmedAddress?) {
        if store.requestCalendar != nil,
           oldAddress?.timeZoneIdentifier != confirmedAddress?.timeZoneIdentifier {
            selectedDate = store.preferredStart
            selectedTimeWindow = .detailed
            isFlexibleWithTime = false
        }
        guard isContinuingAfterAddressConfirmation, confirmedAddress != nil else { return }
        isContinuingAfterAddressConfirmation = false
        let validation = store.validateWizardStep(.time)
        invalidFields = validation.fields
        store.errorMessage = validation.isValid ? nil : validation.message
    }

    func back() {
        guard !store.isSubmitting else { return }
        if store.isRecoveringPublication {
            store.cancelWizard()
            return
        }

        if let previous = currentStep.previous {
            currentStep = previous
        } else {
            store.cancelWizard()
        }
    }

    func continueForward() async -> Bool {
        if store.isRecoveringPublication {
            return true
        }
        let validation = store.validateWizardStep(currentStep)
        guard validation.isValid else {
            if currentStep == .time,
               validation.requiresOnlyAddressConfirmation {
                invalidFields = []
                store.errorMessage = nil
                isContinuingAfterAddressConfirmation = true
                let result = await store.addressEditorState.prepareConfirmation(requiringTimeZone: true)
                guard isContinuingAfterAddressConfirmation else { return false }
                guard result != .needsReview else { return false }
                isContinuingAfterAddressConfirmation = false
                return false
            }

            invalidFields = validation.fields
            store.errorMessage = validation.message
            return false
        }

        invalidFields = []
        store.errorMessage = nil

        if currentStep == .review {
            return true
        } else if let next = currentStep.next {
            currentStep = next
        }
        return false
    }

    func applyInitialDefaults() {
        currentStep = store.wizardInitialStep
        selectedDate = store.preferredStart
        guard store.wizardInitialStep != .review else {
            selectedTimeWindow = .detailed
            isFlexibleWithTime = false
            return
        }

        selectedTimeWindow = .afternoon
        isFlexibleWithTime = false
        applySelectedTimeWindow()
    }

    func applySelectedTimeWindow() {
        guard let calendar = store.requestCalendar else { return }
        if isFlexibleWithTime {
            let range = CustomerRequestTimeWindowOption.flexibleRange(on: selectedDate, calendar: calendar)
            store.preferredStart = range.start
            store.preferredEnd = range.end
            return
        }

        guard let range = selectedTimeWindow.range(on: selectedDate, calendar: calendar) else {
            if !store.applyDetailedDate(selectedDate) { selectedDate = store.preferredStart }
            return
        }

        store.preferredStart = range.start
        store.preferredEnd = range.end
    }

    func clearInvalidField(_ field: CustomerRequestWizardValidationField) {
        guard invalidFields.remove(field) != nil else { return }

        if invalidFields.isEmpty,
           store.errorMessage == CustomerRequestWizardStepValidation.requiredFieldsMessage {
            store.errorMessage = nil
        }
    }
}
