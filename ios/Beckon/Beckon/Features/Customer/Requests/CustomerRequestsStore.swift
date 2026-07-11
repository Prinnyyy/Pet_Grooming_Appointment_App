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

    let customerID: UUID
    private let petRepository: any CustomerPetRepository
    private let requestRepository: any CustomerRequestRepository
    private let bookingRepository: any BookingRepository
    private let appointmentReminderScheduler: any AppointmentReminderScheduling
    private let handoffAcknowledgementDefaults: UserDefaults
    private let handoffAcknowledgementStorageKey: String
    private var debugRecorder: AppDebugEventRecorder?
    private var refreshNotifications: (@MainActor () async -> Void)?

    private(set) var pets: [CustomerPet] = []
    private(set) var petPhotosByPetID: [UUID: [CustomerPetPhoto]] = [:]
    private(set) var petPhotoDataByID: [UUID: Data] = [:]
    private(set) var requests: [CustomerGroomingRequest] = []
    private(set) var requestPhotosByRequestID: [UUID: [GroomingRequestPhoto]] = [:]
    private(set) var requestPhotoDataByID: [UUID: Data] = [:]
    private(set) var bookings: [Booking] = []
    private(set) var offerReviewsByRequestID: [UUID: [CustomerOfferReview]] = [:]
    private(set) var offerErrorsByRequestID: [UUID: String] = [:]
    private(set) var loadingOfferRequestIDs: Set<UUID> = []
    private(set) var loadingMoreOfferRequestIDs: Set<UUID> = []
    private(set) var isLoadingMoreRequests = false
    private(set) var acceptingOfferIDs: Set<UUID> = []
    private(set) var cancellingRequestIDs: Set<UUID> = []
    private(set) var acknowledgedBookingHandoffRequestIDs: Set<UUID> = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var nextRequestsPageRequest: ListPageRequest?
    private(set) var nextOfferPageRequestByRequestID: [UUID: ListPageRequest] = [:]

    var errorMessage: String?
    var noticeMessage: String?
    var publishResult: GroomingRequestPublishResult?
    var isShowingWizard = false
    var wizardInitialStep: CustomerRequestWizardStep = .pet

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
        isLoading
            || isLoadingMoreRequests
            || isSubmitting
            || !acceptingOfferIDs.isEmpty
            || !cancellingRequestIDs.isEmpty
    }

    var canLoadMoreRequests: Bool {
        nextRequestsPageRequest != nil
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
            coatType: selectedPet.coatType,
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
            CustomerRequestActionCardItem(
                request: $0,
                handoff: nil,
                petAvatarPhotoData: primaryPetPhotoData(petID: $0.petID)
            )
        } + bookingHandoffs.map {
            CustomerRequestActionCardItem(
                request: $0.request,
                handoff: $0,
                petAvatarPhotoData: primaryPetPhotoData(petID: $0.request.petID)
            )
        }
    }

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        appointmentReminderScheduler: any AppointmentReminderScheduling =
            AppointmentReminderScheduler.shared,
        handoffAcknowledgementDefaults: UserDefaults = .standard,
        now: Date = Date(),
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.customerID = customerID
        self.petRepository = petRepository
        self.requestRepository = requestRepository
        self.bookingRepository = bookingRepository
        self.appointmentReminderScheduler = appointmentReminderScheduler
        self.handoffAcknowledgementDefaults = handoffAcknowledgementDefaults
        self.debugRecorder = debugRecorder
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

    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }

    func setNotificationRefresh(_ refresh: @escaping @MainActor () async -> Void) {
        refreshNotifications = refresh
    }

    func load() async {
        guard !isLoading, !isLoadingMoreRequests else { return }

        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            pets = try await petRepository.pets(customerID: customerID)
            await loadPetPhotosForWizard(startedAt: startedAt)
            let requestPage = try await requestRepository.requests(
                customerID: customerID,
                page: .first
            )
            requests = requestPage.items
            nextRequestsPageRequest = requestPage.nextRequest
            await loadRequestPhotosForRepublish(startedAt: startedAt)
            do {
                bookings = try await bookingRepository.bookings(
                    participantID: customerID,
                    role: .customer
                )
            } catch BookingRepositoryError.cancelled {
                bookings = []
                recordStoreCancelled("load.bookingHandoff", startedAt: startedAt)
            } catch {
                bookings = []
                recordStoreFailure(
                    "load.bookingHandoff",
                    error: error,
                    mappedMessage: nil,
                    startedAt: startedAt,
                    level: .warning
                )
            }
            await loadAcknowledgedBookingHandoffs(startedAt: startedAt)

            if selectedPetID == nil {
                selectedPetID = pets.first?.id
            }
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "petCount": "\(pets.count)",
                    "petPhotoCount": "\(petPhotosByPetID.values.reduce(0) { $0 + $1.count })",
                    "requestCount": "\(requests.count)",
                    "hasMoreRequests": "\(canLoadMoreRequests)",
                    "bookingCount": "\(bookings.count)",
                ]
            )
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
            errorMessage = message(for: CustomerRequestRepositoryError.unavailable, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func loadNextRequestsPage() async {
        guard !isLoading,
              !isLoadingMoreRequests,
              let pageRequest = nextRequestsPageRequest else { return }

        let startedAt = Date()
        recordStoreStart("loadNextRequestsPage")
        isLoadingMoreRequests = true
        errorMessage = nil
        defer { isLoadingMoreRequests = false }

        do {
            let page = try await requestRepository.requests(
                customerID: customerID,
                page: pageRequest
            )
            requests = ListPageMerge.appendingUnique(page.items, to: requests)
            nextRequestsPageRequest = page.nextRequest
            await loadAdditionalRequestPhotos(
                for: page.items,
                startedAt: startedAt
            )
            recordStoreSuccess(
                "loadNextRequestsPage",
                startedAt: startedAt,
                metadata: [
                    "loadedCount": "\(page.items.count)",
                    "requestCount": "\(requests.count)",
                    "hasMore": "\(canLoadMoreRequests)",
                ]
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("loadNextRequestsPage", startedAt: startedAt)
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "loadNextRequestsPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadNextRequestsPage", startedAt: startedAt)
        } catch {
            errorMessage = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "load"
            )
            recordStoreFailure(
                "loadNextRequestsPage",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func startCreate() {
        resetForm()
        selectedPetID = pets.first?.id
        wizardInitialStep = .pet
        errorMessage = nil
        noticeMessage = nil
        publishResult = nil
        isShowingWizard = true
    }

    func startRepublish(
        from request: CustomerGroomingRequest,
        now: Date = Date()
    ) {
        resetForm(now: now)
        selectedPetID = republishPetID(for: request)
        serviceType = request.serviceType
        serviceNotes = request.serviceNotes ?? ""
        locationMode = request.locationMode
        streetAddress = request.streetAddress
        city = request.city
        stateCode = USStateCode(rawValue: request.state.uppercased())
        zipCode = request.zipCode
        travelRadiusMiles = request.travelRadiusMiles ?? 15

        let range = republishPreferredRange(from: request, now: now)
        preferredStart = range.start
        preferredEnd = range.end
        pendingRequestPhotos = republishPendingPhotos(from: request)

        wizardInitialStep = .review
        errorMessage = nil
        noticeMessage = nil
        publishResult = nil
        isShowingWizard = true
    }

    @discardableResult
    func startRepublish(
        from booking: Booking,
        originalRequest: CustomerGroomingRequest?,
        now: Date = Date()
    ) -> Bool {
        guard booking.status.isCancellation else {
            errorMessage = "Only cancelled bookings can start a new request."
            return false
        }

        guard let originalRequest,
              originalRequest.id == booking.requestID else {
            errorMessage = "Original request details are unavailable. Refresh bookings and try again."
            return false
        }

        startRepublish(from: originalRequest, now: now)
        return true
    }

    func setWizardPresentation(
        _ isPresented: Bool,
        now: Date = Date()
    ) {
        if isPresented {
            isShowingWizard = true
        } else {
            cancelWizard(now: now)
        }
    }

    func cancelWizard(now: Date = Date()) {
        isShowingWizard = false
        resetForm(now: now)
        selectedPetID = pets.first?.id
        wizardInitialStep = .pet
        publishResult = nil
        errorMessage = nil
    }

    func offers(for request: CustomerGroomingRequest) -> [CustomerOfferReview] {
        offerReviewsByRequestID[request.id] ?? []
    }

    func canLoadMoreOffers(for request: CustomerGroomingRequest) -> Bool {
        nextOfferPageRequestByRequestID[request.id] != nil
    }

    func requestPhotos(for request: CustomerGroomingRequest) -> [GroomingRequestPhoto] {
        requestPhotosByRequestID[request.id, default: []]
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    $0.fileName < $1.fileName
                } else {
                    $0.sortOrder < $1.sortOrder
                }
            }
    }

    func requestPhotoData(for photo: GroomingRequestPhoto) -> Data? {
        requestPhotoDataByID[photo.id]
    }

    func petPhotos(for pet: CustomerPet) -> [CustomerPetPhoto] {
        petPhotosByPetID[pet.id, default: []]
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    $0.fileName < $1.fileName
                } else {
                    $0.sortOrder < $1.sortOrder
                }
            }
    }

    func primaryPetPhotoData(for pet: CustomerPet) -> Data? {
        let photos = petPhotos(for: pet)
        if let newestAvailableData = photos.reversed().lazy.compactMap({
            self.petPhotoDataByID[$0.id]
        }).first {
            return newestAvailableData
        }

        return nil
    }

    func primaryPetPhotoData(petID: UUID?) -> Data? {
        guard let petID, let pet = pets.first(where: { $0.id == petID }) else {
            return nil
        }

        return primaryPetPhotoData(for: pet)
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

    func isLoadingMoreOffers(for request: CustomerGroomingRequest) -> Bool {
        loadingMoreOfferRequestIDs.contains(request.id)
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

    func acknowledgeBookingHandoff(for handoff: CustomerRequestBookingHandoff) async {
        let insertion = acknowledgedBookingHandoffRequestIDs.insert(handoff.request.id)
        guard insertion.inserted else { return }
        persistAcknowledgedBookingHandoffRequestIDs()

        let startedAt = Date()
        recordStoreStart(
            "acknowledgeBookingHandoff",
            metadata: [
                "requestID": handoff.request.id.uuidString,
                "bookingID": handoff.booking.id.uuidString,
            ]
        )
        do {
            try await requestRepository.acknowledgeBookingHandoff(
                customerID: customerID,
                requestID: handoff.request.id,
                bookingID: handoff.booking.id
            )
            recordStoreSuccess(
                "acknowledgeBookingHandoff",
                startedAt: startedAt,
                metadata: [
                    "requestID": handoff.request.id.uuidString,
                    "bookingID": handoff.booking.id.uuidString,
                ]
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled(
                "acknowledgeBookingHandoff",
                startedAt: startedAt
            )
        } catch let error as CustomerRequestRepositoryError {
            recordStoreFailure(
                "acknowledgeBookingHandoff",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        } catch {
            recordStoreFailure(
                "acknowledgeBookingHandoff",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        }
    }

    func bookingDetailStore(for booking: Booking) -> BookingsStore {
        BookingsStore(
            participantID: customerID,
            role: .customer,
            repository: bookingRepository,
            initialBookings: [booking],
            debugRecorder: debugRecorder
        )
    }

    func loadOffers(for request: CustomerGroomingRequest) async {
        guard !loadingOfferRequestIDs.contains(request.id) else { return }

        let startedAt = Date()
        recordStoreStart("loadOffers", metadata: ["requestID": request.id.uuidString])
        loadingOfferRequestIDs.insert(request.id)
        offerErrorsByRequestID[request.id] = nil
        defer {
            loadingOfferRequestIDs.remove(request.id)
        }

        do {
            let page = try await requestRepository.offers(
                customerID: customerID,
                requestID: request.id,
                page: .first
            )
            offerReviewsByRequestID[request.id] = Self.displayOrdered(page.items)
            setNextOfferPageRequest(page.nextRequest, for: request.id)
            recordStoreSuccess(
                "loadOffers",
                startedAt: startedAt,
                metadata: [
                    "requestID": request.id.uuidString,
                    "offerCount": "\(offerReviewsByRequestID[request.id, default: []].count)",
                    "hasMore": "\(canLoadMoreOffers(for: request))",
                ]
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("loadOffers", startedAt: startedAt)
        } catch let error as CustomerRequestRepositoryError {
            offerErrorsByRequestID[request.id] = message(for: error, action: "load offers")
            recordStoreFailure(
                "loadOffers",
                error: error,
                mappedMessage: offerErrorsByRequestID[request.id],
                startedAt: startedAt,
                metadata: ["requestID": request.id.uuidString]
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadOffers", startedAt: startedAt)
        } catch {
            offerErrorsByRequestID[request.id] = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "load offers"
            )
            recordStoreFailure(
                "loadOffers",
                error: error,
                mappedMessage: offerErrorsByRequestID[request.id],
                startedAt: startedAt,
                metadata: ["requestID": request.id.uuidString]
            )
        }
    }

    func loadNextOffersPage(for request: CustomerGroomingRequest) async {
        guard !loadingOfferRequestIDs.contains(request.id),
              let pageRequest = nextOfferPageRequestByRequestID[request.id] else { return }

        let startedAt = Date()
        recordStoreStart(
            "loadNextOffersPage",
            metadata: ["requestID": request.id.uuidString]
        )
        loadingOfferRequestIDs.insert(request.id)
        loadingMoreOfferRequestIDs.insert(request.id)
        offerErrorsByRequestID[request.id] = nil
        defer {
            loadingOfferRequestIDs.remove(request.id)
            loadingMoreOfferRequestIDs.remove(request.id)
        }

        do {
            let page = try await requestRepository.offers(
                customerID: customerID,
                requestID: request.id,
                page: pageRequest
            )
            offerReviewsByRequestID[request.id] = Self.displayOrdered(
                ListPageMerge.appendingUnique(
                    page.items,
                    to: offerReviewsByRequestID[request.id, default: []]
                )
            )
            setNextOfferPageRequest(page.nextRequest, for: request.id)
            recordStoreSuccess(
                "loadNextOffersPage",
                startedAt: startedAt,
                metadata: [
                    "requestID": request.id.uuidString,
                    "loadedCount": "\(page.items.count)",
                    "offerCount": "\(offerReviewsByRequestID[request.id, default: []].count)",
                    "hasMore": "\(canLoadMoreOffers(for: request))",
                ]
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("loadNextOffersPage", startedAt: startedAt)
        } catch let error as CustomerRequestRepositoryError {
            offerErrorsByRequestID[request.id] = message(for: error, action: "load offers")
            recordStoreFailure(
                "loadNextOffersPage",
                error: error,
                mappedMessage: offerErrorsByRequestID[request.id],
                startedAt: startedAt,
                metadata: ["requestID": request.id.uuidString]
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("loadNextOffersPage", startedAt: startedAt)
        } catch {
            offerErrorsByRequestID[request.id] = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "load offers"
            )
            recordStoreFailure(
                "loadNextOffersPage",
                error: error,
                mappedMessage: offerErrorsByRequestID[request.id],
                startedAt: startedAt,
                metadata: ["requestID": request.id.uuidString]
            )
        }
    }

    func publish() async {
        guard !isSubmitting else { return }

        let startedAt = Date()
        recordStoreStart("publish")
        errorMessage = nil
        noticeMessage = nil
        publishResult = nil

        let draft: GroomingRequestDraft
        do {
            draft = try makeDraft()
        } catch let error as CustomerRequestFormError {
            errorMessage = error.message
            recordStoreFailure(
                "publish",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning
            )
            return
        } catch {
            errorMessage = "Check the request details and try again."
            recordStoreFailure(
                "publish",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning
            )
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
            let requestPage = try await requestRepository.requests(
                customerID: customerID,
                page: .first
            )
            requests = requestPage.items
            nextRequestsPageRequest = requestPage.nextRequest
            try await loadRequestPhotos(for: requests)
            publishResult = result
            noticeMessage = result.matchCount == 1
                ? "Request published. 1 groomer matched."
                : "Request published. \(result.matchCount) groomers matched."
            isShowingWizard = false
            resetForm()
            selectedPetID = pets.first?.id
            wizardInitialStep = .pet
            recordStoreSuccess(
                "publish",
                startedAt: startedAt,
                metadata: [
                    "matchCount": "\(result.matchCount)",
                    "pendingPhotoCount": "\(pendingRequestPhotos.count)",
                ]
            )
            await refreshNotifications?()
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("publish", startedAt: startedAt)
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "publish")
            recordStoreFailure(
                "publish",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("publish", startedAt: startedAt)
        } catch {
            errorMessage = message(for: CustomerRequestRepositoryError.unavailable, action: "publish")
            recordStoreFailure(
                "publish",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
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

        let startedAt = Date()
        recordStoreStart(
            "accept",
            metadata: [
                "requestID": request.id.uuidString,
                "offerID": offerReview.offer.id.uuidString,
            ]
        )
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
            await appointmentReminderScheduler.syncReminders(
                for: bookings,
                role: .customer
            )
            noticeMessage = didApplyLocalState
                ? "Offer accepted. Booking confirmed."
                : "Offer accepted. Booking confirmed. Refresh this request if the offer state does not update."
            recordStoreSuccess("accept", startedAt: startedAt)
        } catch BookingRepositoryError.cancelled {
            recordStoreCancelled("accept", startedAt: startedAt)
        } catch let error as BookingRepositoryError {
            errorMessage = message(for: error, action: "accept offer")
            recordStoreFailure(
                "accept",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("accept", startedAt: startedAt)
        } catch {
            errorMessage = message(
                for: BookingRepositoryError.unavailable,
                action: "accept offer"
            )
            recordStoreFailure(
                "accept",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func cancel(_ request: CustomerGroomingRequest) async {
        guard !cancellingRequestIDs.contains(request.id) else { return }
        guard request.status.isOpenForOffers else {
            errorMessage = "This request can no longer be cancelled."
            return
        }

        let startedAt = Date()
        recordStoreStart("cancel", metadata: ["requestID": request.id.uuidString])
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
            recordStoreSuccess("cancel", startedAt: startedAt)
            await refreshNotifications?()
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("cancel", startedAt: startedAt)
        } catch let error as CustomerRequestRepositoryError {
            errorMessage = message(for: error, action: "cancel")
            recordStoreFailure(
                "cancel",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("cancel", startedAt: startedAt)
        } catch {
            errorMessage = message(
                for: CustomerRequestRepositoryError.unavailable,
                action: "cancel"
            )
            recordStoreFailure(
                "cancel",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
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

    private func republishPetID(for request: CustomerGroomingRequest) -> UUID? {
        let candidateIDs = [
            request.petID,
            request.petSnapshot.id,
        ].compactMap { $0 }

        for candidateID in candidateIDs where pets.contains(where: { $0.id == candidateID }) {
            return candidateID
        }

        return pets.first?.id
    }

    private func republishPreferredRange(
        from request: CustomerGroomingRequest,
        now: Date
    ) -> (start: Date, end: Date) {
        let earliestPreferredStart = now.addingTimeInterval(
            Self.minimumPreferredStartLeadTime
        )
        guard
            let start = GroomingRequestDateFormatting.parsedDate(
                from: request.preferredStart
            ),
            let end = GroomingRequestDateFormatting.parsedDate(
                from: request.preferredEnd
            ),
            start >= earliestPreferredStart,
            end > start
        else {
            return Self.defaultPreferredRange(now: now)
        }

        return (start, end)
    }

    private func republishPendingPhotos(
        from request: CustomerGroomingRequest
    ) -> [PendingGroomingRequestPhoto] {
        requestPhotos(for: request).compactMap { photo in
            guard let data = requestPhotoData(for: photo),
                  data.count <= Self.maximumRequestPhotoBytes else {
                return nil
            }

            return PendingGroomingRequestPhoto(
                data: data,
                contentType: Self.republishContentType(for: photo)
            )
        }
    }

    private static func republishContentType(
        for photo: GroomingRequestPhoto
    ) -> GroomingRequestPhotoContentType {
        let fileExtension = photo.fileName
            .split(separator: ".")
            .last
            .map { String($0).lowercased() }

        switch fileExtension {
        case "png":
            return .png
        case "heic":
            return .heic
        case "heif":
            return .heif
        default:
            return .jpeg
        }
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
                    groomerAvatarPhotoData: review.groomerAvatarPhotoData,
                    matchScore: review.matchScore,
                    matchReason: review.matchReason
                )
            }
        )

        return didUpdateRequest && didUpdateAcceptedOffer
    }

    private func refreshAfterAcceptance(requestID: UUID) async {
        do {
            let requestPage = try await requestRepository.requests(
                customerID: customerID,
                page: .first
            )
            requests = requestPage.items
            nextRequestsPageRequest = requestPage.nextRequest

            let offerPage = try await requestRepository.offers(
                customerID: customerID,
                requestID: requestID,
                page: .first
            )
            offerReviewsByRequestID[requestID] = Self.displayOrdered(offerPage.items)
            setNextOfferPageRequest(offerPage.nextRequest, for: requestID)
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
                    groomerAvatarPhotoData: review.groomerAvatarPhotoData,
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

    private func loadRequestPhotos(
        for requests: [CustomerGroomingRequest]
    ) async throws {
        let photos = try await requestRepository.requestPhotos(
            customerID: customerID,
            requestIDs: requests.map(\.id)
        )
        requestPhotosByRequestID = Dictionary(grouping: photos, by: \.requestID)
        requestPhotoDataByID = await requestPhotoDataMap(for: photos)
    }

    private func loadRequestPhotosForRepublish(startedAt: Date) async {
        do {
            try await loadRequestPhotos(for: requests)
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("load.requestPhotos", startedAt: startedAt)
        } catch {
            requestPhotosByRequestID = [:]
            requestPhotoDataByID = [:]
            recordStoreFailure(
                "load.requestPhotos",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        }
    }

    private func loadAdditionalRequestPhotos(
        for requests: [CustomerGroomingRequest],
        startedAt: Date
    ) async {
        do {
            let photos = try await requestRepository.requestPhotos(
                customerID: customerID,
                requestIDs: requests.map(\.id)
            )
            for (requestID, requestPhotos) in Dictionary(grouping: photos, by: \.requestID) {
                requestPhotosByRequestID[requestID] = ListPageMerge.appendingUnique(
                    requestPhotos,
                    to: requestPhotosByRequestID[requestID, default: []]
                )
            }
            requestPhotoDataByID.merge(
                await requestPhotoDataMap(for: photos),
                uniquingKeysWith: { _, newValue in newValue }
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled("loadNextRequestsPage.requestPhotos", startedAt: startedAt)
        } catch {
            recordStoreFailure(
                "loadNextRequestsPage.requestPhotos",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        }
    }

    private func setNextOfferPageRequest(
        _ pageRequest: ListPageRequest?,
        for requestID: UUID
    ) {
        if let pageRequest {
            nextOfferPageRequestByRequestID[requestID] = pageRequest
        } else {
            nextOfferPageRequestByRequestID.removeValue(forKey: requestID)
        }
    }

    private func loadPetPhotosForWizard(startedAt: Date) async {
        do {
            let photos = try await petRepository.photos(customerID: customerID)
            petPhotosByPetID = Dictionary(grouping: photos, by: \.petID)
            petPhotoDataByID = await petPhotoDataMap(for: photos)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("load.petPhotos", startedAt: startedAt)
        } catch {
            petPhotosByPetID = [:]
            petPhotoDataByID = [:]
            recordStoreFailure(
                "load.petPhotos",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        }
    }

    private func petPhotoDataMap(
        for photos: [CustomerPetPhoto]
    ) async -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            do {
                dataByID[photo.id] = try await petRepository.photoData(photo)
            } catch {
                continue
            }
        }
        return dataByID
    }

    private func requestPhotoDataMap(
        for photos: [GroomingRequestPhoto]
    ) async -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            guard let data = try? await requestRepository.requestPhotoData(photo) else {
                continue
            }
            dataByID[photo.id] = data
        }
        return dataByID
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
        case .cancelled:
            "The pet information load was cancelled."
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
        case .cancelled:
            "The request action was cancelled."
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
        case .cancelled:
            "The booking action was cancelled."
        case .unavailable:
            "We could not \(action). Please try again."
        }
    }

    private var debugScope: String {
        "customer.requests"
    }

    private func recordStoreStart(
        _ operation: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["customerID"] = customerID.uuidString
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: eventMetadata
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date,
        level: AppDebugEventLevel = .error,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: level,
            category: .store,
            source: "CustomerRequestsStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerRequestsStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
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

    private func loadAcknowledgedBookingHandoffs(startedAt: Date) async {
        do {
            let remoteAcknowledgedRequestIDs =
                try await requestRepository.acknowledgedBookingHandoffRequestIDs(
                    customerID: customerID
                )
            guard !remoteAcknowledgedRequestIDs.isEmpty else { return }

            acknowledgedBookingHandoffRequestIDs.formUnion(remoteAcknowledgedRequestIDs)
            persistAcknowledgedBookingHandoffRequestIDs()
            recordStoreSuccess(
                "load.bookingHandoffAcknowledgements",
                startedAt: startedAt,
                metadata: [
                    "acknowledgementCount": "\(acknowledgedBookingHandoffRequestIDs.count)",
                ]
            )
        } catch CustomerRequestRepositoryError.cancelled {
            recordStoreCancelled(
                "load.bookingHandoffAcknowledgements",
                startedAt: startedAt
            )
        } catch let error as CustomerRequestRepositoryError {
            recordStoreFailure(
                "load.bookingHandoffAcknowledgements",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
        } catch {
            recordStoreFailure(
                "load.bookingHandoffAcknowledgements",
                error: error,
                mappedMessage: nil,
                startedAt: startedAt,
                level: .warning
            )
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
        "beckon.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
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
    let petAvatarPhotoData: Data?

    init(
        request: CustomerGroomingRequest,
        handoff: CustomerRequestBookingHandoff?,
        petAvatarPhotoData: Data? = nil
    ) {
        self.request = request
        self.handoff = handoff
        self.petAvatarPhotoData = petAvatarPhotoData
    }

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
