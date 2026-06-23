import Foundation
import Testing
@testable import PetGroomerMarketplace

struct CustomerPetPhotoPathTests {
    @Test
    func storagePathMatchesBackendContractAndUsesLowercaseUUIDs() {
        let customerID = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let petID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let fileID = UUID(uuidString: "99999999-AAAA-4BBB-8CCC-DDDDDDDDDDDD")!

        let path = CustomerPetPhotoPath.make(
            customerID: customerID,
            petID: petID,
            fileID: fileID,
            contentType: .heic
        )

        #expect(
            path ==
                "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/11111111-2222-4333-8444-555555555555/99999999-aaaa-4bbb-8ccc-dddddddddddd.heic"
        )
    }
}

struct CustomerPetsStoreTests {
    @Test @MainActor
    func createsPetWithFixedOptionsAndDerivedSize() async {
        let customerID = UUID()
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )

        store.formName = " Mochi "
        store.formSpecies = .dog
        store.formBreed = .unspecified
        store.formWeightLbs = 22
        store.formBirthdayDate = Date(timeIntervalSince1970: 1_647_740_800)
        store.formTemperament = .gentle

        await store.savePet()

        #expect(repository.createCallCount == 1)
        #expect(repository.lastCustomerID == customerID)
        #expect(repository.lastDraft?.name == "Mochi")
        #expect(repository.lastDraft?.species == "Dog")
        #expect(repository.lastDraft?.breed == "Unspecified")
        #expect(repository.lastDraft?.size == "M")
        #expect(repository.lastDraft?.weightLbs == 22)
        #expect(repository.lastDraft?.birthday == "2022-03-20")
        #expect(repository.lastDraft?.temperament == "Gentle")
        #expect(store.pets.map(\.name) == ["Mochi"])
        #expect(store.isShowingPetForm == false)
    }

    @Test
    func sizeCodeMapsFromWeightBands() {
        #expect(CustomerPetSizeCode.code(forWeightLbs: 9.9) == .xs)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 10) == .s)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 20) == .m)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 40) == .l)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 60) == .xl)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 80) == .xxl)
        #expect(CustomerPetSizeCode.code(forWeightLbs: 101) == .giant)
    }

    @Test @MainActor
    func invalidPetFormDoesNotCallRepository() async {
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(
            customerID: UUID(),
            repository: repository
        )

        store.formName = " "
        store.formSpecies = .dog

        await store.savePet()

        #expect(repository.createCallCount == 0)
        #expect(store.errorMessage == "Pet name must be 1–80 characters.")
    }

    @Test @MainActor
    func loadGroupsPhotosByPetID() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([
                Self.photo(customerID: customerID, petID: pet.id),
            ])
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )

        await store.load()

        #expect(store.pets == [pet])
        #expect(store.photos(for: pet).count == 1)
    }

    @Test @MainActor
    func softDeleteRemovesPetAndItsPhotosFromLocalState() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo])
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        await store.softDelete(pet)

        #expect(repository.softDeleteCallCount == 1)
        #expect(store.pets.isEmpty)
        #expect(store.photos(for: pet).isEmpty)
    }

    @Test @MainActor
    func oversizedPhotoUploadDoesNotCallRepository() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )

        await store.uploadPhoto(
            pet: pet,
            data: Data(count: CustomerPetsStore.maximumPhotoBytes + 1),
            contentType: .png
        )

        #expect(repository.uploadCallCount == 0)
        #expect(store.errorMessage == "Choose a photo smaller than 10 MB.")
    }

    @Test @MainActor
    func successfulPhotoUploadAndDeleteUpdateLocalState() async throws {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let repository = CustomerPetRepositoryFake(
            uploadResult: .success(
                Self.photo(customerID: customerID, petID: pet.id)
            )
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )

        await store.uploadPhoto(
            pet: pet,
            data: Data([0x01, 0x02]),
            contentType: .jpeg
        )

        #expect(repository.uploadCallCount == 1)
        #expect(store.photos(for: pet).count == 1)

        let photo = try #require(store.photos(for: pet).first)
        await store.deletePhoto(photo)

        #expect(repository.deletePhotoCallCount == 1)
        #expect(store.photos(for: pet).isEmpty)
    }

    @Test @MainActor
    func stagedFormPhotoUploadsAfterPetCreation() async {
        let customerID = UUID()
        let createdPet = Self.pet(customerID: customerID)
        let repository = CustomerPetRepositoryFake(
            createResult: .success(createdPet),
            uploadResult: .success(
                Self.photo(customerID: customerID, petID: createdPet.id)
            )
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )

        store.formName = "Banksy"
        store.formSpecies = .dog
        store.formBreed = .corgi
        store.formWeightLbs = 21
        store.formTemperament = .friendly
        store.addPendingFormPhoto(
            data: Data([0x01, 0x02]),
            contentType: .png
        )

        await store.savePet()

        #expect(repository.createCallCount == 1)
        #expect(repository.uploadCallCount == 1)
        #expect(repository.lastUploadPetID == createdPet.id)
        #expect(store.photos(for: createdPet).count == 1)
        #expect(store.pendingFormPhotos.isEmpty)
    }

    private static func pet(customerID: UUID) -> CustomerPet {
        CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: nil,
            size: nil,
            weightLbs: nil,
            birthday: nil,
            temperament: nil,
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )
    }

    private static func photo(
        customerID: UUID,
        petID: UUID
    ) -> CustomerPetPhoto {
        CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: "pet-photos",
            storagePath: CustomerPetPhotoPath.make(
                customerID: customerID,
                petID: petID,
                contentType: .jpeg
            ),
            caption: nil,
            sortOrder: 0,
            isPrimary: false
        )
    }
}

@MainActor
private final class CustomerPetRepositoryFake: CustomerPetRepository {
    var petsResult: Result<[CustomerPet], CustomerPetRepositoryError>
    var photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError>
    var createResult: Result<CustomerPet, CustomerPetRepositoryError>?
    var updateResult: Result<CustomerPet, CustomerPetRepositoryError>?
    var softDeleteResult: Result<Void, CustomerPetRepositoryError>
    var uploadResult: Result<CustomerPetPhoto, CustomerPetRepositoryError>
    var deletePhotoResult: Result<Void, CustomerPetRepositoryError>

    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var softDeleteCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var deletePhotoCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastDraft: CustomerPetDraft?
    private(set) var lastUploadPetID: UUID?

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([]),
        photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError> = .success([]),
        createResult: Result<CustomerPet, CustomerPetRepositoryError>? = nil,
        updateResult: Result<CustomerPet, CustomerPetRepositoryError>? = nil,
        softDeleteResult: Result<Void, CustomerPetRepositoryError> = .success(()),
        uploadResult: Result<CustomerPetPhoto, CustomerPetRepositoryError> =
            .failure(.unavailable),
        deletePhotoResult: Result<Void, CustomerPetRepositoryError> = .success(())
    ) {
        self.petsResult = petsResult
        self.photosResult = photosResult
        self.createResult = createResult
        self.updateResult = updateResult
        self.softDeleteResult = softDeleteResult
        self.uploadResult = uploadResult
        self.deletePhotoResult = deletePhotoResult
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        try photosResult.get()
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        createCallCount += 1
        lastCustomerID = customerID
        lastDraft = draft

        if let createResult {
            return try createResult.get()
        }

        return CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: draft.name,
            species: draft.species,
            breed: draft.breed,
            size: draft.size,
            weightLbs: draft.weightLbs,
            birthday: draft.birthday,
            temperament: draft.temperament,
            medicalNotes: draft.medicalNotes,
            groomingNotes: draft.groomingNotes,
            isActive: true
        )
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        updateCallCount += 1
        lastDraft = draft

        if let updateResult {
            return try updateResult.get()
        }

        return CustomerPet(
            id: pet.id,
            customerID: pet.customerID,
            name: draft.name,
            species: draft.species,
            breed: draft.breed,
            size: draft.size,
            weightLbs: draft.weightLbs,
            birthday: draft.birthday,
            temperament: draft.temperament,
            medicalNotes: draft.medicalNotes,
            groomingNotes: draft.groomingNotes,
            isActive: true
        )
    }

    func softDeletePet(_ pet: CustomerPet) async throws {
        softDeleteCallCount += 1
        try softDeleteResult.get()
    }

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        uploadCallCount += 1
        lastUploadPetID = petID
        return try uploadResult.get()
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {
        deletePhotoCallCount += 1
        try deletePhotoResult.get()
    }
}
