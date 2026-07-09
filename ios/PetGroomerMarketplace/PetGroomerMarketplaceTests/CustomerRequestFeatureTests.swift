import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerRequestsStoreTests {
    @Test @MainActor
    func fixedGroomingServiceTypesUseStableBackendValuesAndTitles() {
        #expect(GroomingServiceType.allCases.map(\.rawValue) == [
            "full_groom",
            "bath_and_brush",
            "haircut_only",
            "nail_trim",
            "de_shedding",
            "custom_request",
        ])
        #expect(GroomingServiceType.fullGroom.title == "Full Groom")
        #expect(GroomingServiceType.bathAndBrush.title == "Bath & Brush")
        #expect(GroomingServiceType.customRequest.subtitle == "Describe exactly what you need")
    }

    @Test @MainActor
    func loadPopulatesPetsRequestsAndDefaultSelection() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(store.pets == [pet])
        #expect(store.requests == [request])
        #expect(store.selectedPetID == pet.id)
    }

    @Test @MainActor
    func loadPopulatesPrimaryPetPhotoDataForRequestWizard() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.petPhoto(customerID: customerID, petID: pet.id)
        let photoData = Data([0x41, 0x42, 0x43])
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .success(photoData),
            ]
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(petRepository.photosCallCount == 1)
        #expect(petRepository.photoDataCallCount == 1)
        #expect(store.primaryPetPhotoData(for: pet) == photoData)
    }

    @Test @MainActor
    func loadIgnoresUnavailablePetPhotoDataForRequestWizard() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.petPhoto(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .failure(.unavailable),
            ]
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(petRepository.photosCallCount == 1)
        #expect(petRepository.photoDataCallCount == 1)
        #expect(store.primaryPetPhotoData(for: pet) == nil)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func requestPhotoPresentationMarksMissingImageDataUnavailable() {
        let photo = GroomingRequestPhoto(
            id: UUID(),
            requestID: UUID(),
            customerID: UUID(),
            storageBucket: PhotoStorageBucketID.groomingRequest.rawValue,
            storagePath: "customer/request/before.png",
            caption: "Before bath",
            sortOrder: 0,
            createdAt: nil
        )

        let unavailable = CustomerRequestPhotoRowPresentation(
            photo: photo,
            data: nil
        )
        let available = CustomerRequestPhotoRowPresentation(
            photo: photo,
            data: Data([0x11])
        )

        #expect(unavailable.title == "Before bath")
        #expect(unavailable.detail == "Photo unavailable")
        #expect(available.title == "Before bath")
        #expect(available.detail == "before.png")
    }

    @Test @MainActor
    func publishTrimsDraftCallsRepositoryAndReloadsRequests() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            createResult: .success(
                GroomingRequestPublishResult(
                    requestID: request.id,
                    matchCount: 2
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .fullGroom
        store.serviceNotes = "   "
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.streetAddress = " 123 Pine Street "
        store.city = " Seattle "
        store.stateCode = .washington
        store.zipCode = " 98101 "

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.requestsCallCount == 2)
        #expect(requestRepository.lastCustomerID == customerID)
        #expect(requestRepository.lastDraft?.petID == pet.id)
        #expect(requestRepository.lastDraft?.serviceType == .fullGroom)
        #expect(requestRepository.lastDraft?.serviceNotes == nil)
        #expect(requestRepository.lastDraft?.streetAddress == "123 Pine Street")
        #expect(requestRepository.lastDraft?.city == "Seattle")
        #expect(requestRepository.lastDraft?.stateCode == .washington)
        #expect(requestRepository.lastDraft?.zipCode == "98101")
        #expect(store.isShowingWizard == false)
        #expect(store.noticeMessage == "Request published. 2 groomers matched.")
        #expect(store.publishResult?.matchCount == 2)
    }

    @Test @MainActor
    func publishPersistsFixedServiceLocationAddressAndTravelRange() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestID = UUID()
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .success(
                GroomingRequestPublishResult(
                    requestID: requestID,
                    matchCount: 1
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .bathAndBrush
        store.serviceNotes = " Use hypoallergenic shampoo. "
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.locationMode = .customerComesToGroomer
        store.streetAddress = " 123 Pine St "
        store.city = " Seattle "
        store.stateCode = .washington
        store.zipCode = " 98101 "
        store.travelRadiusMiles = 42

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.lastDraft?.serviceType == .bathAndBrush)
        #expect(requestRepository.lastDraft?.serviceNotes == "Use hypoallergenic shampoo.")
        #expect(requestRepository.lastDraft?.locationMode == .customerComesToGroomer)
        #expect(requestRepository.lastDraft?.streetAddress == "123 Pine St")
        #expect(requestRepository.lastDraft?.city == "Seattle")
        #expect(requestRepository.lastDraft?.stateCode == .washington)
        #expect(requestRepository.lastDraft?.zipCode == "98101")
        #expect(requestRepository.lastDraft?.travelRadiusMiles == 42)
    }

    @Test @MainActor
    func publishMobileRequestOmitsTravelRangeAndRequiresValidUSAddress() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestRepository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.locationMode = .groomerComesToCustomer
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"
        store.travelRadiusMiles = 88

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.lastDraft?.travelRadiusMiles == nil)

        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.locationMode = .groomerComesToCustomer
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "9810"

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.errorMessage == "Enter a valid 5-digit ZIP code.")

        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.locationMode = .groomerComesToCustomer
        store.streetAddress = "Pine Street"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.errorMessage == "Enter a street address with a street number and name.")
    }

    @Test @MainActor
    func publishUploadsSelectedRequestPhotosAfterRequestCreation() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestID = UUID()
        let uploadedPhoto = GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: "customer/request/photo.jpg",
            caption: nil,
            sortOrder: 0,
            createdAt: "2026-06-22T20:00:00Z"
        )
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .success(
                GroomingRequestPublishResult(
                    requestID: requestID,
                    matchCount: 0
                )
            ),
            uploadRequestPhotoResult: .success(uploadedPhoto)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.locationMode = .groomerComesToCustomer
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"
        store.addPendingPhoto(data: Data([0x01, 0x02]), contentType: .jpeg)

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.uploadRequestPhotoCallCount == 1)
        #expect(requestRepository.lastUploadRequestID == requestID)
        #expect(requestRepository.lastUploadData == Data([0x01, 0x02]))
        #expect(requestRepository.lastUploadContentType == .jpeg)
        #expect(store.pendingRequestPhotos.isEmpty)
    }

    @Test @MainActor
    func startRepublishFromCancelledRequestPrefillsReviewDraftAndCreatesNewRequest() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let originalRequestID = UUID()
        let newRequestID = UUID()
        let preferredStartValue = GroomingRequestDateFormatting.serverString(
            from: Date().addingTimeInterval(2 * 24 * 60 * 60)
        )
        let preferredEndValue = GroomingRequestDateFormatting.serverString(
            from: try #require(
                GroomingRequestDateFormatting.parsedDate(from: preferredStartValue)
            ).addingTimeInterval(90 * 60)
        )
        let preferredStart = try #require(
            GroomingRequestDateFormatting.parsedDate(from: preferredStartValue)
        )
        let preferredEnd = try #require(
            GroomingRequestDateFormatting.parsedDate(from: preferredEndValue)
        )
        let originalRequest = Self.request(
            id: originalRequestID,
            customerID: customerID,
            petID: pet.id,
            status: .cancelled,
            serviceType: .bathAndBrush,
            serviceNotes: "Use hypoallergenic shampoo.",
            preferredStart: preferredStartValue,
            preferredEnd: preferredEndValue,
            locationMode: .customerComesToGroomer,
            streetAddress: "456 Cedar Ave",
            city: "Bellevue",
            state: "WA",
            zipCode: "98004",
            travelRadiusMiles: 24
        )
        let originalPhoto = GroomingRequestPhoto(
            id: UUID(),
            requestID: originalRequestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: "customer/original/photo.png",
            caption: nil,
            sortOrder: 0,
            createdAt: "2026-06-22T16:00:00Z"
        )
        let copiedPhotoData = Data([1, 2, 3, 4])
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([originalRequest]),
            createResult: .success(
                GroomingRequestPublishResult(
                    requestID: newRequestID,
                    matchCount: 3
                )
            ),
            uploadRequestPhotoResult: .success(
                GroomingRequestPhoto(
                    id: UUID(),
                    requestID: newRequestID,
                    customerID: customerID,
                    storageBucket: "request-photos",
                    storagePath: "customer/new/photo.png",
                    caption: nil,
                    sortOrder: 0,
                    createdAt: nil
                )
            ),
            requestPhotosResult: .success([originalPhoto]),
            requestPhotoDataByID: [originalPhoto.id: copiedPhotoData]
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startRepublish(from: originalRequest, now: Date())

        #expect(store.isShowingWizard)
        #expect(store.wizardInitialStep == .review)
        #expect(store.selectedPetID == pet.id)
        #expect(store.serviceType == .bathAndBrush)
        #expect(store.serviceNotes == "Use hypoallergenic shampoo.")
        #expect(store.preferredStart == preferredStart)
        #expect(store.preferredEnd == preferredEnd)
        #expect(store.locationMode == .customerComesToGroomer)
        #expect(store.streetAddress == "456 Cedar Ave")
        #expect(store.city == "Bellevue")
        #expect(store.stateCode == .washington)
        #expect(store.zipCode == "98004")
        #expect(store.travelRadiusMiles == 24)
        #expect(store.pendingRequestPhotos.map(\.data) == [copiedPhotoData])
        #expect(store.pendingRequestPhotos.map(\.contentType) == [.png])

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.lastDraft?.petID == pet.id)
        #expect(requestRepository.lastDraft?.serviceType == .bathAndBrush)
        #expect(requestRepository.lastDraft?.serviceNotes == "Use hypoallergenic shampoo.")
        #expect(requestRepository.lastDraft?.preferredStart == preferredStart)
        #expect(requestRepository.lastDraft?.preferredEnd == preferredEnd)
        #expect(requestRepository.lastDraft?.locationMode == .customerComesToGroomer)
        #expect(requestRepository.lastDraft?.streetAddress == "456 Cedar Ave")
        #expect(requestRepository.lastDraft?.city == "Bellevue")
        #expect(requestRepository.lastDraft?.stateCode == .washington)
        #expect(requestRepository.lastDraft?.zipCode == "98004")
        #expect(requestRepository.lastDraft?.travelRadiusMiles == 24)
        #expect(requestRepository.uploadRequestPhotoCallCount == 1)
        #expect(requestRepository.lastUploadRequestID == newRequestID)
        #expect(requestRepository.lastUploadRequestID != originalRequestID)
        #expect(requestRepository.lastUploadData == copiedPhotoData)
        #expect(requestRepository.lastUploadContentType == .png)
        #expect(store.isShowingWizard == false)
        #expect(store.noticeMessage == "Request published. 3 groomers matched.")
    }

    @Test @MainActor
    func startRepublishFromCancelledBookingUsesMatchingOriginalRequest() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let originalRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked,
            serviceType: .nailTrim,
            serviceNotes: "Keep nails short."
        )
        let cancelledBooking = Self.booking(
            requestID: originalRequest.id,
            customerID: customerID,
            status: .cancelledByCustomer
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([originalRequest])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        let didStart = store.startRepublish(
            from: cancelledBooking,
            originalRequest: store.request(withID: cancelledBooking.requestID),
            now: Date()
        )

        #expect(didStart)
        #expect(store.isShowingWizard)
        #expect(store.wizardInitialStep == .review)
        #expect(store.selectedPetID == pet.id)
        #expect(store.serviceType == .nailTrim)
        #expect(store.serviceNotes == "Keep nails short.")
    }

    @Test @MainActor
    func oversizedRequestPhotoIsRejectedBeforePublish() async throws {
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        store.addPendingPhoto(
            data: Data(count: CustomerRequestsStore.maximumRequestPhotoBytes + 1),
            contentType: .jpeg
        )

        #expect(store.pendingRequestPhotos.isEmpty)
        #expect(store.errorMessage == "Choose a request photo smaller than 10 MB.")
    }

    @Test @MainActor
    func invalidFormDoesNotCallRepository() async {
        let repository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.publish()

        #expect(repository.createCallCount == 0)
        #expect(store.errorMessage == "Add a pet before creating a request.")
    }

    @Test @MainActor
    func nearFutureStartTimeDoesNotCallRepository() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let repository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .bathAndBrush
        store.preferredStart = Date().addingTimeInterval(60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.streetAddress = "123 Pine Street"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"

        await store.publish()

        #expect(repository.createCallCount == 0)
        #expect(
            store.errorMessage ==
                "Preferred start must be at least 5 minutes from now."
        )
    }

    @Test @MainActor
    func publishFailurePreservesWizardInput() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let petRepository = CustomerRequestPetRepositoryFake(
            petsResult: .success([pet])
        )
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .failure(.requestLimitExceeded)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: petRepository,
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.serviceType = .bathAndBrush
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.streetAddress = "123 Pine Street"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.isShowingWizard)
        #expect(store.serviceType == .bathAndBrush)
        #expect(store.errorMessage == "You can have at most 3 open grooming requests.")
    }

    @Test @MainActor
    func cancelOpenRequestCallsRepositoryAndUpdatesLocalState() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            cancelResult: .success(
                CancelGroomingRequestResult(
                    requestID: request.id,
                    requestStatus: .cancelled,
                    cancelledTimestamp: "2026-06-22T14:00:00Z"
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        await store.cancel(request)

        #expect(requestRepository.cancelCallCount == 1)
        #expect(requestRepository.lastCancelRequestID == request.id)
        #expect(store.requests.first?.status == .cancelled)
        #expect(store.noticeMessage == "Request cancelled.")
    }

    @Test @MainActor
    func cancelBookedRequestDoesNotCallRepository() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        await store.cancel(request)

        #expect(requestRepository.cancelCallCount == 0)
        #expect(store.requests.first?.status == .booked)
        #expect(store.errorMessage == "This request can no longer be cancelled.")
    }

    @Test @MainActor
    func activeRequestsIncludeOnlyOpenAndOfferStates() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let openRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .hasOffers
        )
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled
        )
        let expiredRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .expired
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    openRequest,
                    offerRequest,
                    bookedRequest,
                    cancelledRequest,
                    expiredRequest,
                ])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(store.activeRequests.map(\.id) == [
            openRequest.id,
            offerRequest.id,
        ])
    }

    @Test @MainActor
    func bookedRequestWithConfirmedBookingCreatesSessionHandoff() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([booking])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: bookingRepository
        )

        await store.load()

        #expect(bookingRepository.bookingsCallCount == 1)
        #expect(bookingRepository.lastBookingsParticipantID == customerID)
        #expect(bookingRepository.lastBookingsRole == .customer)
        #expect(store.activeRequests.isEmpty)
        #expect(store.bookingHandoffs.map(\.request.id) == [bookedRequest.id])
        #expect(store.bookingHandoffs.first?.booking.id == booking.id)

        await store.acknowledgeBookingHandoff(for: store.bookingHandoffs[0])

        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.requests.first?.status == .booked)
    }

    @Test @MainActor
    func bookingHandoffLoadFailureDoesNotSurfaceAsRequestUpdateError() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .failure(.unavailable)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: bookingRepository
        )

        await store.load()

        #expect(bookingRepository.bookingsCallCount == 1)
        #expect(store.requests == [bookedRequest])
        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func acknowledgedBookingHandoffPersistsAcrossStoreReloads() async throws {
        let customerID = UUID()
        let suiteName = "CustomerRequestsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let firstStore = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )

        await firstStore.load()
        let handoff = try #require(firstStore.bookingHandoffs.first)
        await firstStore.acknowledgeBookingHandoff(for: handoff)

        let secondStore = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([bookedRequest])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )

        await secondStore.load()

        #expect(secondStore.bookingHandoffs.isEmpty)
        #expect(secondStore.acknowledgedBookingHandoffRequestIDs.contains(bookedRequest.id))
    }

    @Test @MainActor
    func bookingHandoffLoadMergesRemoteAcknowledgementsWithLocalFallback() async throws {
        let customerID = UUID()
        let suiteName = "CustomerRequestsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let pet = Self.pet(customerID: customerID)
        let remoteAcknowledgedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let localAcknowledgedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let visibleRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        defaults.set(
            [localAcknowledgedRequest.id.uuidString],
            forKey: "groomly.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([
                remoteAcknowledgedRequest,
                localAcknowledgedRequest,
                visibleRequest,
            ]),
            acknowledgedBookingHandoffRequestIDsResult: .success([remoteAcknowledgedRequest.id])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([
                Self.booking(requestID: remoteAcknowledgedRequest.id, customerID: customerID, status: .confirmed),
                Self.booking(requestID: localAcknowledgedRequest.id, customerID: customerID, status: .confirmed),
                Self.booking(requestID: visibleRequest.id, customerID: customerID, status: .confirmed),
            ])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: bookingRepository,
            handoffAcknowledgementDefaults: defaults
        )

        await store.load()

        #expect(requestRepository.acknowledgedBookingHandoffRequestIDsCallCount == 1)
        #expect(requestRepository.lastAcknowledgedBookingHandoffCustomerID == customerID)
        #expect(store.acknowledgedBookingHandoffRequestIDs == [
            remoteAcknowledgedRequest.id,
            localAcknowledgedRequest.id,
        ])
        #expect(store.bookingHandoffs.map(\.request.id) == [visibleRequest.id])
    }

    @Test @MainActor
    func acknowledgeBookingHandoffKeepsLocalFallbackWhenRemoteWriteFails() async throws {
        let customerID = UUID()
        let suiteName = "CustomerRequestsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([bookedRequest]),
            acknowledgeBookingHandoffResult: .failure(.networkUnavailable)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([booking])
            ),
            handoffAcknowledgementDefaults: defaults
        )
        await store.load()
        let handoff = try #require(store.bookingHandoffs.first)

        await store.acknowledgeBookingHandoff(for: handoff)

        #expect(requestRepository.acknowledgeBookingHandoffCallCount == 1)
        #expect(requestRepository.lastAcknowledgedBookingHandoffRequestID == bookedRequest.id)
        #expect(requestRepository.lastAcknowledgedBookingHandoffBookingID == booking.id)
        #expect(store.bookingHandoffs.isEmpty)
        #expect(store.acknowledgedBookingHandoffRequestIDs.contains(bookedRequest.id))
        #expect(
            defaults.stringArray(
                forKey: "groomly.customerRequests.bookingHandoffAcknowledgements.\(customerID.uuidString)"
            ) == [bookedRequest.id.uuidString]
        )
    }

    @Test @MainActor
    func bookedRequestHandoffsRequireConfirmedBooking() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let completedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            bookingsResult: .success([
                Self.booking(
                    requestID: completedRequest.id,
                    customerID: customerID,
                    status: .completed
                ),
                Self.booking(
                    requestID: cancelledRequest.id,
                    customerID: customerID,
                    status: .cancelledByCustomer
                ),
            ])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    completedRequest,
                    cancelledRequest,
                ])
            ),
            bookingRepository: bookingRepository
        )

        await store.load()

        #expect(store.activeRequests.isEmpty)
        #expect(store.bookingHandoffs.isEmpty)
    }

    @Test @MainActor
    func visibleActionCardsMirrorRequestsDashboardFilteringForHome() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let openRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .hasOffers
        )
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled
        )
        let expiredRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .expired
        )
        let confirmedBooking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([
                    openRequest,
                    offerRequest,
                    bookedRequest,
                    cancelledRequest,
                    expiredRequest,
                ])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([confirmedBooking])
            )
        )

        await store.load()

        #expect(store.visibleActionCards.map(\.request.id) == [
            openRequest.id,
            offerRequest.id,
            bookedRequest.id,
        ])
        #expect(store.visibleActionCards.first?.handoff == nil)
        #expect(store.visibleActionCards.last?.handoff?.booking.id == confirmedBooking.id)

        let handoff = try #require(store.visibleActionCards.last?.handoff)
        await store.acknowledgeBookingHandoff(for: handoff)

        #expect(store.visibleActionCards.map(\.request.id) == [
            openRequest.id,
            offerRequest.id,
        ])
    }

    @Test @MainActor
    func homeRequestHeroStaysEnabledWhileRequestsReloadWhenPetsExist() {
        let loadingWithPet = CustomerHomeRequestHeroPresentation(
            hasPets: true,
            isRequestStoreBusy: true
        )
        let emptyPets = CustomerHomeRequestHeroPresentation(
            hasPets: false,
            isRequestStoreBusy: false
        )

        #expect(loadingWithPet.isStartRequestDisabled == false)
        #expect(emptyPets.isStartRequestDisabled == true)
    }

    @Test @MainActor
    func homeActiveRequestPresentationUsesAllCardsAndNeverShowsLoadingCard() {
        let customerID = UUID()
        let openRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let offerRequest = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .hasOffers
        )
        let cards = [
            CustomerRequestActionCardItem(request: openRequest, handoff: nil),
            CustomerRequestActionCardItem(request: offerRequest, handoff: nil),
        ]
        let populated = CustomerHomeActiveRequestPresentation(
            cards: cards,
            isLoading: true
        )
        let emptyLoading = CustomerHomeActiveRequestPresentation(
            cards: [],
            isLoading: true
        )

        #expect(populated.cards == cards)
        #expect(populated.shouldShowCarousel == true)
        #expect(populated.shouldShowEmptyText == false)
        #expect(populated.shouldShowLoadingCard == false)
        #expect(emptyLoading.cards.isEmpty)
        #expect(emptyLoading.shouldShowCarousel == false)
        #expect(emptyLoading.shouldShowEmptyText == true)
        #expect(emptyLoading.shouldShowLoadingCard == false)
    }

    @Test @MainActor
    func homeNextBookingPresentationUsesInlineEmptyTextInsteadOfCard() {
        let booking = Self.booking(
            requestID: UUID(),
            customerID: UUID()
        )
        let populated = CustomerHomeNextBookingPresentation(
            booking: booking,
            isLoading: false
        )
        let emptyLoading = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: true
        )
        let emptyLoaded = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: false
        )

        #expect(populated.shouldShowBooking == true)
        #expect(populated.shouldShowLoading == false)
        #expect(populated.shouldShowEmptyText == false)
        #expect(populated.shouldShowEmptyCard == false)
        #expect(emptyLoading.shouldShowBooking == false)
        #expect(emptyLoading.shouldShowLoading == false)
        #expect(emptyLoading.shouldShowEmptyText == true)
        #expect(emptyLoading.shouldShowEmptyCard == false)
        #expect(emptyLoaded.shouldShowBooking == false)
        #expect(emptyLoaded.shouldShowLoading == false)
        #expect(emptyLoaded.shouldShowEmptyText == true)
        #expect(emptyLoaded.shouldShowEmptyCard == false)
    }

    @Test @MainActor
    func homeNextBookingLoadFailureDoesNotCreateGlobalPrompt() {
        let presentation = CustomerHomeNextBookingPresentation(
            booking: nil,
            isLoading: false,
            loadErrorMessage: "We could not load bookings. Please try again."
        )

        #expect(presentation.shouldShowLoadError == false)
        #expect(presentation.shouldShowEmptyText == true)
        #expect(presentation.globalErrorPrompt == nil)
    }

    @Test @MainActor
    func requestEmptyCopyIsSharedByHomeAndRequests() {
        #expect(CustomerRequestEmptyCopy.title == "No Active Request")
        #expect(
            CustomerRequestEmptyCopy.message ==
                "Open quests and newly confirmed booking handoffs will appear here."
        )
    }

    @Test @MainActor
    func requestWizardStepsMatchPrototypeProgression() {
        #expect(CustomerRequestWizardStep.allCases.map(\.title) == [
            "Pet",
            "Service",
            "Time & Location",
            "Details",
            "Review",
        ])
        #expect(CustomerRequestWizardStep.pet.progress == 0.2)
        #expect(CustomerRequestWizardStep.review.progress == 1)
    }

    @Test @MainActor
    func requestWizardProgressLabelsUseProgressTrackWidth() {
        let layout = CustomerRequestWizardProgressLayout(
            backButtonWidth: 54,
            horizontalSpacing: 16
        )

        #expect(layout.progressTrackLeadingOffset == 70)
        #expect(layout.shouldLabelRowShareProgressTrackWidth == true)
    }

    @Test @MainActor
    func requestWizardServiceOptionsMapToExistingServiceTypeField() {
        #expect(CustomerRequestServiceOption.allCases.count == 6)
        #expect(CustomerRequestServiceOption.fullGroom.title == "Full Groom")
        #expect(CustomerRequestServiceOption.fullGroom.rawValue == "full_groom")
        #expect(CustomerRequestServiceOption.bathAndBrush.rawValue == "bath_and_brush")
        #expect(CustomerRequestServiceOption.customRequest.subtitle == "Describe exactly what you need")
    }

    @Test @MainActor
    func requestWizardTimeWindowsApplyPresetRangesToSelectedDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let morning = try #require(
            CustomerRequestTimeWindowOption.morning.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let afternoon = try #require(
            CustomerRequestTimeWindowOption.afternoon.range(
                on: selectedDate,
                calendar: calendar
            )
        )
        let evening = try #require(
            CustomerRequestTimeWindowOption.evening.range(
                on: selectedDate,
                calendar: calendar
            )
        )

        #expect(Self.hourMinute(morning.start, calendar: calendar) == [6, 0])
        #expect(Self.hourMinute(morning.end, calendar: calendar) == [11, 59])
        #expect(Self.hourMinute(afternoon.start, calendar: calendar) == [12, 0])
        #expect(Self.hourMinute(afternoon.end, calendar: calendar) == [16, 59])
        #expect(Self.hourMinute(evening.start, calendar: calendar) == [17, 0])
        #expect(Self.hourMinute(evening.end, calendar: calendar) == [21, 0])
        #expect(
            CustomerRequestTimeWindowOption.detailed.range(
                on: selectedDate,
                calendar: calendar
            ) == nil
        )
    }

    @Test @MainActor
    func requestWizardFlexibleTimeUsesAllDayWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let selectedDate = try #require(Self.isoDate("2026-06-19T12:00:00Z"))

        let flexible = CustomerRequestTimeWindowOption.flexibleRange(
            on: selectedDate,
            calendar: calendar
        )

        #expect(Self.hourMinute(flexible.start, calendar: calendar) == [0, 0])
        #expect(Self.hourMinute(flexible.end, calendar: calendar) == [23, 59])
    }

    @Test @MainActor
    func requestMatchingCopyExplainsPreferredTimeAsFlexible() {
        #expect(
            CustomerRequestMatchingCopy.customerReviewInfo ==
                "Your preferred time helps us find groomers with availability on that day. Groomers will send offers with a real appointment time for you to review."
        )
        #expect(
            CustomerRequestMatchingCopy.groomerOfferGuidance ==
                "Start from the customer's preferred window, then choose a time that is actually available on your schedule."
        )
    }

    @Test @MainActor
    func requestWizardTravelRangeClampsToSupportedMiles() {
        #expect(CustomerRequestTravelRange.clampedMiles(3) == 5)
        #expect(CustomerRequestTravelRange.clampedMiles(42) == 42)
        #expect(CustomerRequestTravelRange.clampedMiles(120) == 100)
    }

    @Test @MainActor
    func requestWizardReviewSummaryUsesCurrentRequestFields() {
        let summary = CustomerRequestWizardReviewPresentation(
            pet: "Mochi · Toy Poodle",
            service: "Full Groom",
            preferredTime: "Fri 19 · Afternoon",
            location: "Mobile · Seattle, WA 98101",
            notes: "Mochi needs a teddy-style trim."
        )

        #expect(summary.rows.map(\.title) == [
            "Pet",
            "Service",
            "Preferred Time",
            "Location",
            "Notes",
        ])
        #expect(summary.rows.map(\.value) == [
            "Mochi · Toy Poodle",
            "Full Groom",
            "Fri 19 · Afternoon",
            "Mobile · Seattle, WA 98101",
            "Mochi needs a teddy-style trim.",
        ])
    }

    @Test @MainActor
    func requestWizardFitInputPreviewDerivesSignalsFromSelectedPetAndService() async throws {
        let customerID = UUID()
        let pet = CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: "Toy Poodle",
            coatType: nil,
            size: "S",
            weightLbs: 15,
            birthday: nil,
            temperament: "Gentle",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()
        store.startCreate()
        store.serviceType = .fullGroom

        #expect(store.requestFitInputSignals().map(\.id) == [
            "coat_type:curly_wavy",
            "breed_group:poodle",
            "size_band:S",
            "service_fit:curly_coat",
            "service_fit:full_haircut_styling",
        ])
    }

    @Test @MainActor
    func requestWizardFitInputPresentationUsesReadableReviewLabels() {
        let presentation = CustomerRequestWizardFitInputPresentation(
            signals: [
                .breedGroup(.poodle),
                .sizeBand(.s),
                .serviceFit(.curlyCoat),
            ]
        )

        #expect(presentation.chips.map(\.label) == [
            "Breed",
            "Pet Size",
            "Service Fit",
        ])
        #expect(presentation.chips.map(\.title) == [
            "Poodle",
            "S",
            "Curly Coat",
        ])
    }

    @Test @MainActor
    func requestWizardTimeStepRequiresCompleteAddressBeforeContinuing() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()
        store.startCreate()
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.streetAddress = "760"
        store.city = ""
        store.stateCode = nil
        store.zipCode = ""

        let validation = store.validateWizardStep(.time)

        #expect(validation.isValid == false)
        #expect(validation.message == "Complete the highlighted required fields before continuing.")
        #expect(validation.fields == [
            .streetAddress,
            .city,
            .state,
            .zipCode,
        ])
    }

    @Test @MainActor
    func sharedAddressSuggestionsDeduplicateRepeatedMapResults() {
        let result = GroomlyAddressSuggestionBuilder.build(
            from: [
                GroomlyAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "first"
                ),
                GroomlyAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "duplicate"
                ),
                GroomlyAddressCompletion(
                    title: "760 2nd Street",
                    subtitle: "San Francisco, CA",
                    completion: "second"
                ),
            ]
        )

        #expect(result.suggestions.map(\.title) == [
            "760 Market Street",
            "760 2nd Street",
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "first")
        #expect(result.completionsByID[result.suggestions[1].id] == "second")
    }

    @Test @MainActor
    func profileAddressAutofillRequiresCompleteTrimmedAddress() {
        let customerID = UUID()
        let completeProfile = CustomerProfileDetails(
            userID: customerID,
            nickname: "Prinny",
            avatarPath: nil,
            streetAddress: " 123 Pine Street ",
            city: " Seattle ",
            stateCode: .washington,
            zipCode: " 98101 ",
            contactEmail: nil,
            phoneNumber: nil
        )

        #expect(CustomerProfileAddressAutofill.make(from: completeProfile) == CustomerProfileAddressAutofill(
            streetAddress: "123 Pine Street",
            city: "Seattle",
            stateCode: .washington,
            zipCode: "98101"
        ))

        let incompleteProfile = CustomerProfileDetails(
            userID: customerID,
            nickname: "Prinny",
            avatarPath: nil,
            streetAddress: "123 Pine Street",
            city: "",
            stateCode: .washington,
            zipCode: "98101",
            contactEmail: nil,
            phoneNumber: nil
        )

        #expect(CustomerProfileAddressAutofill.make(from: incompleteProfile) == nil)
    }

    @Test @MainActor
    func requestWizardAddressSuggestionsDeduplicateRepeatedMapResults() {
        let result = CustomerRequestAddressSuggestionBuilder.build(
            from: [
                CustomerRequestAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "first"
                ),
                CustomerRequestAddressCompletion(
                    title: "760 Market Street",
                    subtitle: "San Francisco, CA",
                    completion: "duplicate"
                ),
                CustomerRequestAddressCompletion(
                    title: "760 2nd Street",
                    subtitle: "San Francisco, CA",
                    completion: "second"
                ),
            ]
        )

        #expect(result.suggestions.map(\.title) == [
            "760 Market Street",
            "760 2nd Street",
        ])
        #expect(result.completionsByID[result.suggestions[0].id] == "first")
        #expect(result.completionsByID[result.suggestions[1].id] == "second")
    }

    @Test @MainActor
    func bookedHandoffCardPresentationKeepsQuestSummaryAndAddsAddress() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let bookedRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .booked
        )
        let booking = Self.booking(
            requestID: bookedRequest.id,
            customerID: customerID,
            status: .confirmed
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: bookedRequest,
            handoff: CustomerRequestBookingHandoff(
                request: bookedRequest,
                booking: booking
            )
        )

        #expect(presentation.headline == "Booking\nConfirmed")
        #expect(presentation.subtitle == "Full Groom for Mochi")
        #expect(presentation.infoLines == [
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "calendar",
                text: Self.compactDisplayRange(
                    from: booking.scheduledStart,
                    to: booking.scheduledEnd
                )
            ),
            CustomerRequestProgressCardPresentation.InfoLine(
                systemImage: "mappin.and.ellipse",
                text: "Seattle, WA 98101"
            ),
        ])
    }

    @Test @MainActor
    func openRequestCardPresentationUsesTitleCaseHeadlineAndCompactTimeRange() async throws {
        let customerID = UUID()
        let request = Self.request(
            customerID: customerID,
            petID: UUID(),
            status: .open
        )
        let presentation = CustomerRequestProgressCardPresentation(
            request: request,
            handoff: nil
        )

        #expect(presentation.headline == "Open\nRequest")
        #expect(presentation.infoLines.first == CustomerRequestProgressCardPresentation.InfoLine(
            systemImage: "calendar",
            text: Self.compactDisplayRange(
                from: request.preferredStart,
                to: request.preferredEnd
            )
        ))
        #expect(presentation.infoLines.first?.text.contains("2026") == false)
        #expect(presentation.infoLines.first?.text.contains("\n") == false)
    }

    @Test @MainActor
    func clearNoticeOnlyDismissesMatchingMessage() async throws {
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        store.noticeMessage = "Request cancelled."
        store.clearNotice(ifCurrent: "Offer accepted. Booking confirmed.")
        #expect(store.noticeMessage == "Request cancelled.")

        store.clearNotice(ifCurrent: "Request cancelled.")
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func loadOffersPopulatesOfferReviewsForRequest() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let repository = CustomerRequestRepositoryFake(
            offersResult: .success([offerReview])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(repository.offersCallCount == 1)
        #expect(repository.lastOfferCustomerID == customerID)
        #expect(repository.lastOfferRequestID == request.id)
        #expect(store.offers(for: request) == [offerReview])
        #expect(store.offerError(for: request) == nil)
    }

    @Test @MainActor
    func loadOffersOrdersPendingBeforeHistoricalOffers() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let withdrawnOffer = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            status: .withdrawnByGroomer,
            createdAt: "2026-06-20T14:00:00Z"
        )
        let pendingOffer = Self.offerReview(
            customerID: customerID,
            requestID: request.id,
            status: .pending,
            createdAt: "2026-06-20T13:00:00Z"
        )
        let repository = CustomerRequestRepositoryFake(
            offersResult: .success([withdrawnOffer, pendingOffer])
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(store.offers(for: request).map(\.offer.status) == [
            .pending,
            .withdrawnByGroomer,
        ])
    }

    @Test @MainActor
    func offerReviewFitEvidencePresentationUsesExplanationFirstCopyWithoutRawScore() {
        let offerReview = Self.offerReview(
            customerID: UUID(),
            requestID: UUID(),
            matchScore: 94.4,
            matchReason: """
            Same city and service location. Pet-fit evidence: completed poodle coats.
            """
        )

        let presentation = offerReview.fitEvidencePresentation

        #expect(presentation?.scoreText == nil)
        #expect(
            presentation?.reason
                == "Same city and service location. Pet-fit evidence: completed poodle coats."
        )
        #expect(
            presentation?.listSummary
                == "Location And Service Fit: Same city and service location. Earned Evidence: completed poodle coats."
        )
    }

    @Test @MainActor
    func offerReviewFitEvidencePresentationIgnoresBlankReason() {
        let offerReview = Self.offerReview(
            customerID: UUID(),
            requestID: UUID(),
            matchScore: 91,
            matchReason: "   \n  "
        )

        #expect(offerReview.fitEvidencePresentation == nil)
    }

    @Test @MainActor
    func loadOffersFailureIsScopedToRequest() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let repository = CustomerRequestRepositoryFake(
            offersResult: .failure(.networkUnavailable)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository,
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.loadOffers(for: request)

        #expect(repository.offersCallCount == 1)
        #expect(store.offers(for: request).isEmpty)
        #expect(store.offerError(for: request) == "Check your connection and try again.")
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func acceptOfferCallsBookingRPCAndRefreshesRequestAndOffers() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
        let acceptedOfferID = UUID()
        let competingOfferID = UUID()
        let acceptedPending = Self.offerReview(
            offerID: acceptedOfferID,
            customerID: customerID,
            requestID: request.id
        )
        let competingPending = Self.offerReview(
            offerID: competingOfferID,
            customerID: customerID,
            requestID: request.id
        )
        let acceptedFinal = Self.offerReview(
            offerID: acceptedOfferID,
            customerID: customerID,
            requestID: request.id,
            status: .acceptedByCustomer
        )
        let competingFinal = Self.offerReview(
            offerID: competingOfferID,
            customerID: customerID,
            requestID: request.id,
            status: .declinedByCustomer
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            offersResult: .success([acceptedPending, competingPending])
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: UUID(),
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: acceptedOfferID,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: requestRepository,
            bookingRepository: bookingRepository
        )
        await store.load()
        await store.loadOffers(for: request)

        requestRepository.requestsResult = .success([
            request.replacing(status: .booked),
        ])
        requestRepository.offersResult = .success([
            acceptedFinal,
            competingFinal,
        ])

        await store.accept(offerReview: acceptedPending, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(bookingRepository.lastAcceptedOfferID == acceptedOfferID)
        #expect(requestRepository.requestsCallCount == 2)
        #expect(requestRepository.offersCallCount == 2)
        #expect(store.request(withID: request.id)?.status == .booked)
        let statusesByOfferID = Dictionary(
            uniqueKeysWithValues: store.offers(for: request).map {
                ($0.offer.id, $0.offer.status)
            }
        )
        #expect(statusesByOfferID[acceptedOfferID] == .acceptedByCustomer)
        #expect(statusesByOfferID[competingOfferID] == .declinedByCustomer)
        #expect(store.noticeMessage == "Offer accepted. Booking confirmed.")
    }

    @Test @MainActor
    func acceptOfferConflictExplainsNoLocalBooking() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .failure(.bookingConflict)
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: bookingRepository
        )

        await store.accept(offerReview: offerReview, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(
            store.errorMessage ==
                "That groomer is no longer available at the proposed time."
        )
        #expect(store.noticeMessage == nil)
    }

    @Test @MainActor
    func acceptOfferWithMissingLocalStateReportsRefreshHint() async throws {
        let customerID = UUID()
        let request = Self.request(customerID: customerID, petID: UUID())
        let offerReview = Self.offerReview(
            customerID: customerID,
            requestID: request.id
        )
        let bookingRepository = CustomerRequestBookingRepositoryFake(
            acceptResult: .success(
                AcceptGroomerOfferResult(
                    bookingID: UUID(),
                    conversationID: UUID(),
                    requestID: request.id,
                    offerID: offerReview.offer.id,
                    bookingStatus: .confirmed,
                    offerStatus: .acceptedByCustomer,
                    requestStatus: .booked
                )
            )
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: bookingRepository
        )

        await store.accept(offerReview: offerReview, for: request)

        #expect(bookingRepository.acceptCallCount == 1)
        #expect(
            store.noticeMessage ==
                "Offer accepted. Booking confirmed. Refresh this request if the offer state does not update."
        )
    }

    private static func pet(customerID: UUID) -> CustomerPet {
        CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: "Corgi",
            coatType: nil,
            size: "M",
            weightLbs: 22,
            birthday: nil,
            temperament: "Gentle",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
    }

    private static func request(
        id: UUID = UUID(),
        customerID: UUID,
        petID: UUID,
        status: GroomingRequestStatus = .open,
        serviceType: GroomingServiceType = .fullGroom,
        serviceNotes: String? = nil,
        preferredStart: String = "2026-06-22T16:00:00Z",
        preferredEnd: String = "2026-06-22T18:00:00Z",
        locationMode: GroomingLocationMode = .groomerComesToCustomer,
        streetAddress: String = "123 Pine Street",
        city: String = "Seattle",
        state: String = "WA",
        zipCode: String = "98101",
        travelRadiusMiles: Int? = nil
    ) -> CustomerGroomingRequest {
        CustomerGroomingRequest(
            id: id,
            customerID: customerID,
            petID: petID,
            petSnapshot: GroomingRequestPetSnapshot(
                id: petID,
                name: "Mochi",
                species: "Dog",
                breed: "Corgi",
                coatType: nil,
                size: "M",
                weightLbs: 22,
                birthday: nil,
                temperament: "Gentle",
                medicalNotes: nil,
                groomingNotes: nil,
                snapshotAt: "2026-06-20T12:00:00Z"
            ),
            photoSnapshot: [],
            serviceType: serviceType,
            serviceNotes: serviceNotes,
            preferredStart: preferredStart,
            preferredEnd: preferredEnd,
            locationMode: locationMode,
            streetAddress: streetAddress,
            city: city,
            state: state,
            zipCode: zipCode,
            travelRadiusMiles: travelRadiusMiles,
            status: status,
            expiresAt: "2026-06-22T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )
    }

    private static func compactDisplayRange(from start: String, to end: String) -> String {
        "\(compactDisplayString(from: start)) - \(compactDisplayString(from: end))"
    }

    private static func compactDisplayString(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func hourMinute(_ date: Date, calendar: Calendar) -> [Int] {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return [
            components.hour ?? -1,
            components.minute ?? -1,
        ]
    }

    private static func offerReview(
        offerID: UUID = UUID(),
        customerID: UUID,
        requestID: UUID,
        status: GroomerOfferStatus = .pending,
        createdAt: String = "2026-06-20T13:00:00Z",
        matchScore: Double? = nil,
        matchReason: String? = nil
    ) -> CustomerOfferReview {
        let groomerID = UUID()
        return CustomerOfferReview(
            offer: GroomerOffer(
                id: offerID,
                requestID: requestID,
                matchID: UUID(),
                customerID: customerID,
                groomerID: groomerID,
                proposedStart: "2026-06-22T16:30:00Z",
                proposedEnd: "2026-06-22T18:30:00Z",
                priceEstimate: 125,
                message: "I can help.",
                status: status,
                expiresAt: "2026-06-22T12:00:00Z",
                withdrawnAt: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            groomerProfile: GroomerProfile(
                userID: groomerID,
                businessName: "Fresh Paws Grooming",
                bio: "Gentle grooming.",
                yearsExperience: 5,
                baseCity: "Seattle",
                baseState: "WA",
                serviceRadiusMiles: 12,
                serviceLocationMode: .groomerComesToCustomer,
                ratingAverage: 4.8,
                ratingCount: 18,
                isActive: true,
                isVerified: true
            ),
            matchScore: matchScore,
            matchReason: matchReason
        )
    }

    private static func booking(
        requestID: UUID,
        customerID: UUID,
        status: BookingStatus = .confirmed
    ) -> Booking {
        Booking(
            id: UUID(),
            requestID: requestID,
            offerID: UUID(),
            customerID: customerID,
            groomerID: UUID(),
            scheduledStart: "2026-06-24T16:00:00Z",
            scheduledEnd: "2026-06-24T18:00:00Z",
            priceEstimate: 128,
            status: status,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-06-22T16:00:00Z",
            updatedAt: "2026-06-22T16:00:00Z",
            review: nil
        )
    }

    private static func petPhoto(
        customerID: UUID,
        petID: UUID,
        sortOrder: Int = 0,
        isPrimary: Bool = true
    ) -> CustomerPetPhoto {
        CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: PhotoStorageBucketID.customerPet.rawValue,
            storagePath: "\(customerID.uuidString.lowercased())/\(petID.uuidString.lowercased())/avatar.jpg",
            caption: nil,
            sortOrder: sortOrder,
            isPrimary: isPrimary
        )
    }
}

@MainActor
private final class CustomerRequestPetRepositoryFake: CustomerPetRepository {
    var petsResult: Result<[CustomerPet], CustomerPetRepositoryError>
    var photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError>
    var photoDataResultsByPhotoID: [UUID: Result<Data, CustomerPetRepositoryError>]
    private(set) var photosCallCount = 0
    private(set) var photoDataCallCount = 0

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([]),
        photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError> = .success([]),
        photoDataResultsByPhotoID: [UUID: Result<Data, CustomerPetRepositoryError>] = [:]
    ) {
        self.petsResult = petsResult
        self.photosResult = photosResult
        self.photoDataResultsByPhotoID = photoDataResultsByPhotoID
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        photosCallCount += 1
        return try photosResult.get()
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        throw CustomerPetRepositoryError.unavailable
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        throw CustomerPetRepositoryError.unavailable
    }

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        throw CustomerPetRepositoryError.unavailable
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        photoDataCallCount += 1
        guard let result = photoDataResultsByPhotoID[photo.id] else {
            throw CustomerPetRepositoryError.unavailable
        }
        return try result.get()
    }
}

@MainActor
private final class CustomerRequestRepositoryFake: CustomerRequestRepository {
    var requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError>
    var offersResult: Result<[CustomerOfferReview], CustomerRequestRepositoryError>
    var createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError>
    var uploadRequestPhotoResult: Result<GroomingRequestPhoto, CustomerRequestRepositoryError>
    var cancelResult: Result<CancelGroomingRequestResult, CustomerRequestRepositoryError>
    var requestPhotosResult: Result<[GroomingRequestPhoto], CustomerRequestRepositoryError>
    var requestPhotoDataByID: [UUID: Data]
    var acknowledgedBookingHandoffRequestIDsResult: Result<Set<UUID>, CustomerRequestRepositoryError>
    var acknowledgeBookingHandoffResult: Result<Void, CustomerRequestRepositoryError>

    private(set) var requestsCallCount = 0
    private(set) var offersCallCount = 0
    private(set) var createCallCount = 0
    private(set) var uploadRequestPhotoCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var requestPhotosCallCount = 0
    private(set) var requestPhotoDataCallCount = 0
    private(set) var acknowledgedBookingHandoffRequestIDsCallCount = 0
    private(set) var acknowledgeBookingHandoffCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastOfferCustomerID: UUID?
    private(set) var lastOfferRequestID: UUID?
    private(set) var lastCancelRequestID: UUID?
    private(set) var lastRequestPhotoCustomerID: UUID?
    private(set) var lastRequestPhotoRequestIDs: [UUID] = []
    private(set) var lastRequestPhotoDataID: UUID?
    private(set) var lastDraft: GroomingRequestDraft?
    private(set) var lastUploadCustomerID: UUID?
    private(set) var lastUploadRequestID: UUID?
    private(set) var lastUploadData: Data?
    private(set) var lastUploadContentType: GroomingRequestPhotoContentType?
    private(set) var lastUploadCaption: String?
    private(set) var lastAcknowledgedBookingHandoffCustomerID: UUID?
    private(set) var lastAcknowledgedBookingHandoffRequestID: UUID?
    private(set) var lastAcknowledgedBookingHandoffBookingID: UUID?

    init(
        requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError> = .success([]),
        offersResult: Result<[CustomerOfferReview], CustomerRequestRepositoryError> = .success([]),
        createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError> =
            .failure(.unavailable),
        uploadRequestPhotoResult: Result<GroomingRequestPhoto, CustomerRequestRepositoryError> =
            .failure(.unavailable),
        cancelResult: Result<CancelGroomingRequestResult, CustomerRequestRepositoryError> =
            .failure(.unavailable),
        requestPhotosResult: Result<[GroomingRequestPhoto], CustomerRequestRepositoryError> =
            .success([]),
        requestPhotoDataByID: [UUID: Data] = [:],
        acknowledgedBookingHandoffRequestIDsResult: Result<Set<UUID>, CustomerRequestRepositoryError> =
            .success([]),
        acknowledgeBookingHandoffResult: Result<Void, CustomerRequestRepositoryError> =
            .success(())
    ) {
        self.requestsResult = requestsResult
        self.offersResult = offersResult
        self.createResult = createResult
        self.uploadRequestPhotoResult = uploadRequestPhotoResult
        self.cancelResult = cancelResult
        self.requestPhotosResult = requestPhotosResult
        self.requestPhotoDataByID = requestPhotoDataByID
        self.acknowledgedBookingHandoffRequestIDsResult = acknowledgedBookingHandoffRequestIDsResult
        self.acknowledgeBookingHandoffResult = acknowledgeBookingHandoffResult
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        requestsCallCount += 1
        return try requestsResult.get()
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        offersCallCount += 1
        lastOfferCustomerID = customerID
        lastOfferRequestID = requestID
        return try offersResult.get()
    }

    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        requestPhotosCallCount += 1
        lastRequestPhotoCustomerID = customerID
        lastRequestPhotoRequestIDs = requestIDs
        return try requestPhotosResult.get()
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        requestPhotoDataCallCount += 1
        lastRequestPhotoDataID = photo.id
        guard let data = requestPhotoDataByID[photo.id] else {
            throw CustomerRequestRepositoryError.unavailable
        }
        return data
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        createCallCount += 1
        lastCustomerID = customerID
        lastDraft = draft
        return try createResult.get()
    }

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        uploadRequestPhotoCallCount += 1
        lastUploadCustomerID = customerID
        lastUploadRequestID = requestID
        lastUploadData = data
        lastUploadContentType = contentType
        lastUploadCaption = caption
        return try uploadRequestPhotoResult.get()
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        cancelCallCount += 1
        lastCancelRequestID = requestID
        return try cancelResult.get()
    }

    func acknowledgedBookingHandoffRequestIDs(
        customerID: UUID
    ) async throws -> Set<UUID> {
        acknowledgedBookingHandoffRequestIDsCallCount += 1
        lastAcknowledgedBookingHandoffCustomerID = customerID
        return try acknowledgedBookingHandoffRequestIDsResult.get()
    }

    func acknowledgeBookingHandoff(
        customerID: UUID,
        requestID: UUID,
        bookingID: UUID
    ) async throws {
        acknowledgeBookingHandoffCallCount += 1
        lastAcknowledgedBookingHandoffCustomerID = customerID
        lastAcknowledgedBookingHandoffRequestID = requestID
        lastAcknowledgedBookingHandoffBookingID = bookingID
        try acknowledgeBookingHandoffResult.get()
    }
}

@MainActor
private final class CustomerRequestBookingRepositoryFake: BookingRepository {
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError>

    private(set) var bookingsCallCount = 0
    private(set) var acceptCallCount = 0
    private(set) var lastBookingsParticipantID: UUID?
    private(set) var lastBookingsRole: UserRole?
    private(set) var lastAcceptedOfferID: UUID?

    init(
        bookingsResult: Result<[Booking], BookingRepositoryError> = .success([]),
        acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError> =
            .failure(.unavailable)
    ) {
        self.bookingsResult = bookingsResult
        self.acceptResult = acceptResult
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        bookingsCallCount += 1
        lastBookingsParticipantID = participantID
        lastBookingsRole = role
        return try bookingsResult.get()
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        acceptCallCount += 1
        lastAcceptedOfferID = offerID
        return try acceptResult.get()
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
