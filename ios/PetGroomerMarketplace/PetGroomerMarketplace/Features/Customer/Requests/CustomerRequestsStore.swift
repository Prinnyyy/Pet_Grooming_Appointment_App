import Foundation
import Observation

@MainActor
@Observable
final class CustomerRequestsStore {
    static let minimumPreferredStartLeadTime: TimeInterval = 5 * 60

    private let customerID: UUID
    private let petRepository: any CustomerPetRepository
    private let requestRepository: any CustomerRequestRepository
    private let bookingRepository: any BookingRepository

    private(set) var pets: [CustomerPet] = []
    private(set) var requests: [CustomerGroomingRequest] = []
    private(set) var offerReviewsByRequestID: [UUID: [CustomerOfferReview]] = [:]
    private(set) var offerErrorsByRequestID: [UUID: String] = [:]
    private(set) var loadingOfferRequestIDs: Set<UUID> = []
    private(set) var acceptingOfferIDs: Set<UUID> = []
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
        isLoading || isSubmitting || !acceptingOfferIDs.isEmpty
    }

    var selectedPet: CustomerPet? {
        guard let selectedPetID else { return nil }
        return pets.first { $0.id == selectedPetID }
    }

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        now: Date = Date()
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.bookingRepository = bookingRepository

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

    func offers(for request: CustomerGroomingRequest) -> [CustomerOfferReview] {
        offerReviewsByRequestID[request.id] ?? []
    }

    func request(withID id: UUID) -> CustomerGroomingRequest? {
        requests.first { $0.id == id }
    }

    func offerError(for request: CustomerGroomingRequest) -> String? {
        offerErrorsByRequestID[request.id]
    }

    func isAcceptingOffer(_ offerID: UUID) -> Bool {
        acceptingOfferIDs.contains(offerID)
    }

    func isLoadingOffers(for request: CustomerGroomingRequest) -> Bool {
        loadingOfferRequestIDs.contains(request.id)
    }

    func loadOffers(for request: CustomerGroomingRequest) async {
        guard !loadingOfferRequestIDs.contains(request.id) else { return }

        loadingOfferRequestIDs.insert(request.id)
        offerErrorsByRequestID[request.id] = nil
        defer {
            loadingOfferRequestIDs.remove(request.id)
        }

        do {
            offerReviewsByRequestID[request.id] = Self.displayOrdered(
                try await requestRepository.offers(
                    customerID: customerID,
                    requestID: request.id
                )
            )
        } catch let error as CustomerRequestRepositoryError {
            offerErrorsByRequestID[request.id] = message(for: error, action: "load offers")
        } catch {
            offerErrorsByRequestID[request.id] = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "load offers"
            )
        }
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

    func accept(
        offerReview: CustomerOfferReview,
        for request: CustomerGroomingRequest
    ) async {
        guard !acceptingOfferIDs.contains(offerReview.offer.id) else { return }
        guard offerReview.offer.status == .pending else {
            errorMessage = "This offer can no longer be accepted."
            return
        }
        guard request.status.isOpenForOffers else {
            errorMessage = "This request can no longer become a booking."
            return
        }

        acceptingOfferIDs.insert(offerReview.offer.id)
        errorMessage = nil
        noticeMessage = nil
        defer {
            acceptingOfferIDs.remove(offerReview.offer.id)
        }

        do {
            let result = try await bookingRepository.acceptOffer(
                offerID: offerReview.offer.id
            )
            let didApplyLocalState = applyAcceptanceResult(
                result,
                requestID: request.id
            )
            await refreshAfterAcceptance(requestID: request.id)
            noticeMessage = didApplyLocalState
                ? "Offer accepted. Booking confirmed."
                : "Offer accepted. Booking confirmed. Refresh this request if the offer state does not update."
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "accept offer")
        } catch {
            errorMessage = message(
                for: BookingRepositoryError.unavailable,
                action: "accept offer"
            )
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

    private func applyAcceptanceResult(
        _ result: AcceptGroomerOfferResult,
        requestID: UUID
    ) -> Bool {
        var didUpdateRequest = false
        var didUpdateAcceptedOffer = false

        if let index = requests.firstIndex(where: { $0.id == result.requestID }) {
            requests[index] = requests[index].replacing(status: result.requestStatus)
            didUpdateRequest = true
        } else if let index = requests.firstIndex(where: { $0.id == requestID }) {
            requests[index] = requests[index].replacing(status: result.requestStatus)
            didUpdateRequest = true
        }

        let reviews = offerReviewsByRequestID[requestID] ?? []
        offerReviewsByRequestID[requestID] = Self.displayOrdered(
            reviews.map { review in
                let nextStatus: GroomerOfferStatus
                if review.offer.id == result.offerID {
                    nextStatus = result.offerStatus
                    didUpdateAcceptedOffer = true
                } else if review.offer.status == .pending {
                    nextStatus = .declinedByCustomer
                } else {
                    nextStatus = review.offer.status
                }

                return CustomerOfferReview(
                    offer: review.offer.replacing(
                        status: nextStatus,
                        withdrawnAt: review.offer.withdrawnAt
                    ),
                    groomerProfile: review.groomerProfile
                )
            }
        )

        return didUpdateRequest && didUpdateAcceptedOffer
    }

    private func refreshAfterAcceptance(requestID: UUID) async {
        do {
            requests = try await requestRepository.requests(customerID: customerID)
            offerReviewsByRequestID[requestID] = Self.displayOrdered(
                try await requestRepository.offers(
                    customerID: customerID,
                    requestID: requestID
                )
            )
            offerErrorsByRequestID[requestID] = nil
        } catch {
            offerErrorsByRequestID[requestID] = "Booking confirmed. Refresh this request to see the latest offer state."
        }
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

    private func message(
        for error: BookingRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action)."
        case .offerNotFound:
            "This offer is no longer available."
        case .offerNoLongerPending:
            "This offer can no longer be accepted."
        case .requestNoLongerOpen:
            "This request can no longer become a booking."
        case .bookingAlreadyExists:
            "This request already has a booking."
        case .bookingConflict:
            "That groomer is no longer available at the proposed time."
        case .bookingNotFound:
            "This booking is no longer available."
        case .bookingNotCancellable:
            "This booking can no longer be cancelled."
        case .bookingNotCompletable:
            "This booking can no longer be completed."
        case .bookingNotCompleted:
            "This booking must be completed before it can be reviewed."
        case .reviewAlreadyExists:
            "This booking already has a review."
        case .invalidReview:
            "Check the review and try again."
        case .invalidInput:
            "Check the offer and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .unavailable:
            "We could not \(action). Please try again."
        }
    }

    private static func defaultPreferredRange(now: Date) -> (start: Date, end: Date) {
        let start = now.addingTimeInterval(24 * 60 * 60)
        let end = start.addingTimeInterval(2 * 60 * 60)
        return (start, end)
    }

    private static func displayOrdered(
        _ offerReviews: [CustomerOfferReview]
    ) -> [CustomerOfferReview] {
        offerReviews.sorted { lhs, rhs in
            if lhs.isPending != rhs.isPending {
                return lhs.isPending
            }

            let lhsTimestamp = lhs.offer.createdAt ?? lhs.offer.updatedAt ?? ""
            let rhsTimestamp = rhs.offer.createdAt ?? rhs.offer.updatedAt ?? ""

            if lhsTimestamp != rhsTimestamp {
                return lhsTimestamp > rhsTimestamp
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

private struct CustomerRequestFormError: Error {
    let message: String
}
