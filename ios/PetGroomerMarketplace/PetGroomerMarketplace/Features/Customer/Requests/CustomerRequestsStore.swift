import Foundation
import Observation

@MainActor
@Observable
final class CustomerRequestsStore {
    static let minimumPreferredStartLeadTime: TimeInterval = 5 * 60

    private let customerID: UUID
    private let petRepository: any CustomerPetRepository
    private let requestRepository: any CustomerRequestRepository

    private(set) var pets: [CustomerPet] = []
    private(set) var requests: [CustomerGroomingRequest] = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false

    var errorMessage: String?
    var noticeMessage: String?
    var publishResult: GroomingRequestPublishResult?
    var isShowingWizard = false

    var selectedPetID: UUID?
    var serviceType = ""
    var serviceNotes = ""
    var preferredStart: Date
    var preferredEnd: Date
    var city = ""
    var state = ""
    var zipCode = ""

    var isBusy: Bool {
        isLoading || isSubmitting
    }

    var selectedPet: CustomerPet? {
        guard let selectedPetID else { return nil }
        return pets.first { $0.id == selectedPetID }
    }

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        now: Date = Date()
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository

        let defaults = Self.defaultPreferredRange(now: now)
        preferredStart = defaults.start
        preferredEnd = defaults.end
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            pets = try await petRepository.pets(customerID: customerID)
            requests = try await requestRepository.requests(customerID: customerID)

            if selectedPetID == nil {
                selectedPetID = pets.first?.id
            }
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch {
            errorMessage = message(for: CustomerRequestRepositoryError.unavailable, action: "load")
        }
    }

    func startCreate() {
        resetForm()
        selectedPetID = pets.first?.id
        errorMessage = nil
        noticeMessage = nil
        publishResult = nil
        isShowingWizard = true
    }

    func cancelWizard() {
        isShowingWizard = false
        errorMessage = nil
    }

    func publish() async {
        guard !isSubmitting else { return }

        errorMessage = nil
        noticeMessage = nil
        publishResult = nil

        let draft: GroomingRequestDraft
        do {
            draft = try makeDraft()
        } catch let error as CustomerRequestFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check the request details and try again."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await requestRepository.createRequest(
                customerID: customerID,
                draft: draft
            )
            requests = try await requestRepository.requests(customerID: customerID)
            publishResult = result
            noticeMessage = result.matchCount == 1
                ? "Request published. 1 groomer matched."
                : "Request published. \(result.matchCount) groomers matched."
            isShowingWizard = false
            resetForm()
            selectedPetID = pets.first?.id
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "publish")
        } catch {
            errorMessage = message(for: CustomerRequestRepositoryError.unavailable, action: "publish")
        }
    }

    private func makeDraft(now: Date = Date()) throws -> GroomingRequestDraft {
        guard !pets.isEmpty else {
            throw CustomerRequestFormError(
                message: "Add a pet before creating a request."
            )
        }

        guard let selectedPetID,
              pets.contains(where: { $0.id == selectedPetID }) else {
            throw CustomerRequestFormError(
                message: "Choose a pet for this request."
            )
        }

        let serviceType = try required(
            self.serviceType,
            field: "Service type",
            range: 1...80
        )
        let serviceNotes = try optional(
            self.serviceNotes,
            field: "Service notes",
            maximum: 2000
        )

        let earliestPreferredStart = now.addingTimeInterval(
            Self.minimumPreferredStartLeadTime
        )
        guard preferredStart >= earliestPreferredStart else {
            throw CustomerRequestFormError(
                message: "Preferred start must be at least 5 minutes from now."
            )
        }

        guard preferredEnd > preferredStart else {
            throw CustomerRequestFormError(
                message: "Preferred end must be after the start time."
            )
        }

        return GroomingRequestDraft(
            petID: selectedPetID,
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            city: try required(city, field: "City", range: 1...100),
            state: try required(state, field: "State", range: 2...80),
            zipCode: try required(zipCode, field: "ZIP code", range: 3...20)
        )
    }

    private func resetForm(now: Date = Date()) {
        serviceType = ""
        serviceNotes = ""
        city = ""
        state = ""
        zipCode = ""

        let defaults = Self.defaultPreferredRange(now: now)
        preferredStart = defaults.start
        preferredEnd = defaults.end
    }

    private func required(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(trimmed.count) else {
            throw CustomerRequestFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound) characters."
            )
        }
        return trimmed
    }

    private func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw CustomerRequestFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    private func message(
        for error: CustomerPetRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) customer pets."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) pet information. Please try again."
        }
    }

    private func message(
        for error: CustomerRequestRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) grooming requests."
        case .requestLimitExceeded:
            "You can have at most 3 open grooming requests."
        case .petNotFound:
            "Choose an active pet and try again."
        case .invalidInput:
            "Check the request details and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action) grooming requests. Please try again."
        }
    }

    private static func defaultPreferredRange(now: Date) -> (start: Date, end: Date) {
        let start = now.addingTimeInterval(24 * 60 * 60)
        let end = start.addingTimeInterval(2 * 60 * 60)
        return (start, end)
    }
}

private struct CustomerRequestFormError: Error {
    let message: String
}
