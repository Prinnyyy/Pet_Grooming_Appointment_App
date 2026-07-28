import Foundation
import Testing
@testable import Beckon

struct CustomerRequestsStoreTests {
    @Test
    func onlyActiveCustomerTabCanPresentSharedRequestWizard() {
        #expect(
            CustomerRequestWizardPresentationOwnership.shouldPresent(
                storeRequested: true,
                isActiveTab: true
            )
        )
        #expect(
            !CustomerRequestWizardPresentationOwnership.shouldPresent(
                storeRequested: true,
                isActiveTab: false
            )
        )
        #expect(
            !CustomerRequestWizardPresentationOwnership.shouldPresent(
                storeRequested: false,
                isActiveTab: true
            )
        )
    }

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
    func loadSharesPrimaryPetPhotoDataWithWizardAndRequestCards() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let request = Self.request(customerID: customerID, petID: pet.id)
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
            requestRepository: CustomerRequestRepositoryFake(
                requestsResult: .success([request])
            ),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )

        await store.load()

        #expect(petRepository.photosCallCount == 1)
        #expect(petRepository.photoDataCallCount == 1)
        #expect(store.primaryPetPhotoData(for: pet) == photoData)
        #expect(store.visibleActionCards.first?.petAvatarPhotoData == photoData)
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
        store.confirmCurrentTestAddress()

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
        store.confirmCurrentTestAddress()

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
        store.confirmCurrentTestAddress()

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
        store.confirmCurrentTestAddress()

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.uploadRequestPhotoCallCount == 1)
        #expect(requestRepository.lastUploadRequestID == requestID)
        #expect(requestRepository.lastUploadData == Data([0x01, 0x02]))
        #expect(requestRepository.lastUploadContentType == .jpeg)
        #expect(store.pendingRequestPhotos.isEmpty)
    }

    @Test @MainActor
    func publishRetryReusesTheSameOperationIDAfterCreateFailure() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestID = UUID()
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .failure(.networkUnavailable)
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
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"
        store.confirmCurrentTestAddress()

        await store.publish()
        requestRepository.createResult = .success(
            GroomingRequestPublishResult(requestID: requestID, matchCount: 1)
        )
        await store.publish()

        #expect(requestRepository.receivedDrafts.count == 2)
        #expect(
            requestRepository.receivedDrafts[0].publishOperationID ==
                requestRepository.receivedDrafts[1].publishOperationID
        )
        #expect(store.publishResult?.requestID == requestID)
        #expect(store.isShowingWizard == false)
    }

    @Test @MainActor
    func photoUploadFailureDoesNotMisreportCreatedRequestAsPublishFailure() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestID = UUID()
        let request = Self.request(
            id: requestID,
            customerID: customerID,
            petID: pet.id
        )
        let requestRepository = CustomerRequestRepositoryFake(
            requestsResult: .success([request]),
            createResult: .success(
                GroomingRequestPublishResult(requestID: requestID, matchCount: 1)
            ),
            uploadRequestPhotoResult: .failure(.networkUnavailable)
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
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"
        store.addPendingPhoto(data: Data([0x01]), contentType: .jpeg)
        store.confirmCurrentTestAddress()

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.uploadRequestPhotoCallCount == 1)
        #expect(store.publishResult?.requestID == requestID)
        #expect(store.isShowingWizard == false)
        #expect(store.errorMessage == nil)
        #expect(store.noticeMessage?.contains("Request published.") == true)
        #expect(store.noticeMessage?.contains("photo could not be added") == true)
    }

    @Test @MainActor
    func refreshFailureDoesNotMisreportCreatedRequestAsPublishFailure() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let requestID = UUID()
        let requestRepository = CustomerRequestRepositoryFake(
            createResult: .success(
                GroomingRequestPublishResult(requestID: requestID, matchCount: 2)
            ),
            requestPages: [
                .success(
                    ListPage(
                        items: [],
                        request: .first,
                        hasMore: false
                    )
                ),
                .failure(.networkUnavailable),
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

        store.startCreate()
        store.serviceType = .fullGroom
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.streetAddress = "123 Pine St"
        store.city = "Seattle"
        store.stateCode = .washington
        store.zipCode = "98101"
        store.confirmCurrentTestAddress()

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.publishResult?.requestID == requestID)
        #expect(store.isShowingWizard == false)
        #expect(store.errorMessage == nil)
        #expect(store.noticeMessage?.contains("Request published.") == true)
        #expect(store.noticeMessage?.contains("refresh later") == true)
    }

    @Test @MainActor
    func cancelWizardDiscardsUnpublishedDraftAndReturnsToDefaultCreateState() async throws {
        let customerID = UUID()
        let firstPet = Self.pet(customerID: customerID)
        let secondPet = CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Biscuit",
            species: "Dog",
            breed: "Shih Tzu",
            coatType: nil,
            size: "S",
            weightLbs: 14,
            birthday: nil,
            temperament: "Calm",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
        let resetNow = Date(timeIntervalSinceReferenceDate: 825_000_000)
        let store = CustomerRequestsStore(
            customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(
                petsResult: .success([firstPet, secondPet])
            ),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake()
        )
        await store.load()

        store.startCreate()
        store.selectedPetID = secondPet.id
        store.serviceType = .nailTrim
        store.serviceNotes = "Nervous with dryers."
        store.preferredStart = resetNow.addingTimeInterval(4 * 60 * 60)
        store.preferredEnd = resetNow.addingTimeInterval(5 * 60 * 60)
        store.locationMode = .customerComesToGroomer
        store.streetAddress = "456 Cedar Ave"
        store.city = "Irvine"
        store.stateCode = .california
        store.zipCode = "92618"
        store.travelRadiusMiles = 42
        store.addPendingPhoto(data: Data([0x01, 0x02]), contentType: .png)
        store.errorMessage = "Draft validation error"

        store.cancelWizard(now: resetNow)

        #expect(store.isShowingWizard == false)
        #expect(store.wizardInitialStep == .pet)
        #expect(store.selectedPetID == firstPet.id)
        #expect(store.serviceType == .fullGroom)
        #expect(store.serviceNotes == "")
        #expect(store.preferredStart == resetNow.addingTimeInterval(24 * 60 * 60))
        #expect(store.preferredEnd == resetNow.addingTimeInterval(26 * 60 * 60))
        #expect(store.locationMode == .groomerComesToCustomer)
        #expect(store.streetAddress == "")
        #expect(store.city == "")
        #expect(store.stateCode == nil)
        #expect(store.zipCode == "")
        #expect(store.travelRadiusMiles == 15)
        #expect(store.pendingRequestPhotos.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor
    func sheetDismissDiscardsUnpublishedWizardDraft() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let resetNow = Date(timeIntervalSinceReferenceDate: 825_100_000)
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
        store.serviceType = .customRequest
        store.serviceNotes = "Please call first."
        store.streetAddress = "789 Maple St"
        store.city = "Anaheim"
        store.stateCode = .california
        store.zipCode = "92805"
        store.addPendingPhoto(data: Data([0x03]), contentType: .jpeg)

        store.setWizardPresentation(false, now: resetNow)

        #expect(store.isShowingWizard == false)
        #expect(store.wizardInitialStep == .pet)
        #expect(store.selectedPetID == pet.id)
        #expect(store.serviceType == .fullGroom)
        #expect(store.serviceNotes == "")
        #expect(store.streetAddress == "")
        #expect(store.city == "")
        #expect(store.stateCode == nil)
        #expect(store.zipCode == "")
        #expect(store.pendingRequestPhotos.isEmpty)
        #expect(store.preferredStart == resetNow.addingTimeInterval(24 * 60 * 60))
        #expect(store.preferredEnd == resetNow.addingTimeInterval(26 * 60 * 60))
    }

    static func pet(customerID: UUID) -> CustomerPet {
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

    static func request(
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
        addressLine2: String? = nil,
        city: String = "Seattle",
        state: String = "WA",
        zipCode: String = "98101",
        travelRadiusMiles: Int? = nil,
        updatedAt: String = "2026-06-20T12:00:00Z"
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
            addressLine2: addressLine2,
            city: city,
            state: state,
            zipCode: zipCode,
            travelRadiusMiles: travelRadiusMiles,
            status: status,
            expiresAt: "2026-06-22T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: updatedAt
        )
    }

    static func compactDisplayRange(from start: String, to end: String) -> String {
        "\(compactDisplayString(from: start)) - \(compactDisplayString(from: end))"
    }

    static func compactDisplayString(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    static func hourMinute(_ date: Date, calendar: Calendar) -> [Int] {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return [
            components.hour ?? -1,
            components.minute ?? -1,
        ]
    }

    static func offerReview(
        offerID: UUID = UUID(),
        customerID: UUID,
        requestID: UUID,
        status: GroomerOfferStatus = .pending,
        createdAt: String = "2026-06-20T13:00:00Z",
        matchScore: Double? = nil,
        matchReason: String? = nil,
        groomerAvatarPhotoData: Data? = nil
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
            groomerAvatarPhotoData: groomerAvatarPhotoData,
            matchScore: matchScore,
            matchReason: matchReason
        )
    }

    static func booking(
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

    static func petPhoto(
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
