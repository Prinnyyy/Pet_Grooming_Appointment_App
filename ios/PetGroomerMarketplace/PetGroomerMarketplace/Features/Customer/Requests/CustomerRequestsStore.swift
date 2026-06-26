import Foundation
import Observation

enum CustomerRequestWizardStep: Int, CaseIterable, Identifiable {
    case pet
    case service
    case time
    case details
    case review

    var id: Self { self }

    var title: String {
        switch self {
        case .pet:
            "Pet"
        case .service:
            "Service"
        case .time:
            "Time & Location"
        case .details:
            "Details"
        case .review:
            "Review"
        }
    }

    var headline: String {
        switch self {
        case .pet:
            "Who Needs Grooming?"
        case .service:
            "What Service Do You Need?"
        case .time:
            "When and Where Works Best?"
        case .details:
            "Add Helpful Details"
        case .review:
            "Review Your Request"
        }
    }

    var subtitle: String? {
        switch self {
        case .pet:
            "Choose the pet this request is for."
        case .service:
            nil
        case .time:
            "Choose a preferred time and the location details groomers need before making an offer."
        case .details:
            nil
        case .review:
            nil
        }
    }

    var progress: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }

    var previous: Self? {
        Self(rawValue: rawValue - 1)
    }

    var next: Self? {
        Self(rawValue: rawValue + 1)
    }
}

enum CustomerRequestWizardValidationField: Hashable {
    case pet
    case service
    case timeWindow
    case notes
    case streetAddress
    case city
    case state
    case zipCode
}

struct CustomerRequestWizardStepValidation: Equatable {
    static let requiredFieldsMessage =
        "Complete the highlighted required fields before continuing."

    let fields: Set<CustomerRequestWizardValidationField>
    let message: String?

    var isValid: Bool {
        fields.isEmpty
    }

    static var valid: Self {
        Self(fields: [], message: nil)
    }
}

@MainActor
@Observable
final class CustomerRequestsStore {
    static let minimumPreferredStartLeadTime: TimeInterval = 5 * 60
    static let maximumRequestPhotoBytes = 10 * 1024 * 1024

    private let customerID: UUID
    private let petRepository: any CustomerPetRepository
    private let requestRepository: any CustomerRequestRepository
    private let bookingRepository: any BookingRepository
    private let handoffAcknowledgementDefaults: UserDefaults
    private let handoffAcknowledgementStorageKey: String

    private(set) var pets: [CustomerPet] = []
    private(set) var requests: [CustomerGroomingRequest] = []
    private(set) var bookings: [Booking] = []
    private(set) var offerReviewsByRequestID: [UUID: [CustomerOfferReview]] = [:]
    private(set) var offerErrorsByRequestID: [UUID: String] = [:]
    private(set) var loadingOfferRequestIDs: Set<UUID> = []
    private(set) var acceptingOfferIDs: Set<UUID> = []
    private(set) var cancellingRequestIDs: Set<UUID> = []
    private(set) var acknowledgedBookingHandoffRequestIDs: Set<UUID> = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false

    var errorMessage: String?
    var noticeMessage: String?
    var publishResult: GroomingRequestPublishResult?
    var isShowingWizard = false

    var selectedPetID: UUID?
    var serviceType: GroomingServiceType = .fullGroom
    var serviceNotes = ""
    var preferredStart: Date
    var preferredEnd: Date
    var locationMode: GroomingLocationMode = .groomerComesToCustomer
    var streetAddress = ""
    var city = ""
    var stateCode: USStateCode?
    var zipCode = ""
    var travelRadiusMiles = 15
    private(set) var pendingRequestPhotos: [PendingGroomingRequestPhoto] = []

    var isBusy: Bool {
        isLoading || isSubmitting || !acceptingOfferIDs.isEmpty || !cancellingRequestIDs.isEmpty
    }

    var selectedPet: CustomerPet? {
        guard let selectedPetID else { return nil }
        return pets.first { $0.id == selectedPetID }
    }

    func requestFitInputSignals(referenceDate: Date = Date()) -> [PetFitSignal] {
        guard let selectedPet else { return [] }

        let snapshot = GroomingRequestPetSnapshot(
            id: selectedPet.id,
            name: selectedPet.name,
            species: selectedPet.species,
            breed: selectedPet.breed,
            size: selectedPet.size,
            weightLbs: selectedPet.weightLbs,
            birthday: selectedPet.birthday,
            temperament: selectedPet.temperament,
            medicalNotes: selectedPet.medicalNotes,
            groomingNotes: selectedPet.groomingNotes,
            snapshotAt: nil
        )

        return PetFitSignal.signals(
            for: snapshot,
            serviceType: serviceType,
            referenceDate: referenceDate
        )
    }

    var activeRequests: [CustomerGroomingRequest] {
        requests.filter(\.status.isOpenForOffers)
    }

    var bookingHandoffs: [CustomerRequestBookingHandoff] {
        var confirmedBookingsByRequestID: [UUID: Booking] = [:]
        for booking in bookings where booking.status == .confirmed {
            confirmedBookingsByRequestID[booking.requestID] = confirmedBookingsByRequestID[booking.requestID] ?? booking
        }

        return requests.compactMap { request in
            guard request.status == .booked,
                  !acknowledgedBookingHandoffRequestIDs.contains(request.id),
                  let booking = confirmedBookingsByRequestID[request.id] else {
                return nil
            }

            return CustomerRequestBookingHandoff(
                request: request,
                booking: booking
            )
        }
    }

    var visibleActionCards: [CustomerRequestActionCardItem] {
        activeRequests.map {
            CustomerRequestActionCardItem(request: $0, handoff: nil)
        } + bookingHandoffs.map {
            CustomerRequestActionCardItem(request: $0.request, handoff: $0)
        }
    }

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        handoffAcknowledgementDefaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.bookingRepository = bookingRepository
        self.handoffAcknowledgementDefaults = handoffAcknowledgementDefaults
        handoffAcknowledgementStorageKey = Self.handoffAcknowledgementStorageKey(
            customerID: customerID
        )

        let defaults = Self.defaultPreferredRange(now: now)
        preferredStart = defaults.start
        preferredEnd = defaults.end
        acknowledgedBookingHandoffRequestIDs = Self.loadAcknowledgedBookingHandoffRequestIDs(
            defaults: handoffAcknowledgementDefaults,
            key: handoffAcknowledgementStorageKey
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            pets = try await petRepository.pets(customerID: customerID)
            requests = try await requestRepository.requests(customerID: customerID)
            bookings = try await bookingRepository.bookings(
                participantID: customerID,
                role: .customer
            )

            if selectedPetID == nil {
                selectedPetID = pets.first?.id
            }
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "load bookings")
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

    func isCancelling(_ request: CustomerGroomingRequest) -> Bool {
        cancellingRequestIDs.contains(request.id)
    }

    func clearNotice(ifCurrent message: String? = nil) {
        if let message {
            guard noticeMessage == message else { return }
        }

        noticeMessage = nil
    }

    func addPendingPhoto(
        data: Data,
        contentType: GroomingRequestPhotoContentType
    ) {
        guard data.count <= Self.maximumRequestPhotoBytes else {
            errorMessage = "Choose a request photo smaller than 10 MB."
            return
        }

        pendingRequestPhotos.append(
            PendingGroomingRequestPhoto(
                data: data,
                contentType: contentType
            )
        )
        errorMessage = nil
    }

    func acknowledgeBookingHandoff(for handoff: CustomerRequestBookingHandoff) {
        let insertion = acknowledgedBookingHandoffRequestIDs.insert(handoff.request.id)
        guard insertion.inserted else { return }
        persistAcknowledgedBookingHandoffRequestIDs()
    }

    func bookingDetailStore(for booking: Booking) -> BookingsStore {
        BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: bookingRepository,
            initialBookings: [booking]
        )
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
            for photo in pendingRequestPhotos {
                _ = try await requestRepository.uploadRequestPhoto(
                    customerID: customerID,
                    requestID: result.requestID,
                    data: photo.data,
                    contentType: photo.contentType,
                    caption: nil
                )
            }
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

    func cancel(_ request: CustomerGroomingRequest) async {
        guard !cancellingRequestIDs.contains(request.id) else { return }
        guard request.status.isOpenForOffers else {
            errorMessage = "This request can no longer be cancelled."
            return
        }

        cancellingRequestIDs.insert(request.id)
        errorMessage = nil
        noticeMessage = nil
        defer {
            cancellingRequestIDs.remove(request.id)
        }

        do {
            let result = try await requestRepository.cancelRequest(
                requestID: request.id
            )
            let didApplyLocalState = applyCancellationResult(
                result,
                requestID: request.id
            )
            noticeMessage = didApplyLocalState
                ? "Request cancelled."
                : "Request cancelled. Refresh requests to see the latest state."
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "cancel")
        } catch {
            errorMessage = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "cancel"
            )
        }
    }

    func validateWizardStep(
        _ step: CustomerRequestWizardStep,
        now: Date = Date()
    ) -> CustomerRequestWizardStepValidation {
        switch step {
        case .pet:
            return validatePetStep()
        case .service:
            return .valid
        case .time:
            return validateTimeAndLocationStep(now: now)
        case .details:
            return validateDetailsStep()
        case .review:
            for requiredStep in CustomerRequestWizardStep.allCases where requiredStep != .review {
                let validation = validateWizardStep(requiredStep, now: now)
                guard validation.isValid else { return validation }
            }

            return .valid
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

        let streetAddress = try streetAddressValue(self.streetAddress)
        let city = try required(city, field: "City", range: 1...100)
        guard let stateCode else {
            throw CustomerRequestFormError(message: "Choose a state.")
        }
        let zipCode = try zipCodeValue(self.zipCode)
        let travelRadius = locationMode == .customerComesToGroomer
            ? CustomerRequestTravelRange.clampedMiles(Double(travelRadiusMiles))
            : nil

        return GroomingRequestDraft(
            petID: selectedPetID,
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            locationMode: locationMode,
            streetAddress: streetAddress,
            city: city,
            stateCode: stateCode,
            zipCode: zipCode,
            travelRadiusMiles: travelRadius
        )
    }

    private func validatePetStep() -> CustomerRequestWizardStepValidation {
        guard !pets.isEmpty else {
            return CustomerRequestWizardStepValidation(
                fields: [.pet],
                message: "Add a pet before continuing."
            )
        }

        guard let selectedPetID,
              pets.contains(where: { $0.id == selectedPetID }) else {
            return CustomerRequestWizardStepValidation(
                fields: [.pet],
                message: "Choose a pet before continuing."
            )
        }

        return .valid
    }

    private func validateTimeAndLocationStep(
        now: Date
    ) -> CustomerRequestWizardStepValidation {
        var fields: Set<CustomerRequestWizardValidationField> = []

        let earliestPreferredStart = now.addingTimeInterval(
            Self.minimumPreferredStartLeadTime
        )
        if preferredStart < earliestPreferredStart || preferredEnd <= preferredStart {
            fields.insert(.timeWindow)
        }

        let street = streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if street.isEmpty || !Self.hasStreetAddressNumberAndName(street) {
            fields.insert(.streetAddress)
        }

        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.insert(.city)
        }

        if stateCode == nil {
            fields.insert(.state)
        }

        if !Self.isValidZipCode(zipCode) {
            fields.insert(.zipCode)
        }

        guard !fields.isEmpty else { return .valid }

        return CustomerRequestWizardStepValidation(
            fields: fields,
            message: CustomerRequestWizardStepValidation.requiredFieldsMessage
        )
    }

    private func validateDetailsStep() -> CustomerRequestWizardStepValidation {
        let notes = serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard notes.count <= 2000 else {
            return CustomerRequestWizardStepValidation(
                fields: [.notes],
                message: "Service notes must be 2,000 characters or fewer."
            )
        }

        return .valid
    }

    private func resetForm(now: Date = Date()) {
        serviceType = .fullGroom
        serviceNotes = ""
        locationMode = .groomerComesToCustomer
        streetAddress = ""
        city = ""
        stateCode = nil
        zipCode = ""
        travelRadiusMiles = 15
        pendingRequestPhotos = []

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
                    groomerProfile: review.groomerProfile,
                    matchScore: review.matchScore,
                    matchReason: review.matchReason
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
            bookings = try await bookingRepository.bookings(
                participantID: customerID,
                role: .customer
            )
            offerErrorsByRequestID[requestID] = nil
        } catch {
            offerErrorsByRequestID[requestID] = "Booking confirmed. Refresh this request to see the latest offer state."
        }
    }

    private func applyCancellationResult(
        _ result: CancelGroomingRequestResult,
        requestID: UUID
    ) -> Bool {
        var didUpdateRequest = false

        if let index = requests.firstIndex(where: { $0.id == result.requestID }) {
            requests[index] = requests[index].replacing(
                status: result.requestStatus,
                updatedAt: result.cancelledTimestamp
            )
            didUpdateRequest = true
        } else if let index = requests.firstIndex(where: { $0.id == requestID }) {
            requests[index] = requests[index].replacing(
                status: result.requestStatus,
                updatedAt: result.cancelledTimestamp
            )
            didUpdateRequest = true
        }

        let reviews = offerReviewsByRequestID[requestID] ?? []
        offerReviewsByRequestID[requestID] = Self.displayOrdered(
            reviews.map { review in
                let nextStatus: GroomerOfferStatus = review.offer.status == .pending
                    ? .declinedByCustomer
                    : review.offer.status

                return CustomerOfferReview(
                    offer: review.offer.replacing(
                        status: nextStatus,
                        withdrawnAt: review.offer.withdrawnAt
                    ),
                    groomerProfile: review.groomerProfile,
                    matchScore: review.matchScore,
                    matchReason: review.matchReason
                )
            }
        )
        offerErrorsByRequestID[requestID] = nil

        return didUpdateRequest
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

    private func zipCodeValue(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidZipCode(trimmed) else {
            throw CustomerRequestFormError(message: "Enter a valid 5-digit ZIP code.")
        }
        return trimmed
    }

    private func streetAddressValue(_ value: String) throws -> String {
        let trimmed = try required(value, field: "Street address", range: 1...160)
        guard Self.hasStreetAddressNumberAndName(trimmed) else {
            throw CustomerRequestFormError(
                message: "Enter a street address with a street number and name."
            )
        }

        return trimmed
    }

    private static func hasStreetAddressNumberAndName(_ value: String) -> Bool {
        let hasStreetNumber = value.range(of: #"[0-9]"#, options: .regularExpression) != nil
        let hasStreetName = value.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
        return hasStreetNumber && hasStreetName
    }

    private static func isValidZipCode(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[0-9]{5}(-[0-9]{4})?$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
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
        case .requestNotFound:
            "This request is no longer available."
        case .requestNotCancellable:
            "This request can no longer be cancelled."
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

    private func persistAcknowledgedBookingHandoffRequestIDs() {
        let encodedRequestIDs = acknowledgedBookingHandoffRequestIDs
            .map(\.uuidString)
            .sorted()
        handoffAcknowledgementDefaults.set(
            encodedRequestIDs,
            forKey: handoffAcknowledgementStorageKey
        )
    }

    private static func loadAcknowledgedBookingHandoffRequestIDs(
        defaults: UserDefaults,
        key: String
    ) -> Set<UUID> {
        Set(
            (defaults.stringArray(forKey: key) ?? [])
                .compactMap { UUID(uuidString: $0) }
        )
    }

    private static func handoffAcknowledgementStorageKey(customerID: UUID) -> String {
        "groomly.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
    }
}

private struct CustomerRequestFormError: Error {
    let message: String
}

struct CustomerRequestBookingHandoff: Equatable, Hashable, Identifiable, Sendable {
    let request: CustomerGroomingRequest
    let booking: Booking

    var id: UUID {
        request.id
    }
}

struct CustomerRequestActionCardItem: Equatable, Hashable, Identifiable, Sendable {
    let request: CustomerGroomingRequest
    let handoff: CustomerRequestBookingHandoff?

    var id: UUID {
        request.id
    }

    var isBookingHandoff: Bool {
        handoff != nil
    }
}

struct PendingGroomingRequestPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let data: Data
    let contentType: GroomingRequestPhotoContentType

    init(
        id: UUID = UUID(),
        data: Data,
        contentType: GroomingRequestPhotoContentType
    ) {
        self.id = id
        self.data = data
        self.contentType = contentType
    }
}
