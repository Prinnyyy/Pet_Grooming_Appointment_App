import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerRequestsStoreTests {
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
            requestRepository: requestRepository
        )

        await store.load()

        #expect(store.pets == [pet])
        #expect(store.requests == [request])
        #expect(store.selectedPetID == pet.id)
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
            requestRepository: requestRepository
        )
        await store.load()

        store.startCreate()
        store.serviceType = " Full groom "
        store.serviceNotes = "   "
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(3 * 60 * 60)
        store.city = " Seattle "
        store.state = " WA "
        store.zipCode = " 98101 "

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(requestRepository.requestsCallCount == 2)
        #expect(requestRepository.lastCustomerID == customerID)
        #expect(requestRepository.lastDraft?.petID == pet.id)
        #expect(requestRepository.lastDraft?.serviceType == "Full groom")
        #expect(requestRepository.lastDraft?.serviceNotes == nil)
        #expect(requestRepository.lastDraft?.city == "Seattle")
        #expect(requestRepository.lastDraft?.state == "WA")
        #expect(requestRepository.lastDraft?.zipCode == "98101")
        #expect(store.isShowingWizard == false)
        #expect(store.noticeMessage == "Request published. 2 groomers matched.")
        #expect(store.publishResult?.matchCount == 2)
    }

    @Test @MainActor
    func invalidFormDoesNotCallRepository() async {
        let repository = CustomerRequestRepositoryFake()
        let store = CustomerRequestsStore(
            customerID: UUID(),
            petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: repository
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
            requestRepository: repository
        )
        await store.load()

        store.startCreate()
        store.serviceType = "Bath"
        store.preferredStart = Date().addingTimeInterval(60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.city = "Seattle"
        store.state = "WA"
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
            requestRepository: requestRepository
        )
        await store.load()

        store.startCreate()
        store.serviceType = "Bath"
        store.preferredStart = Date().addingTimeInterval(60 * 60)
        store.preferredEnd = Date().addingTimeInterval(2 * 60 * 60)
        store.city = "Seattle"
        store.state = "WA"
        store.zipCode = "98101"

        await store.publish()

        #expect(requestRepository.createCallCount == 1)
        #expect(store.isShowingWizard)
        #expect(store.serviceType == "Bath")
        #expect(store.errorMessage == "You can have at most 3 open grooming requests.")
    }

    private static func pet(customerID: UUID) -> CustomerPet {
        CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: "Corgi",
            size: "Small",
            weightLbs: 22,
            birthday: nil,
            temperament: "Gentle",
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
    }

    private static func request(
        customerID: UUID,
        petID: UUID
    ) -> CustomerGroomingRequest {
        CustomerGroomingRequest(
            id: UUID(),
            customerID: customerID,
            petID: petID,
            petSnapshot: GroomingRequestPetSnapshot(
                id: petID,
                name: "Mochi",
                species: "Dog",
                breed: "Corgi",
                size: "Small",
                weightLbs: 22,
                birthday: nil,
                temperament: "Gentle",
                medicalNotes: nil,
                groomingNotes: nil,
                snapshotAt: "2026-06-20T12:00:00Z"
            ),
            photoSnapshot: [],
            serviceType: "Full groom",
            serviceNotes: nil,
            preferredStart: "2026-06-22T16:00:00Z",
            preferredEnd: "2026-06-22T18:00:00Z",
            city: "Seattle",
            state: "WA",
            zipCode: "98101",
            status: .open,
            expiresAt: "2026-06-22T12:00:00Z",
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        )
    }
}

@MainActor
private final class CustomerRequestPetRepositoryFake: CustomerPetRepository {
    var petsResult: Result<[CustomerPet], CustomerPetRepositoryError>

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([])
    ) {
        self.petsResult = petsResult
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        []
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
}

@MainActor
private final class CustomerRequestRepositoryFake: CustomerRequestRepository {
    var requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError>
    var createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError>

    private(set) var requestsCallCount = 0
    private(set) var createCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastDraft: GroomingRequestDraft?

    init(
        requestsResult: Result<[CustomerGroomingRequest], CustomerRequestRepositoryError> = .success([]),
        createResult: Result<GroomingRequestPublishResult, CustomerRequestRepositoryError> =
            .failure(.unavailable)
    ) {
        self.requestsResult = requestsResult
        self.createResult = createResult
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        requestsCallCount += 1
        return try requestsResult.get()
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
}
