import Foundation
@testable import Beckon

extension CustomerRequestsStore {
    func confirmCurrentTestAddress(
        placeID: String? = nil,
        coordinate: BeckonAddressCoordinate = BeckonAddressCoordinate(
            latitude: 47.6062,
            longitude: -122.3321
        )
    ) {
        let input = BeckonAddressInput(
            line1: streetAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            line2: addressLine2.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode: stateCode,
            postalCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
            countryCode: "US"
        )
        let confirmed = BeckonConfirmedAddress(
            entered: input,
            accepted: input,
            provider: "apple_maps",
            placeID: placeID,
            coordinate: coordinate,
            resolutionSource: "autocomplete_selection",
            confirmedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        addressEditorState.replaceInput(input, confirmedAddress: confirmed)
    }
}

@MainActor
final class CustomerRequestPetRepositoryFake: CustomerPetRepository {
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

final class CustomerRequestAppointmentReminderSchedulerFake:
    AppointmentReminderScheduling,
    @unchecked Sendable
{
    private(set) var syncCallCount = 0
    private(set) var lastSyncedBookings: [Booking]?
    private(set) var lastSyncedRole: UserRole?

    func syncReminders(
        for bookings: [Booking],
        role: UserRole
    ) async -> AppointmentReminderSyncResult {
        syncCallCount += 1
        lastSyncedBookings = bookings
        lastSyncedRole = role
        return .scheduled(count: bookings.count)
    }

    func cancelReminder(for bookingID: UUID, role: UserRole) async {}
}

@MainActor
final class CustomerRequestRepositoryFake: CustomerRequestRepository {
    var requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError>
    var offersResult: Result<[CustomerOfferReview], CustomerRequestRepositoryError>
    var createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError>
    var uploadRequestPhotoResult: Result<GroomingRequestPhoto, CustomerRequestRepositoryError>
    var cancelResult: Result<CancelGroomingRequestResult, CustomerRequestRepositoryError>
    var requestPhotosResult: Result<[GroomingRequestPhoto], CustomerRequestRepositoryError>
    var requestPhotoDataByID: [UUID: Data]
    var acknowledgedBookingHandoffRequestIDsResult: Result<Set<UUID>, CustomerRequestRepositoryError>
    var acknowledgeBookingHandoffResult: Result<Void, CustomerRequestRepositoryError>
    var requestPages: [Result<ListPage<CustomerGroomingRequest>, CustomerRequestRepositoryError>]
    var offerPages: [Result<ListPage<CustomerOfferReview>, CustomerRequestRepositoryError>]

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
    private(set) var receivedDrafts: [GroomingRequestDraft] = []
    private(set) var lastUploadCustomerID: UUID?
    private(set) var lastUploadRequestID: UUID?
    private(set) var lastUploadData: Data?
    private(set) var lastUploadContentType: GroomingRequestPhotoContentType?
    private(set) var lastUploadCaption: String?
    private(set) var lastAcknowledgedBookingHandoffCustomerID: UUID?
    private(set) var lastAcknowledgedBookingHandoffRequestID: UUID?
    private(set) var lastAcknowledgedBookingHandoffBookingID: UUID?
    private(set) var receivedRequestPages: [ListPageRequest] = []
    private(set) var receivedOfferPages: [ListPageRequest] = []

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
            .success(()),
        requestPages: [Result<ListPage<CustomerGroomingRequest>, CustomerRequestRepositoryError>] = [],
        offerPages: [Result<ListPage<CustomerOfferReview>, CustomerRequestRepositoryError>] = []
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
        self.requestPages = requestPages
        self.offerPages = offerPages
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        requestsCallCount += 1
        lastCustomerID = customerID
        return try requestsResult.get()
    }

    func requests(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerGroomingRequest> {
        requestsCallCount += 1
        lastCustomerID = customerID
        receivedRequestPages.append(page)
        if !requestPages.isEmpty {
            return try requestPages.removeFirst().get()
        }

        return ListPage(
            items: try requestsResult.get(),
            request: page,
            hasMore: false
        )
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

    func offers(
        customerID: UUID,
        requestID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerOfferReview> {
        offersCallCount += 1
        lastOfferCustomerID = customerID
        lastOfferRequestID = requestID
        receivedOfferPages.append(page)
        if !offerPages.isEmpty {
            return try offerPages.removeFirst().get()
        }

        return ListPage(
            items: try offersResult.get(),
            request: page,
            hasMore: false
        )
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
        receivedDrafts.append(draft)
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
final class CustomerRequestBookingRepositoryFake: BookingRepository {
    var bookingsResult: Result<[Booking], BookingRepositoryError>
    var acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError>
    var acceptDelayNanoseconds: UInt64

    private(set) var bookingsCallCount = 0
    private(set) var acceptCallCount = 0
    private(set) var lastBookingsParticipantID: UUID?
    private(set) var lastBookingsRole: UserRole?
    private(set) var lastAcceptedOfferID: UUID?

    init(
        bookingsResult: Result<[Booking], BookingRepositoryError> = .success([]),
        acceptResult: Result<AcceptGroomerOfferResult, BookingRepositoryError> =
            .failure(.unavailable),
        acceptDelayNanoseconds: UInt64 = 0
    ) {
        self.bookingsResult = bookingsResult
        self.acceptResult = acceptResult
        self.acceptDelayNanoseconds = acceptDelayNanoseconds
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
        if acceptDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: acceptDelayNanoseconds)
        }
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
