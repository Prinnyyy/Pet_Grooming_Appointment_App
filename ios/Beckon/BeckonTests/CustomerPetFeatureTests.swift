import Foundation
import Testing
@testable import Beckon

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
    @Test
    func petAgeUsesStoredBirthdayForCardCopy() {
        let pet = CustomerPet(
            id: UUID(),
            customerID: UUID(),
            name: "Milo",
            species: "Dog",
            breed: "Toy Poodle",
            coatType: nil,
            size: nil,
            weightLbs: nil,
            birthday: "2020-01-01",
            temperament: nil,
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )

        #expect(pet.displayAge?.hasSuffix("years old") == true)
        #expect(pet.accessibilitySummary.contains("years old"))
    }

    @Test
    func petNameInputRejectsCharactersBeyondItsHiddenLimit() {
        let accepted = String(repeating: "a", count: 20)
        let rejectedChange = BeckonTextInputLimit.applyingChange(
            currentText: accepted,
            range: NSRange(location: accepted.utf16.count, length: 0),
            replacement: "b",
            maximumLength: CustomerPetNameInput.maximumLength
        )
        let pastedChange = BeckonTextInputLimit.applyingChange(
            currentText: "Milo",
            range: NSRange(location: 4, length: 0),
            replacement: String(repeating: "x", count: 30),
            maximumLength: CustomerPetNameInput.maximumLength
        )

        #expect(rejectedChange.text == accepted)
        #expect(rejectedChange.acceptedReplacement.isEmpty)
        #expect(rejectedChange.didReachLimit)
        #expect(pastedChange.text.count == CustomerPetNameInput.maximumLength)
        #expect(pastedChange.acceptedReplacement.count == 16)
        #expect(pastedChange.didReachLimit)
    }

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
        store.formCoatType = .doubleCoat
        store.formWeightLbs = 22
        store.formBirthdayDate = Date(timeIntervalSince1970: 1_647_740_800)
        store.formTemperament = .gentle

        await store.savePet()

        #expect(repository.createCallCount == 1)
        #expect(repository.lastCustomerID == customerID)
        #expect(repository.lastDraft?.name == "Mochi")
        #expect(repository.lastDraft?.species == "Dog")
        #expect(repository.lastDraft?.breed == "Unspecified")
        #expect(repository.lastDraft?.coatType == "double_coat")
        #expect(repository.lastDraft?.size == "M")
        #expect(repository.lastDraft?.weightLbs == 22)
        #expect(repository.lastDraft?.birthday == "2022-03-20")
        #expect(repository.lastDraft?.temperament == "Gentle")
        #expect(store.pets.map(\.name) == ["Mochi"])
        #expect(store.isShowingPetForm == false)
    }

    @Test
    func coatTypeOptionsKeepNotSureFirstAndExcludePlaceholderFromFitSignals() {
        let options = CustomerPetCoatType.displayOptions

        #expect(options.first == .notSure)
        #expect(options.contains(.doubleCoat))
        #expect(!PetFitSignal.coatTypeSignals.map(\.traitValue).contains("not_sure"))
    }

    @Test @MainActor
    func selectingKnownBreedAppliesRecommendedCoatType() {
        let store = CustomerPetsStore(
            customerID: UUID(),
            repository: CustomerPetRepositoryFake()
        )

        store.updateFormBreed(.siberianHusky)

        #expect(store.formBreed == .siberianHusky)
        #expect(store.formCoatType == .doubleCoat)
    }

    @Test @MainActor
    func editingPetHydratesSavedCoatType() {
        let pet = Self.pet(
            customerID: UUID(),
            breed: "Unspecified",
            coatType: "wire"
        )
        let store = CustomerPetsStore(
            customerID: pet.customerID,
            repository: CustomerPetRepositoryFake()
        )

        store.startEdit(pet)

        #expect(store.formBreed == .unspecified)
        #expect(store.formCoatType == .wire)
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

    @Test
    func petAccessibilitySummaryUsesReadableBreedSpeciesAndWeight() {
        let pet = CustomerPet(
            id: UUID(),
            customerID: UUID(),
            name: "Mochi",
            species: "Dog",
            breed: "Toy Poodle",
            coatType: nil,
            size: "S",
            weightLbs: 12.2,
            birthday: nil,
            temperament: nil,
            medicalNotes: nil,
            groomingNotes: nil,
            isActive: true
        )

        #expect(pet.accessibilitySummary == "Toy Poodle, Dog, 12 pounds, size S")
    }

    @Test
    func breedOptionsKeepUnspecifiedFirstAndAlphabetizeRemaining() {
        let dogOptions = CustomerPetBreed.options(for: .dog)
        let dogTitles = dogOptions.map(\.title)

        #expect(dogOptions.first == .unspecified)
        #expect(dogOptions.contains(.siberianHusky))
        #expect(Array(dogTitles.dropFirst()) == dogTitles.dropFirst().sorted())
    }

    @Test
    func temperamentOptionsKeepNotSureFirstAndAlphabetizeRemaining() {
        let titles = CustomerPetTemperament.displayOptions.map(\.title)

        #expect(CustomerPetTemperament.displayOptions.first == .notSure)
        #expect(Array(titles.dropFirst()) == titles.dropFirst().sorted())
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
    func loadUsesCachedPetPhotoDataWhenCloudDownloadFails() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let cachedData = Data([0x09, 0x10])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .failure(.networkUnavailable),
            ]
        )
        let photoCache = CustomerPetPhotoCacheFake(
            snapshots: [
                Self.photoSnapshot(photo, data: cachedData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )

        await store.load()

        #expect(store.primaryPhotoData(for: pet) == cachedData)
        #expect(photoCache.savedSnapshots.isEmpty)
    }

    @Test @MainActor
    func loadUsesCachedPetAvatarBeforePhotoMetadataReturns() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let cachedData = Data([0x31, 0x32])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo])
        )
        repository.suspendPhotos = true
        let photoCache = CustomerPetPhotoCacheFake(
            snapshots: [
                Self.photoSnapshot(photo, data: cachedData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )

        let loadTask = Task {
            await store.load()
        }
        await repository.waitUntilPhotosRequested()

        #expect(store.pets == [pet])
        #expect(store.primaryPhotoData(for: pet) == cachedData)

        repository.resumePhotos()
        await loadTask.value
    }

    @Test @MainActor
    func loadRefreshesPetPhotoCacheAfterCloudDownload() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let cachedData = Data([0x01])
        let cloudData = Data([0x02, 0x03])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .success(cloudData),
            ]
        )
        let photoCache = CustomerPetPhotoCacheFake(
            snapshots: [
                Self.photoSnapshot(photo, data: cachedData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )

        await store.load()

        #expect(store.primaryPhotoData(for: pet) == cloudData)
        #expect(photoCache.savedSnapshots.last?.photoID == photo.id)
        #expect(photoCache.savedSnapshots.last?.data == cloudData)
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
        let uploadedData = Data([0x01, 0x02])
        let uploadedPhoto = Self.photo(customerID: customerID, petID: pet.id)
        let repository = CustomerPetRepositoryFake(
            uploadResult: .success(
                uploadedPhoto
            )
        )
        let photoCache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )

        await store.uploadPhoto(
            pet: pet,
            data: uploadedData,
            contentType: .jpeg
        )

        #expect(repository.uploadCallCount == 1)
        #expect(store.photos(for: pet).count == 1)
        #expect(store.primaryPhotoData(for: pet) == uploadedData)
        #expect(photoCache.savedSnapshots.last?.photoID == uploadedPhoto.id)
        #expect(photoCache.savedSnapshots.last?.data == uploadedData)

        let photo = try #require(store.photos(for: pet).first)
        await store.deletePhoto(photo)

        #expect(repository.deletePhotoCallCount == 1)
        #expect(store.photos(for: pet).isEmpty)
        #expect(store.primaryPhotoData(for: pet) == nil)
        #expect(photoCache.removedPhotoIDs == [uploadedPhoto.id])
    }

    @Test @MainActor
    func avatarUploadReplacesExistingPetPhotoAndCache() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let oldPhoto = Self.photo(customerID: customerID, petID: pet.id)
        let newPhoto = Self.photo(customerID: customerID, petID: pet.id)
        let oldData = Data([0x01])
        let newData = Data([0x02, 0x03])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([oldPhoto]),
            uploadResult: .success(newPhoto),
            photoDataResultsByPhotoID: [
                oldPhoto.id: .success(oldData),
            ]
        )
        let photoCache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )
        await store.load()

        await store.uploadPhoto(
            pet: pet,
            data: newData,
            contentType: .jpeg
        )

        #expect(repository.uploadCallCount == 1)
        #expect(repository.deletePhotoCallCount == 1)
        #expect(repository.deletedPhotoIDs == [oldPhoto.id])
        #expect(store.photos(for: pet) == [newPhoto])
        #expect(store.primaryPhotoData(for: pet) == newData)
        #expect(photoCache.savedSnapshots.last?.photoID == newPhoto.id)
        #expect(photoCache.removedPhotoIDs == [oldPhoto.id])
    }

    @Test @MainActor
    func cardPhotoUploadBecomesAvatarWhenOlderPhotoHasNoImageData() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let olderPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/000-old.jpg",
            sortOrder: 0
        )
        let uploadedPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/999-new.jpg",
            sortOrder: 1
        )
        let uploadedData = Data([0x33, 0x44])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([olderPhoto]),
            uploadResult: .success(uploadedPhoto)
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        #expect(store.primaryPhotoData(for: pet) == nil)

        await store.uploadPhoto(
            pet: pet,
            data: uploadedData,
            contentType: .jpeg
        )

        #expect(store.photos(for: pet) == [uploadedPhoto])
        #expect(store.primaryPhotoData(for: pet) == uploadedData)
    }

    @Test @MainActor
    func cardPhotoUploadBecomesAvatarWhenExistingPrimaryHasImageData() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let existingPrimaryPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/000-primary.jpg",
            sortOrder: 0,
            isPrimary: true
        )
        let uploadedPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/999-new.jpg",
            sortOrder: 1
        )
        let existingData = Data([0x10, 0x20])
        let uploadedData = Data([0x30, 0x40])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([existingPrimaryPhoto]),
            uploadResult: .success(uploadedPhoto),
            photoDataResultsByPhotoID: [
                existingPrimaryPhoto.id: .success(existingData),
            ]
        )
        let photoCache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )
        await store.load()

        #expect(store.primaryPhotoData(for: pet) == existingData)

        await store.uploadPhoto(
            pet: pet,
            data: uploadedData,
            contentType: .jpeg
        )

        #expect(store.photos(for: pet) == [uploadedPhoto])
        #expect(store.primaryPhotoData(for: pet) == uploadedData)
    }

    @Test @MainActor
    func cardPhotoUploadBecomesAvatarWhenUploadedPhotoHasSameSortOrder() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let existingPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/zzz-existing.jpg",
            sortOrder: 0
        )
        let uploadedPhoto = Self.photo(
            customerID: customerID,
            petID: pet.id,
            storagePath: "customer/pet/aaa-new.jpg",
            sortOrder: 0
        )
        let existingData = Data([0x10, 0x20])
        let uploadedData = Data([0x30, 0x40])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([existingPhoto]),
            uploadResult: .success(uploadedPhoto),
            photoDataResultsByPhotoID: [
                existingPhoto.id: .success(existingData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        #expect(store.primaryPhotoData(for: pet) == existingData)

        await store.uploadPhoto(
            pet: pet,
            data: uploadedData,
            contentType: .jpeg
        )

        #expect(store.primaryPhotoData(for: pet) == uploadedData)
    }

    @Test @MainActor
    func editFormUsesExistingAvatarPhotoData() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let existingData = Data([0x50, 0x60])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .success(existingData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        store.startEdit(pet)

        #expect(store.formAvatarPhotoData == existingData)
    }

    @Test @MainActor
    func editFormAvatarPreviewPrefersPendingPhoto() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let photo = Self.photo(customerID: customerID, petID: pet.id)
        let existingData = Data([0x50, 0x60])
        let pendingData = Data([0x70, 0x80])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([photo]),
            photoDataResultsByPhotoID: [
                photo.id: .success(existingData),
            ]
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()
        store.startEdit(pet)

        store.addPendingFormPhoto(data: pendingData, contentType: .png)

        #expect(store.formAvatarPhotoData == pendingData)
        #expect(store.pendingFormPhotos.count == 1)
    }

    @Test @MainActor
    func editFormAvatarSelectionReplacesPreviousPendingPhoto() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let firstPendingData = Data([0x11])
        let secondPendingData = Data([0x22])
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: CustomerPetRepositoryFake(
                petsResult: .success([pet])
            )
        )
        await store.load()
        store.startEdit(pet)

        store.addPendingFormPhoto(data: firstPendingData, contentType: .jpeg)
        store.addPendingFormPhoto(data: secondPendingData, contentType: .png)

        #expect(store.pendingFormPhotos.count == 1)
        #expect(store.formAvatarPhotoData == secondPendingData)
    }

    @Test @MainActor
    func stagedEditAvatarUploadReplacesExistingPetPhotoAndCache() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let oldPhoto = Self.photo(customerID: customerID, petID: pet.id)
        let newPhoto = Self.photo(customerID: customerID, petID: pet.id)
        let oldData = Data([0x12])
        let newData = Data([0x34, 0x56])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            photosResult: .success([oldPhoto]),
            updateResult: .success(pet),
            uploadResult: .success(newPhoto),
            photoDataResultsByPhotoID: [
                oldPhoto.id: .success(oldData),
            ]
        )
        let photoCache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )
        await store.load()

        store.startEdit(pet)
        store.addPendingFormPhoto(data: newData, contentType: .png)
        await store.savePet()

        #expect(repository.updateCallCount == 1)
        #expect(repository.uploadCallCount == 1)
        #expect(repository.deletePhotoCallCount == 1)
        #expect(repository.deletedPhotoIDs == [oldPhoto.id])
        #expect(store.photos(for: pet) == [newPhoto])
        #expect(store.primaryPhotoData(for: pet) == newData)
        #expect(photoCache.removedPhotoIDs == [oldPhoto.id])
    }

    @Test @MainActor
    func stagedFormPhotoUploadsAfterPetCreation() async {
        let customerID = UUID()
        let createdPet = Self.pet(customerID: customerID)
        let stagedPhotoData = Data([0x01, 0x02])
        let uploadedPhoto = Self.photo(customerID: customerID, petID: createdPet.id)
        let repository = CustomerPetRepositoryFake(
            createResult: .success(createdPet),
            uploadResult: .success(
                uploadedPhoto
            )
        )
        let photoCache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository,
            photoCache: photoCache
        )

        store.formName = "Banksy"
        store.formSpecies = .dog
        store.formBreed = .corgi
        store.formWeightLbs = 21
        store.formTemperament = .friendly
        store.addPendingFormPhoto(
            data: stagedPhotoData,
            contentType: .png
        )

        await store.savePet()

        #expect(repository.createCallCount == 1)
        #expect(repository.uploadCallCount == 1)
        #expect(repository.lastUploadPetID == createdPet.id)
        #expect(store.photos(for: createdPet).count == 1)
        #expect(store.primaryPhotoData(for: createdPet) == stagedPhotoData)
        #expect(photoCache.savedSnapshots.last?.photoID == uploadedPhoto.id)
        #expect(photoCache.savedSnapshots.last?.data == stagedPhotoData)
        #expect(store.pendingFormPhotos.isEmpty)
    }

    @Test @MainActor
    func stagedFormPhotoUploadsAfterPetUpdateRefreshPrimaryPhotoData() async {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let stagedPhotoData = Data([0x03, 0x04])
        let repository = CustomerPetRepositoryFake(
            petsResult: .success([pet]),
            updateResult: .success(pet),
            uploadResult: .success(
                Self.photo(customerID: customerID, petID: pet.id)
            )
        )
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: repository
        )
        await store.load()

        store.startEdit(pet)
        store.addPendingFormPhoto(
            data: stagedPhotoData,
            contentType: .png
        )

        await store.savePet()

        #expect(repository.updateCallCount == 1)
        #expect(repository.uploadCallCount == 1)
        #expect(repository.lastUploadPetID == pet.id)
        #expect(store.photos(for: pet).count == 1)
        #expect(store.primaryPhotoData(for: pet) == stagedPhotoData)
    }

    private static func pet(
        customerID: UUID,
        breed: String? = nil,
        coatType: String? = nil
    ) -> CustomerPet {
        CustomerPet(
            id: UUID(),
            customerID: customerID,
            name: "Mochi",
            species: "Dog",
            breed: breed,
            coatType: coatType,
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
        petID: UUID,
        storagePath: String? = nil,
        sortOrder: Int = 0,
        isPrimary: Bool = false
    ) -> CustomerPetPhoto {
        CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: "pet-photos",
            storagePath: storagePath ?? CustomerPetPhotoPath.make(
                customerID: customerID,
                petID: petID,
                contentType: .jpeg
            ),
            caption: nil,
            sortOrder: sortOrder,
            isPrimary: isPrimary
        )
    }

    @MainActor
    private static func photoSnapshot(
        _ photo: CustomerPetPhoto,
        data: Data
    ) -> CustomerPetPhotoSnapshot {
        CustomerPetPhotoSnapshot(
            customerID: photo.customerID,
            petID: photo.petID,
            photoID: photo.id,
            storagePath: photo.storagePath,
            data: data
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
    var photoDataResultsByPhotoID: [UUID: Result<Data, CustomerPetRepositoryError>]
    var deletePhotoResult: Result<Void, CustomerPetRepositoryError>
    var suspendPhotos = false

    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var softDeleteCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var deletePhotoCallCount = 0
    private(set) var photosCallCount = 0
    private(set) var lastCustomerID: UUID?
    private(set) var lastDraft: CustomerPetDraft?
    private(set) var lastUploadPetID: UUID?
    private(set) var deletedPhotoIDs: [UUID] = []
    private var photosContinuation:
        CheckedContinuation<[CustomerPetPhoto], any Error>?
    private var photosRequestedContinuation: CheckedContinuation<Void, Never>?

    init(
        petsResult: Result<[CustomerPet], CustomerPetRepositoryError> = .success([]),
        photosResult: Result<[CustomerPetPhoto], CustomerPetRepositoryError> = .success([]),
        createResult: Result<CustomerPet, CustomerPetRepositoryError>? = nil,
        updateResult: Result<CustomerPet, CustomerPetRepositoryError>? = nil,
        softDeleteResult: Result<Void, CustomerPetRepositoryError> = .success(()),
        uploadResult: Result<CustomerPetPhoto, CustomerPetRepositoryError> =
            .failure(.unavailable),
        photoDataResultsByPhotoID: [UUID: Result<Data, CustomerPetRepositoryError>] = [:],
        deletePhotoResult: Result<Void, CustomerPetRepositoryError> = .success(())
    ) {
        self.petsResult = petsResult
        self.photosResult = photosResult
        self.createResult = createResult
        self.updateResult = updateResult
        self.softDeleteResult = softDeleteResult
        self.uploadResult = uploadResult
        self.photoDataResultsByPhotoID = photoDataResultsByPhotoID
        self.deletePhotoResult = deletePhotoResult
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try petsResult.get()
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        photosCallCount += 1
        if suspendPhotos {
            return try await withCheckedThrowingContinuation { continuation in
                photosContinuation = continuation
                photosRequestedContinuation?.resume()
                photosRequestedContinuation = nil
            }
        }

        return try photosResult.get()
    }

    func waitUntilPhotosRequested() async {
        guard photosCallCount == 0 else { return }

        await withCheckedContinuation { continuation in
            photosRequestedContinuation = continuation
        }
    }

    func resumePhotos() {
        guard let photosContinuation else { return }
        self.photosContinuation = nil

        switch photosResult {
        case .success(let photos):
            photosContinuation.resume(returning: photos)
        case .failure(let error):
            photosContinuation.resume(throwing: error)
        }
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
            coatType: draft.coatType,
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
            coatType: draft.coatType,
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
        deletedPhotoIDs.append(photo.id)
        try deletePhotoResult.get()
    }

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        guard let result = photoDataResultsByPhotoID[photo.id] else {
            throw CustomerPetRepositoryError.unavailable
        }
        return try result.get()
    }
}

@MainActor
private final class CustomerPetPhotoCacheFake: CustomerPetPhotoCaching {
    private var snapshotsByPhotoID: [UUID: CustomerPetPhotoSnapshot]
    private(set) var savedSnapshots: [CustomerPetPhotoSnapshot] = []
    private(set) var removedPhotoIDs: [UUID] = []
    private(set) var removedCustomerIDs: [UUID] = []

    init(snapshots: [CustomerPetPhotoSnapshot] = []) {
        snapshotsByPhotoID = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.photoID, $0) }
        )
    }

    func snapshot(
        customerID: UUID,
        petID: UUID
    ) -> CustomerPetPhotoSnapshot? {
        snapshotsByPhotoID.values.first { snapshot in
            snapshot.customerID == customerID && snapshot.petID == petID
        }
    }

    func snapshot(photo: CustomerPetPhoto) -> CustomerPetPhotoSnapshot? {
        guard let snapshot = snapshotsByPhotoID[photo.id],
              snapshot.customerID == photo.customerID,
              snapshot.petID == photo.petID,
              snapshot.storagePath == photo.storagePath else {
            return nil
        }

        return snapshot
    }

    func save(_ snapshot: CustomerPetPhotoSnapshot) {
        snapshotsByPhotoID[snapshot.photoID] = snapshot
        savedSnapshots.append(snapshot)
    }

    func remove(photoID: UUID) {
        snapshotsByPhotoID[photoID] = nil
        removedPhotoIDs.append(photoID)
    }

    func removeAll(customerID: UUID) {
        snapshotsByPhotoID = snapshotsByPhotoID.filter { _, snapshot in
            snapshot.customerID != customerID
        }
        removedCustomerIDs.append(customerID)
    }
}
