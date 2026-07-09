import Foundation
import Testing
@testable import PetGroomerMarketplace

extension CustomerRequestsStoreTests {
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
    func startRepublishFromCancelledBookingWithoutOriginalRequestDoesNotOpenWizard() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let cancelledBooking = Self.booking(
            requestID: UUID(),
            customerID: customerID,
            status: .cancelledByCustomer
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake(
                bookingsResult: .success([cancelledBooking])
            )
        )
        await store.load()

        let didStart = store.startRepublish(
            from: cancelledBooking,
            originalRequest: nil,
            now: Date()
        )

        #expect(didStart == false)
        #expect(store.isShowingWizard == false)
        #expect(store.wizardInitialStep == .pet)
        #expect(store.pendingRequestPhotos.isEmpty)
        #expect(store.errorMessage == "Original request details are unavailable. Refresh bookings and try again.")
    }

    @Test @MainActor
    func startRepublishWithExpiredWindowAndMissingPhotoDataUsesFutureDefaultsAndSkipsMissingPhotos() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let originalRequestID = UUID()
        let now = try #require(Self.isoDate("2026-07-01T12:00:00Z"))
        let originalRequest = Self.request(
            id: originalRequestID,
            customerID: customerID,
            petID: pet.id,
            status: .cancelled,
            serviceType: .fullGroom,
            preferredStart: "2026-06-01T16:00:00Z",
            preferredEnd: "2026-06-01T18:00:00Z"
        )
        let availablePhoto = GroomingRequestPhoto(
            id: UUID(),
            requestID: originalRequestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: "customer/original/available.jpg",
            caption: nil,
            sortOrder: 0,
            createdAt: "2026-06-22T16:00:00Z"
        )
        let missingPhoto = GroomingRequestPhoto(
            id: UUID(),
            requestID: originalRequestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: "customer/original/missing.jpg",
            caption: nil,
            sortOrder: 1,
            createdAt: "2026-06-22T16:01:00Z"
        )
        let availablePhotoData = Data([0x01, 0x02, 0x03])
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([originalRequest]),
            requestPhotosResult: .success([availablePhoto, missingPhoto]),
            requestPhotoDataByID: [
                availablePhoto.id: availablePhotoData,
            ]
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

        store.startRepublish(from: originalRequest, now: now)

        #expect(store.wizardInitialStep == .review)
        #expect(store.preferredStart == now.addingTimeInterval(24 * 60 * 60))
        #expect(store.preferredEnd == now.addingTimeInterval(26 * 60 * 60))
        #expect(store.pendingRequestPhotos.map(\.data) == [availablePhotoData])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func loadKeepsRequestsAvailableWhenRequestPhotoMetadataIsUnavailable() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let cancelledRequest = Self.request(
            customerID: customerID,
            petID: pet.id,
            status: .cancelled
        )
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([pet])
            ),
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([cancelledRequest]),
                requestPhotosResult: .failure(.unavailable)
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(store.requests == [cancelledRequest])
        #expect(store.requestPhotos(for: cancelledRequest).isEmpty)
        #expect(store.errorMessage == nil)

        store.startRepublish(from: cancelledRequest)

        #expect(store.isShowingWizard)
        #expect(store.pendingRequestPhotos.isEmpty)
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

}
