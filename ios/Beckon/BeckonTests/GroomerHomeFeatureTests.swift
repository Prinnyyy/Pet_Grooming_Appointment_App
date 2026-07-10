import Foundation
import Testing
@testable import Beckon

struct GroomerHomeFeatureTests {
    @Test @MainActor
    func loadBuildsOperationalSummaryFromLiveRepositories() async throws {
        let groomerID = UUID()
        let requestID = UUID()
        let nextBooking = makeBooking(
            requestID: requestID,
            groomerID: groomerID,
            scheduledStart: "2026-07-10T17:00:00Z",
            scheduledEnd: "2026-07-10T19:00:00Z",
            status: .confirmed
        )
        let laterBooking = makeBooking(
            groomerID: groomerID,
            scheduledStart: "2026-07-11T17:00:00Z",
            scheduledEnd: "2026-07-11T19:00:00Z",
            status: .confirmed
        )
        let requestPhoto = GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: UUID(),
            storageBucket: "request-photos",
            storagePath: "customer/request/pet.jpg",
            caption: nil,
            sortOrder: 0,
            createdAt: nil
        )
        let avatarData = Data("avatar".utf8)
        let petPhotoData = Data("pet-photo".utf8)
        let profileRepository = GroomerProfileRepositoryFake(
            profileResult: .success(makeProfile(groomerID: groomerID)),
            availabilityResult: .success([
                GroomerAvailabilityWindow(
                    id: UUID(),
                    groomerID: groomerID,
                    weekday: .friday,
                    startMinutes: 9 * 60,
                    endMinutes: 17 * 60,
                    isEnabled: true,
                    timezone: "America/Los_Angeles"
                ),
            ]),
            avatarPhotoDataResult: .success(avatarData)
        )
        let requestRepository = GroomerHomeRequestRepositoryFake(
            matchedRequestsResult: .success([
                makeMatchedRequest(groomerID: groomerID, status: .visible),
                makeMatchedRequest(groomerID: groomerID, status: .viewed),
                makeMatchedRequest(groomerID: groomerID, status: .offered),
            ]),
            offersResult: .success([
                makeOfferItem(groomerID: groomerID, status: .pending),
                makeOfferItem(groomerID: groomerID, status: .acceptedByCustomer),
            ]),
            requestPhotosResult: .success([requestPhoto]),
            photoDataResult: .success(petPhotoData)
        )
        let bookingRepository = GroomerHomeBookingRepositoryFake(
            bookingsResult: .success([
                laterBooking,
                nextBooking,
                makeBooking(
                    groomerID: groomerID,
                    scheduledStart: "2026-07-10T13:00:00Z",
                    scheduledEnd: "2026-07-10T14:00:00Z",
                    status: .cancelledByCustomer
                ),
            ])
        )
        let store = GroomerHomeStore(
            groomerID: groomerID,
            displayName: "Taylor",
            profileRepository: profileRepository,
            requestRepository: requestRepository,
            bookingRepository: bookingRepository,
            profileSnapshotCache: GroomerHomeProfileSnapshotCache(),
            now: { ISO8601DateFormatter().date(from: "2026-07-10T16:00:00Z")! }
        )

        await store.load()

        #expect(store.greetingName == "Taylor")
        #expect(store.businessName == "Prinny & Paws")
        #expect(store.avatarPhotoData == avatarData)
        #expect(store.newMatchCount == 2)
        #expect(store.pendingOfferCount == 1)
        #expect(store.nextBooking?.id == nextBooking.id)
        #expect(store.nextBookingPhotoData == petPhotoData)
        #expect(store.availabilityState == .available)
        #expect(store.issues.isEmpty)
        #expect(requestRepository.requestPhotoRequestIDs == [requestID])
    }

    @Test @MainActor
    func cachedProfileRemainsVisibleWhenProfileRefreshFails() async {
        let groomerID = UUID()
        let cachedAvatar = Data("cached-avatar".utf8)
        let cache = GroomerHomeProfileSnapshotCache(
            snapshot: ProfileSnapshot(
                userID: groomerID,
                displayName: "Cached Studio",
                detailText: "Cached details",
                avatarData: cachedAvatar
            )
        )
        let store = GroomerHomeStore(
            groomerID: groomerID,
            displayName: "Morgan",
            profileRepository: GroomerProfileRepositoryFake(
                profileResult: .failure(.networkUnavailable),
                availabilityResult: .success([])
            ),
            requestRepository: GroomerHomeRequestRepositoryFake(
                matchedRequestsResult: .success([
                    makeMatchedRequest(groomerID: groomerID, status: .visible),
                ])
            ),
            bookingRepository: GroomerHomeBookingRepositoryFake(
                bookingsResult: .success([])
            ),
            profileSnapshotCache: cache
        )

        #expect(store.businessName == "Cached Studio")
        #expect(store.avatarPhotoData == cachedAvatar)

        await store.load()

        #expect(store.businessName == "Cached Studio")
        #expect(store.avatarPhotoData == cachedAvatar)
        #expect(store.newMatchCount == 1)
        #expect(store.nextBooking == nil)
        #expect(store.issues.map(\.section) == [.profile])
        #expect(store.issues.first?.feedbackError.scope == .module("groomer.home.profile"))
        #expect(store.issues.first?.feedbackError.sourceKey == "groomer-home.profile.load")
    }

    @Test @MainActor
    func cancellationDoesNotCreateUserFacingIssue() async {
        let groomerID = UUID()
        let store = GroomerHomeStore(
            groomerID: groomerID,
            displayName: "Avery",
            profileRepository: GroomerProfileRepositoryFake(
                profileResult: .failure(.cancelled),
                availabilityResult: .failure(.cancelled)
            ),
            requestRepository: GroomerHomeRequestRepositoryFake(
                matchedRequestsResult: .failure(.cancelled),
                offersResult: .failure(.cancelled)
            ),
            bookingRepository: GroomerHomeBookingRepositoryFake(
                bookingsResult: .failure(.cancelled)
            ),
            profileSnapshotCache: GroomerHomeProfileSnapshotCache()
        )

        await store.load()

        #expect(store.issues.isEmpty)
        #expect(store.isLoading == false)
    }
}

@MainActor
private final class GroomerHomeProfileSnapshotCache: ProfileSnapshotCaching {
    private var storedSnapshot: ProfileSnapshot?

    init(snapshot: ProfileSnapshot? = nil) {
        storedSnapshot = snapshot
    }

    func snapshot(userID: UUID) -> ProfileSnapshot? {
        guard storedSnapshot?.userID == userID else { return nil }
        return storedSnapshot
    }

    func save(_ snapshot: ProfileSnapshot) {
        storedSnapshot = snapshot
    }

    func remove(userID: UUID) {
        guard storedSnapshot?.userID == userID else { return }
        storedSnapshot = nil
    }
}

@MainActor
private final class GroomerHomeRequestRepositoryFake: GroomerRequestRepository {
    let matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError>
    let offersResult: Result<[GroomerOfferListItem], GroomerRequestRepositoryError>
    let requestPhotosResult: Result<[GroomingRequestPhoto], GroomerRequestRepositoryError>
    let photoDataResult: Result<Data, GroomerRequestRepositoryError>
    private(set) var requestPhotoRequestIDs: [UUID] = []

    init(
        matchedRequestsResult: Result<[GroomerMatchedRequest], GroomerRequestRepositoryError> = .success([]),
        offersResult: Result<[GroomerOfferListItem], GroomerRequestRepositoryError> = .success([]),
        requestPhotosResult: Result<[GroomingRequestPhoto], GroomerRequestRepositoryError> = .success([]),
        photoDataResult: Result<Data, GroomerRequestRepositoryError> = .failure(.unavailable)
    ) {
        self.matchedRequestsResult = matchedRequestsResult
        self.offersResult = offersResult
        self.requestPhotosResult = requestPhotosResult
        self.photoDataResult = photoDataResult
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        try matchedRequestsResult.get()
    }

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem] {
        try offersResult.get()
    }

    func requestPhotos(
        groomerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        requestPhotoRequestIDs = requestIDs
        return try requestPhotosResult.get()
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        try photoDataResult.get()
    }

    func dismiss(matchID: UUID, reason: String?) async throws -> DismissRequestMatchResult {
        throw GroomerRequestRepositoryError.unavailable
    }

    func createOffer(draft: GroomerOfferDraft) async throws -> CreateGroomerOfferResult {
        throw GroomerRequestRepositoryError.unavailable
    }

    func withdrawOffer(offerID: UUID) async throws -> WithdrawGroomerOfferResult {
        throw GroomerRequestRepositoryError.unavailable
    }
}

@MainActor
private final class GroomerHomeBookingRepositoryFake: BookingRepository {
    let bookingsResult: Result<[Booking], BookingRepositoryError>

    init(bookingsResult: Result<[Booking], BookingRepositoryError>) {
        self.bookingsResult = bookingsResult
    }

    func bookings(participantID: UUID, role: UserRole) async throws -> [Booking] {
        try bookingsResult.get()
    }

    func acceptOffer(offerID: UUID) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(bookingID: UUID) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(bookingID: UUID) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}

private func makeProfile(groomerID: UUID) -> GroomerProfile {
    GroomerProfile(
        userID: groomerID,
        avatarPath: "groomer/avatar.jpg",
        businessName: "Prinny & Paws",
        bio: "Calm grooming",
        yearsExperience: 5,
        baseStreetAddress: "100 Main Street",
        baseCity: "Fullerton",
        baseState: "CA",
        baseZipCode: "92831",
        serviceRadiusMiles: 12,
        serviceLocationMode: .customerComesToGroomer,
        serviceLocationModes: [.customerComesToGroomer],
        ratingAverage: 4.9,
        ratingCount: 24,
        isActive: true,
        isVerified: true
    )
}

private func makeMatchedRequest(
    groomerID: UUID,
    status: RequestMatchStatus
) -> GroomerMatchedRequest {
    let requestID = UUID()
    return GroomerMatchedRequest(
        match: GroomerRequestMatch(
            id: UUID(),
            requestID: requestID,
            groomerID: groomerID,
            customerID: UUID(),
            matchScore: nil,
            matchReason: nil,
            dismissReason: nil,
            status: status,
            viewedAt: nil,
            dismissedAt: nil,
            createdAt: "2026-07-10T12:00:00Z",
            updatedAt: "2026-07-10T12:00:00Z"
        ),
        request: GroomerMatchedGroomingRequest(
            id: requestID,
            customerID: UUID(),
            petID: UUID(),
            petSnapshot: makePetSnapshot(),
            photoSnapshot: [],
            serviceType: .fullGroom,
            serviceNotes: nil,
            preferredStart: "2026-07-12T16:00:00Z",
            preferredEnd: "2026-07-12T18:00:00Z",
            locationMode: .customerComesToGroomer,
            streetAddress: "100 Main Street",
            city: "Fullerton",
            state: "CA",
            zipCode: "92831",
            travelRadiusMiles: nil,
            status: .open,
            expiresAt: "2026-07-13T12:00:00Z",
            createdAt: "2026-07-10T12:00:00Z",
            updatedAt: "2026-07-10T12:00:00Z"
        ),
        offer: nil
    )
}

private func makeOfferItem(
    groomerID: UUID,
    status: GroomerOfferStatus
) -> GroomerOfferListItem {
    GroomerOfferListItem(
        offer: GroomerOffer(
            id: UUID(),
            requestID: UUID(),
            matchID: UUID(),
            customerID: UUID(),
            groomerID: groomerID,
            proposedStart: "2026-07-12T16:00:00Z",
            proposedEnd: "2026-07-12T18:00:00Z",
            priceEstimate: 120,
            message: nil,
            status: status,
            expiresAt: "2026-07-13T12:00:00Z",
            withdrawnAt: nil,
            createdAt: "2026-07-10T12:00:00Z",
            updatedAt: "2026-07-10T12:00:00Z"
        ),
        request: nil,
        booking: nil
    )
}

private func makeBooking(
    requestID: UUID = UUID(),
    groomerID: UUID,
    scheduledStart: String,
    scheduledEnd: String,
    status: BookingStatus
) -> Booking {
    Booking(
        id: UUID(),
        requestID: requestID,
        offerID: UUID(),
        customerID: UUID(),
        groomerID: groomerID,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        priceEstimate: 120,
        status: status,
        cancelledBy: nil,
        cancelledAt: nil,
        completedAt: nil,
        completedBy: nil,
        createdAt: "2026-07-10T12:00:00Z",
        updatedAt: "2026-07-10T12:00:00Z",
        review: nil,
        serviceType: .fullGroom,
        requestPetSnapshot: makePetSnapshot(),
        locationMode: .groomerComesToCustomer,
        customerStreetAddress: "200 Harbor Boulevard",
        customerCity: "Fullerton",
        customerState: "CA",
        customerZipCode: "92832"
    )
}

private func makePetSnapshot() -> GroomingRequestPetSnapshot {
    GroomingRequestPetSnapshot(
        id: UUID(),
        name: "Banksy",
        species: "dog",
        breed: "Goldendoodle",
        coatType: "curly",
        size: "L",
        weightLbs: 48,
        birthday: nil,
        temperament: "calm",
        medicalNotes: nil,
        groomingNotes: nil,
        snapshotAt: "2026-07-10T12:00:00Z"
    )
}
