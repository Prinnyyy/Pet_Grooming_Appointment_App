import Foundation
import Testing
@testable import Beckon

@MainActor
struct PetFlowSandboxTests {
    @Test
    func previewIsolationRequiresXcodesExplicitEnvironmentFlag() {
        #expect(AppLaunchConfiguration(arguments: [], environment: [:]).isSwiftUIPreview == false)
        #expect(AppLaunchConfiguration(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "0"])
            .isSwiftUIPreview == false)
        #expect(AppLaunchConfiguration(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
            .isSwiftUIPreview)
    }

    @Test
    func previewPetsCanBeEditedByTheProductionStore() async throws {
        let repository = CustomerPetsPreviewRepository()
        repository.mutationDelay = .zero
        let pet = try #require(try await repository.pets(customerID: repository.customerID).first)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomerPetsStore(customerID: pet.customerID, repository: repository,
            photoCache: FileCustomerPetPhotoCache(directoryURL: directory.appendingPathComponent("photos")),
            pendingCreationDirectory: directory.appendingPathComponent("pending"))
        await store.load()
        store.startEdit(pet)
        store.formName = "Mochi Updated"
        #expect(store.canSaveForm)
        await store.savePet()
        #expect(!store.isShowingPetForm)
        #expect(store.noticeMessage == "Mochi Updated was updated.")
        await store.load()
        #expect(store.pets.first(where: { $0.id == pet.id })?.name == "Mochi Updated")
    }

    @Test
    func previewUpdateSurvivesReadingAgain() async throws {
        let repository = CustomerPetsPreviewRepository()
        repository.mutationDelay = .zero
        let pet = try #require(try await repository.pets(customerID: repository.customerID).first)
        let draft = CustomerPetDraft(name: "Mochi Updated", species: pet.species, breed: pet.breed,
            coatType: pet.coatType, size: pet.size, weightLbs: pet.weightLbs, birthday: pet.birthday,
            temperament: pet.temperament, medicalNotes: pet.medicalNotes, groomingNotes: pet.groomingNotes)
        let updated = try await repository.updatePet(petID: pet.id,
            expectedRevision: pet.revision ?? UUID(), draft: draft)
        #expect(updated.revision != nil)
        let reloaded = try await repository.pet(customerID: pet.customerID, petID: pet.id)
        #expect(reloaded == updated)
    }

    @Test
    func cancellingDoesNotSaveAndInvalidInputStaysInTheForm() async throws {
        let session = CustomerPetsFlowSandboxSession()
        defer { session.invalidate() }
        session.repository.mutationDelay = .zero
        let store = session.store
        await store.load()
        let pet = try #require(store.pets.first)
        store.startEdit(pet)
        store.formName = "Unsaved"
        store.cancelForm()
        await store.load()
        #expect(store.pets.first == pet)
        store.startEdit(pet)
        store.formName = " "
        #expect(!store.canSaveForm)
        await store.savePet()
        #expect(store.isShowingPetForm)
        #expect(store.errorMessage != nil)
        #expect(store.pets.first == pet)
    }

    @Test
    func unconfirmedSaveUsesProductionRecoveryThenCanSaveAgain() async throws {
        let session = CustomerPetsFlowSandboxSession(failsFirstSave: true)
        defer { session.invalidate() }
        session.repository.mutationDelay = .zero
        let store = session.store
        await store.load()
        let pet = try #require(store.pets.first)
        store.startEdit(pet)
        store.formName = "Mochi Updated"
        await store.savePet()
        #expect(store.isShowingPetForm)
        #expect(store.editNeedsReconciliation)
        #expect(store.formName == "Mochi Updated")
        #expect(store.pets.first == pet)
        await store.reloadEditedPet()
        #expect(!store.editNeedsReconciliation)
        store.formName = "Mochi Updated"
        await store.savePet()
        #expect(!store.isShowingPetForm)
        await store.load()
        #expect(store.pets.first?.name == "Mochi Updated")
    }

    @Test
    func sessionsAreIsolatedAndResetInvalidatesOutstandingSaves() async throws {
        let first = CustomerPetsFlowSandboxSession()
        let second = CustomerPetsFlowSandboxSession()
        defer { first.invalidate(); second.invalidate() }
        #expect(first.directory != second.directory)
        #expect(first.repository.customerID != second.repository.customerID)
        #expect(first.directory.path.contains("/BeckonPetFlowSandbox/"))
        await first.store.load()
        await second.store.load()
        let pet = try #require(first.store.pets.first)
        first.store.startEdit(pet)
        first.store.formName = "Changed"
        let save = Task { await first.store.savePet() }
        for _ in 0..<100 where !first.store.isSaving { await Task.yield() }
        try #require(first.store.isSaving)
        first.invalidate()
        await save.value
        #expect(first.store.pets.first == pet)
        #expect(first.store.noticeMessage == nil)
        #expect(second.store.pets.first?.name == "Mochi")
        #expect(!FileManager.default.fileExists(atPath: first.directory.path))
    }

    @Test
    func exposedCreatePhotoAndRemoveActionsStayInsideTheSandbox() async throws {
        let session = CustomerPetsFlowSandboxSession()
        defer { session.invalidate() }
        session.repository.mutationDelay = .zero
        let store = session.store
        await store.load()
        store.startCreate()
        store.formName = "Preview Pet"
        await store.savePet()
        #expect(!store.hasPendingCreation)
        let pet = try #require(store.pets.first(where: { $0.name == "Preview Pet" }))
        let data = Data([1, 2, 3])
        let photo = try await session.repository.uploadPhoto(customerID: pet.customerID,
            petID: pet.id, data: data, contentType: .jpeg, caption: nil)
        await store.load()
        #expect(store.primaryPhotoData(for: pet) == data)
        let files = try FileManager.default.contentsOfDirectory(
            at: session.directory.appendingPathComponent("photos"), includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        try await session.repository.deletePhoto(photo)
        await store.softDelete(pet)
        await store.load()
        #expect(!store.pets.contains(where: { $0.id == pet.id }))
        #expect(try await session.repository.photos(customerID: pet.customerID).isEmpty)
        await #expect(throws: CustomerPetRepositoryError.notAllowed) {
            try await session.repository.pets(customerID: UUID())
        }
    }
}
