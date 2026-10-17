import Foundation
import Testing
@testable import Beckon

struct CustomerPetKeyboardFocusContractTests {
    @Test
    func petFormTargetsAreStableAndDistinct() {
        #expect(CustomerPetFormFocusTarget.name.rawValue == "customer.pets.form.name.container")
        #expect(
            CustomerPetFormFocusTarget.medicalNotes.rawValue
                == "customer.pets.form.medical-notes.container"
        )
        #expect(
            CustomerPetFormFocusTarget.groomingNotes.rawValue
                == "customer.pets.form.grooming-notes.container"
        )
        #expect(Set(CustomerPetFormFocusTarget.allCases.map(\.rawValue)).count == 3)
    }
}

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
    func petFormActionTracksCreateEditValidityAndDirtyState() {
        let customerID = UUID()
        let pet = Self.pet(customerID: customerID)
        let store = CustomerPetsStore(
            customerID: customerID,
            repository: CustomerPetRepositoryFake()
        )

        store.startEdit(pet)
        #expect(store.formActionTitle == "Save")
        #expect(!store.hasFormChanges)
        #expect(!store.canSaveForm)

        store.formName = "Mochi Updated"
        #expect(store.hasFormChanges)
        #expect(store.canSaveForm)

        store.formName = pet.name
        #expect(!store.hasFormChanges)
        #expect(!store.canSaveForm)

        store.addPendingFormPhoto(data: Data([0x01]), contentType: .jpeg)
        #expect(store.hasFormChanges)
        #expect(store.canSaveForm)

        store.startCreate()
        #expect(store.formActionTitle == "Create")
        #expect(!store.hasFormChanges)
        #expect(!store.canSaveForm)

        store.formName = "New Pet"
        #expect(store.hasFormChanges)
        #expect(store.canSaveForm)

        store.formName = " "
        #expect(store.hasFormChanges)
        #expect(!store.canSaveForm)
    }

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
    func selectingKnownBreedDoesNotConfirmCoatType() {
        let store = CustomerPetsStore(
            customerID: UUID(),
            repository: CustomerPetRepositoryFake()
        )

        store.updateFormBreed(.siberianHusky)

        #expect(store.formBreed == .siberianHusky)
        #expect(store.formCoatType == .notSure)
    }

    @Test @MainActor
    func unknownCoatIsNotInferredWhenSavingKnownBreed() async {
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository)
        store.formName = "Mochi"
        store.formBreed = .siberianHusky
        store.formCoatType = .notSure
        await store.savePet()
        #expect(repository.createCallCount == 1)
        #expect(repository.lastDraft?.coatType == nil)
    }

    @Test @MainActor
    func legacyMissingCoatStaysUnknownWhenEditing() {
        let pet = Self.pet(customerID: UUID(), breed: "Siberian Husky")
        let store = CustomerPetsStore(customerID: pet.customerID, repository: CustomerPetRepositoryFake())
        store.startEdit(pet)
        #expect(store.formCoatType == .notSure)
    }

    @Test @MainActor
    func explicitlyChosenCoatCarriesConfirmation() async {
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository)
        store.formName = "Mochi"
        store.formCoatType = .wire
        await store.savePet()
        #expect(repository.lastDraft?.coatTypeConfirmed == true)
    }

    @Test @MainActor
    func editingLegacyFactsDoesNotInventWeightOrConfirmCoat() async {
        let pet = Self.pet(customerID: UUID(), coatType: "wire")
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]))
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        await store.load()
        store.startEdit(pet)
        store.formName = "Mochi II"
        await store.savePet()
        #expect(repository.lastDraft?.weightLbs == nil)
        #expect(repository.lastDraft?.size == nil)
        #expect(repository.lastDraft?.coatTypeConfirmed == false)
        #expect(repository.updateCallCount == 1)
        #expect(repository.createCallCount == 0)
    }

    @Test(arguments: [(100.1, "Giant"), (100.001, "Giant"), (200.0, "Giant"), (2.5, "XS")]) @MainActor
    func fractionalWeightDoesNotRoundIntoAnotherSizeBand(weight: Double, size: String) async {
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository)
        store.formName = "Mochi"
        store.formWeightLbs = weight
        await store.savePet()
        #expect(repository.lastDraft?.weightLbs == weight)
        #expect(repository.lastDraft?.size == size)
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

        #expect(pet.accessibilitySummary == "Toy Poodle, Dog, 12.2 pounds, size S")
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

    @Test @MainActor
    func editingMissingPetNeverFallsBackToCreation() async {
        let repository = CustomerPetRepositoryFake()
        let pet = Self.pet(customerID: UUID())
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        store.startEdit(pet)
        store.formName = "Updated"
        await store.savePet()
        #expect(repository.createCallCount == 0)
        #expect(store.isShowingPetForm)
        #expect(store.formName == "Updated")
    }

    @Test @MainActor
    func latePhotoListCannotRestoreDeletedPetPhotos() async {
        let pet = Self.pet(customerID: UUID())
        let photo = Self.photo(customerID: pet.customerID, petID: pet.id)
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]), photosResult: .success([photo]))
        repository.suspendPhotos = true
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        let loading = Task { await store.load() }
        await repository.waitUntilPhotosRequested()
        await store.softDelete(pet)
        repository.resumePhotos()
        await loading.value
        #expect(store.pets.isEmpty)
        #expect(store.photos(for: pet).isEmpty)
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
            isActive: true,
            revision: UUID()
        )
    }

    @Test @MainActor
    func creationResponseLossSurvivesRestartWithSameIntent() async throws {
        let id = UUID()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CustomerPetRepositoryFake()
        repository.dropCreateReceiptOnce = true
        let first = CustomerPetsStore(customerID: id, repository: repository, pendingCreationDirectory: directory)
        first.startCreate()
        first.formName = "Original"
        await first.savePet()
        #expect(first.hasPendingCreation)
        first.cancelForm()
        let restored = CustomerPetsStore(customerID: id, repository: repository, pendingCreationDirectory: directory)
        restored.startCreate()
        #expect(restored.formName == "Original")
        restored.formName = "Must not replace intent"
        await restored.savePet()
        #expect(Set(repository.createOperationIDs).count == 1)
        #expect(repository.createdPets.count == 1)
        #expect(restored.pets.first?.name == "Original")
        #expect(!restored.hasPendingCreation)
    }

    @Test @MainActor
    func failedPendingPersistenceNeverSendsCreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1]).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository, pendingCreationDirectory: directory)
        store.startCreate(); store.formName = "Not sent"
        await store.savePet()
        #expect(repository.createCallCount == 0)
        #expect(store.formName == "Not sent")
    }

    @Test @MainActor
    func corruptAndFuturePendingFilesCannotBeOverwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        let repository = CustomerPetRepositoryFake()
        let seed = CustomerPetsStore(customerID: id, repository: repository, pendingCreationDirectory: directory)
        repository.dropCreateReceiptOnce = true
        seed.startCreate(); seed.formName = "Future record"
        await seed.savePet()
        var future = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        future["schemaVersion"] = 99
        let sent = repository.createCallCount
        for data in [Data("broken".utf8), try JSONSerialization.data(withJSONObject: future)] {
            try data.write(to: url)
            let store = CustomerPetsStore(customerID: id, repository: repository, pendingCreationDirectory: directory)
            store.startCreate(); store.formName = "Cannot replace"
            await store.savePet()
            #expect(repository.createCallCount == sent)
            #expect(try Data(contentsOf: url) == data)
            #expect(store.hasCreationRecoveryError)
        }
    }

    @Test @MainActor
    func failedPendingCleanupKeepsTheSameIntentBlocked() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let repository = CustomerPetRepositoryFake()
        repository.dropCreateReceiptOnce = true
        let store = CustomerPetsStore(customerID: id, repository: repository, pendingCreationDirectory: directory)
        store.startCreate(); store.formName = "Original"
        await store.savePet()
        let storage = PendingPetCreationStorage(customerID: id, directory: directory)
        let intent = try #require(storage.pending)
        try FileManager.default.removeItem(at: storage.url)
        #expect(throws: (any Error).self) { try storage.finish(operationID: intent.operationID) }
        #expect(storage.pending == intent)
        #expect(throws: CustomerPetRepositoryError.operationIntentChanged) {
            try storage.begin(PendingPetCreation(customerID: id, draft: intent.draft))
        }
    }

    @Test @MainActor
    func pendingCreationIsAccountScopedAndInvalidSessionCannotSend() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CustomerPetRepositoryFake()
        repository.dropCreateReceiptOnce = true
        var current = true
        let store = CustomerPetsStore(customerID: UUID(), repository: repository,
            pendingCreationDirectory: directory, sessionIsCurrent: { current })
        store.startCreate(); store.formName = "Private"
        await store.savePet()
        let other = CustomerPetsStore(customerID: UUID(), repository: repository, pendingCreationDirectory: directory)
        #expect(!other.hasPendingCreation)
        current = false
        await store.savePet()
        #expect(repository.createCallCount == 1)
        #expect(store.hasPendingCreation)
    }

    @Test @MainActor
    func refreshCannotReplaceTheRevisionCapturedByAnEditingForm() async {
        let pet = Self.pet(customerID: UUID())
        var changed = pet; changed.revision = UUID()
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]))
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        await store.load(); store.startEdit(pet); store.formName = "Draft"
        repository.petsResult = .success([changed])
        repository.updateResult = .failure(.revisionConflict)
        await store.load(); await store.savePet()
        #expect(repository.lastExpectedRevision == pet.revision)
        #expect(store.formName == "Draft")
        #expect(store.editNeedsReconciliation)
        #expect(!store.canSaveForm)
        repository.petsResult = .failure(.networkUnavailable)
        await store.reloadEditedPet()
        #expect(store.formName == "Draft")
        repository.petsResult = .success([changed])
        await store.reloadEditedPet()
        #expect(store.formName == pet.name)
        #expect(!store.editNeedsReconciliation)
    }

    @Test @MainActor
    func unknownEditResultMustBeReconciledBeforeRetry() async {
        let pet = Self.pet(customerID: UUID())
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]), updateResult: .failure(.networkUnavailable))
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        await store.load(); store.startEdit(pet); store.formName = "Draft"
        await store.savePet(); await store.savePet()
        #expect(repository.updateCallCount == 1)
        #expect(store.formName == "Draft")
        #expect(store.editNeedsReconciliation)
    }

    @Test @MainActor
    func oldListCannotReplaceSuccessfulEditOrDeletion() async {
        let pet = Self.pet(customerID: UUID())
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]))
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository)
        await store.load(); store.startEdit(pet); store.formName = "New Name"
        let gate = PetReplyGate<[CustomerPet]>()
        repository.loadHandler = { try await gate.value() }
        let loading = Task { await store.load() }
        await gate.waitForRequest()
        await store.savePet()
        gate.resolve(.success([pet])); await loading.value
        #expect(store.pets.first?.name == "New Name")
        let secondGate = PetReplyGate<[CustomerPet]>()
        repository.loadHandler = { try await secondGate.value() }
        let secondLoad = Task { await store.load() }
        await secondGate.waitForRequest(); await store.softDelete(pet)
        secondGate.resolve(.success([pet])); await secondLoad.value
        #expect(store.pets.isEmpty)
    }

    @Test @MainActor
    func oldListCannotHideCreationOrReplaceNewerLoad() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository, pendingCreationDirectory: directory)
        let first = PetReplyGate<[CustomerPet]>()
        repository.loadHandler = { try await first.value() }
        let loading = Task { await store.load() }; await first.waitForRequest()
        store.startCreate(); store.formName = "New pet"
        await store.savePet()
        first.resolve(.success([])); await loading.value
        #expect(store.pets.count == 1)
        let second = PetReplyGate<[CustomerPet]>()
        repository.loadHandler = { try await second.value() }
        let oldLoad = Task { await store.load() }; await second.waitForRequest()
        let newest = Self.pet(customerID: UUID())
        repository.loadHandler = { [newest] }
        await store.load()
        second.resolve(.success([])); await oldLoad.value
        #expect(store.pets == [newest])
    }

    @Test @MainActor
    func supersededLoadErrorDoesNotChangeNewLoadingOrErrorState() async {
        let repository = CustomerPetRepositoryFake()
        let store = CustomerPetsStore(customerID: UUID(), repository: repository)
        let first = PetReplyGate<[CustomerPet]>()
        let second = PetReplyGate<[CustomerPet]>()
        repository.loadHandler = { try await first.value() }
        let a = Task { await store.load() }; await first.waitForRequest()
        repository.loadHandler = { try await second.value() }
        let b = Task { await store.load() }; await second.waitForRequest()
        first.resolve(.failure(CustomerPetRepositoryError.networkUnavailable)); await a.value
        #expect(store.isLoading)
        #expect(store.errorMessage == nil)
        second.resolve(.success([])); await b.value
        #expect(!store.isLoading)
    }

    @Test @MainActor
    func latePhotoDownloadCannotWriteDeletedPhotoOrCache() async {
        let pet = Self.pet(customerID: UUID())
        let photo = Self.photo(customerID: pet.customerID, petID: pet.id)
        let gate = PetReplyGate<Data>()
        let repository = CustomerPetRepositoryFake(petsResult: .success([pet]), photosResult: .success([photo]))
        repository.photoHandler = { try await gate.value() }
        let cache = CustomerPetPhotoCacheFake()
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository, photoCache: cache)
        let loading = Task { await store.load() }; await gate.waitForRequest()
        await store.deletePhoto(photo)
        gate.resolve(.success(Data([9]))); await loading.value
        #expect(store.photoData(for: photo) == nil)
        #expect(cache.savedSnapshots.isEmpty)
    }

    @Test @MainActor
    func latePhotoDownloadCannotReplaceUploadedAvatarOrCrossSession() async {
        for changeSession in [false, true] {
            let pet = Self.pet(customerID: UUID())
            let old = Self.photo(customerID: pet.customerID, petID: pet.id)
            let new = Self.photo(customerID: pet.customerID, petID: pet.id)
            let gate = PetReplyGate<Data>()
            let repository = CustomerPetRepositoryFake(petsResult: .success([pet]),
                photosResult: .success([old]), uploadResult: .success(new))
            repository.photoHandler = { try await gate.value() }
            let cache = CustomerPetPhotoCacheFake()
            var current = true
            let store = CustomerPetsStore(customerID: pet.customerID, repository: repository,
                photoCache: cache, sessionIsCurrent: { current })
            let loading = Task { await store.load() }; await gate.waitForRequest()
            if changeSession { current = false }
            else { await store.uploadPhoto(pet: pet, data: Data([7]), contentType: .jpeg) }
            gate.resolve(.success(Data([9]))); await loading.value
            #expect(store.photoData(for: old) == nil)
            #expect(!cache.savedSnapshots.contains { $0.photoID == old.id })
            if changeSession { #expect(cache.savedSnapshots.isEmpty) }
            else { #expect(store.primaryPhotoData(for: pet) == Data([7])) }
        }
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
    var loadHandler: (@MainActor () async throws -> [CustomerPet])?
    var photoHandler: (@MainActor () async throws -> Data)?
    var dropCreateReceiptOnce = false
    private(set) var createOperationIDs: [UUID] = []
    private(set) var lastExpectedRevision: UUID?
    private(set) var createdPets: [UUID: CustomerPet] = [:]

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
        if let loadHandler { return try await loadHandler() }
        return try petsResult.get()
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
        operationID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPetSaveResult {
        createCallCount += 1
        lastCustomerID = customerID
        lastDraft = draft
        createOperationIDs.append(operationID)
        if let pet = createdPets[operationID] {
            return .init(petID: pet.id, resultRevision: pet.revision!, replayed: true, state: .active, pet: pet)
        }
        var pet = try createResult?.get() ?? CustomerPet(
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
            isActive: true,
            coatTypeSource: draft.coatType == nil ? "unknown" : (draft.coatTypeConfirmed ? "explicit" : "legacy_unverified"),
            mattingConfirmed: draft.mattingConfirmed
        )
        pet.revision = pet.revision ?? UUID()
        createdPets[operationID] = pet
        if dropCreateReceiptOnce {
            dropCreateReceiptOnce = false
            throw CustomerPetRepositoryError.networkUnavailable
        }
        return .init(petID: pet.id, resultRevision: pet.revision!, replayed: false, state: .active, pet: pet)
    }

    func updatePet(
        petID: UUID,
        expectedRevision: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        updateCallCount += 1
        lastDraft = draft
        lastExpectedRevision = expectedRevision

        if let updateResult {
            return try updateResult.get()
        }

        guard let pet = try petsResult.get().first(where: { $0.id == petID }) else {
            throw CustomerPetRepositoryError.petNotFound
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
            isActive: true,
            coatTypeSource: draft.coatType == nil ? "unknown" : (draft.coatTypeConfirmed ? "explicit" :
                (draft.coatType == pet.coatType && draft.species == pet.species && draft.breed == pet.breed ? pet.coatTypeSource : "legacy_unverified")),
            mattingConfirmed: draft.mattingConfirmed,
            revision: UUID()
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
        if let photoHandler { return try await photoHandler() }
        guard let result = photoDataResultsByPhotoID[photo.id] else {
            throw CustomerPetRepositoryError.unavailable
        }
        return try result.get()
    }
}

@MainActor
private final class PetReplyGate<Value: Sendable> {
    private var reply: CheckedContinuation<Value, any Error>?
    private var requested: CheckedContinuation<Void, Never>?
    func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            reply = continuation; requested?.resume(); requested = nil
        }
    }
    func waitForRequest() async {
        if reply != nil { return }
        await withCheckedContinuation { requested = $0 }
    }
    func resolve(_ result: Result<Value, any Error>) {
        reply?.resume(with: result); reply = nil
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
