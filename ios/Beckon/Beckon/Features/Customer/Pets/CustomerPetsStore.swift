import Foundation
import Observation

nonisolated enum CustomerPetFormConstraints {
    static let nameMaximumLength = 20
    static let notesMaximumLength = 2_000
}

private struct CustomerPetFormSnapshot: Equatable {
    let name: String
    let species: CustomerPetSpecies
    let breed: CustomerPetBreed
    let coatType: CustomerPetCoatType
    let coatTypeConfirmed: Bool
    let mattingConfirmed: Bool?
    let weightLbs: Double
    let weightIsKnown: Bool
    let birthdayDate: Date?
    let temperament: CustomerPetTemperament
    let medicalNotes: String
    let groomingNotes: String
    let pendingPhotoData: Data?
    let pendingPhotoContentType: CustomerPetPhotoContentType?
}

@MainActor
@Observable
final class CustomerPetsStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024

    private let customerID: UUID
    private let repository: any CustomerPetRepository
    private let photoCache: any CustomerPetPhotoCaching
    private let debugRecorder: AppDebugEventRecorder?
    private let creationStorage: PendingPetCreationStorage
    private let sessionIsCurrent: @MainActor () -> Bool
    private var loadID = UUID()
    private var mutationRevision = 0
    private var editingRevision: UUID?
    private(set) var editNeedsReconciliation = false
#if DEBUG && targetEnvironment(simulator)
    private var droppedCreationReceipt = false
#endif

    var hasPendingCreation: Bool { creationStorage.pending != nil }
    #if DEBUG
    func seedSandboxPendingCreation(operationID: UUID) throws {
        try creationStorage.begin(.init(customerID: customerID, operationID: operationID, draft: makeDraft()))
    }
    #endif
    var hasCreationRecoveryError: Bool { creationStorage.recoveryError != nil }
    var formIsFrozen: Bool { isSaving || isUploading || (editingPetID == nil && hasPendingCreation) }

    private(set) var pets: [CustomerPet] = []
    private(set) var photosByPetID: [UUID: [CustomerPetPhoto]] = [:]
    private(set) var photoDataByPhotoID: [UUID: Data] = [:]
    private var cachedAvatarDataByPetID: [UUID: Data] = [:]
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isUploading = false

    var errorMessage: String?
    var noticeMessage: String?
    var isShowingPetForm = false
    var editingPetID: UUID?

    var formName = ""
    var formSpecies: CustomerPetSpecies = .dog
    var formBreed: CustomerPetBreed = .unspecified
    var formCoatType: CustomerPetCoatType = .notSure {
        didSet { formCoatTypeConfirmed = formCoatType != .notSure }
    }
    private(set) var formCoatTypeConfirmed = false
    var formMattingConfirmed: Bool?
    var formWeightLbs = 20.0 {
        didSet { formWeightIsKnown = true }
    }
    var formWeightIsKnown = false
    var formBirthdayDate: Date?
    var formTemperament: CustomerPetTemperament = .notSure
    var formMedicalNotes = ""
    var formGroomingNotes = ""
    private(set) var pendingFormPhotos: [PendingCustomerPetPhoto] = []
    private var formBaseline: CustomerPetFormSnapshot?

    var formTitle: String {
        editingPetID == nil ? "Add pet" : "Edit Pet"
    }

    var formActionTitle: String {
        editingPetID == nil ? (hasPendingCreation ? "Confirm Save" : "Create") : "Save"
    }

    var hasFormChanges: Bool {
        guard let formBaseline else { return false }
        return currentFormSnapshot != formBaseline
    }

    var canSaveForm: Bool {
        guard !isSaving, !isUploading, !editNeedsReconciliation, sessionIsCurrent() else { return false }
        if editingPetID == nil {
            if hasCreationRecoveryError { return false }
            if hasPendingCreation { return true }
        }
        return hasFormChanges && formIsValid
    }

    var formAvatarPhotoData: Data? {
        if let pendingPhoto = pendingFormPhotos.last {
            return pendingPhoto.data
        }

        guard let editingPetID,
              let pet = pets.first(where: { $0.id == editingPetID }) else {
            return nil
        }

        return primaryPhotoData(for: pet)
    }

    var isBusy: Bool {
        isLoading || isSaving || isUploading
    }

    init(
        customerID: UUID,
        repository: any CustomerPetRepository,
        photoCache: any CustomerPetPhotoCaching = FileCustomerPetPhotoCache.shared,
        debugRecorder: AppDebugEventRecorder? = nil,
        pendingCreationDirectory: URL? = nil,
        sessionIsCurrent: @escaping @MainActor () -> Bool = { true }
    ) {
        self.customerID = customerID
        self.repository = repository
        self.photoCache = photoCache
        self.debugRecorder = debugRecorder
        self.creationStorage = PendingPetCreationStorage(customerID: customerID, directory: pendingCreationDirectory)
        self.sessionIsCurrent = sessionIsCurrent
    }

    func load() async {
        guard !isSaving, !isUploading, sessionIsCurrent(), !Task.isCancelled else { return }
        let operation = UUID()
        loadID = operation
        let revision = mutationRevision
        defer { if loadID == operation { isLoading = false } }
        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil

        do {
            let loadedPets = try await repository.pets(customerID: customerID)
            guard isCurrentLoad(operation, revision: revision) else { return }
            cachedAvatarDataByPetID = cachedAvatarDataMap(for: loadedPets)
            pets = loadedPets

            let photos = try await repository.photos(customerID: customerID)
            guard isCurrentLoad(operation, revision: revision) else { return }
            photosByPetID = Dictionary(grouping: photos, by: \.petID)
            photoDataByPhotoID = cachedPhotoDataMap(for: photos)
            clearStaleCachedAvatarData()
            isLoading = false

            let downloadedPhotoData = await photoDataMap(for: photos)
            guard isCurrentLoad(operation, revision: revision) else { return }
            for photo in photos {
                if let data = downloadedPhotoData[photo.id] { savePhotoCache(photo: photo, data: data) }
            }
            photoDataByPhotoID.merge(downloadedPhotoData) { _, downloaded in
                downloaded
            }
            recordStoreSuccess(
                "load",
                startedAt: startedAt,
                metadata: [
                    "petCount": "\(pets.count)",
                    "photoCount": "\(photosByPetID.values.reduce(0) { $0 + $1.count })",
                    "downloadedPhotoCount": "\(downloadedPhotoData.count)",
                ]
            )
        } catch CustomerPetRepositoryError.cancelled {
            guard isCurrentLoad(operation, revision: revision) else { return }
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            guard isCurrentLoad(operation, revision: revision) else { return }
            isLoading = false
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            guard isCurrentLoad(operation, revision: revision) else { return }
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
            guard isCurrentLoad(operation, revision: revision) else { return }
            isLoading = false
            errorMessage = message(for: .unavailable, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    private func isCurrentLoad(_ operation: UUID, revision: Int) -> Bool {
        sessionIsCurrent() && !Task.isCancelled && operation == loadID && revision == mutationRevision
    }

    private func beginMutation() {
        mutationRevision += 1
        loadID = UUID()
        isLoading = false
    }

    func photos(for pet: CustomerPet) -> [CustomerPetPhoto] {
        photosByPetID[pet.id, default: []]
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    $0.fileName < $1.fileName
                } else {
                    $0.sortOrder < $1.sortOrder
                }
            }
    }

    func photoData(for photo: CustomerPetPhoto) -> Data? {
        photoDataByPhotoID[photo.id]
    }

    func primaryPhotoData(for pet: CustomerPet) -> Data? {
        let photos = photosByPetID[pet.id, default: []]

        if let newestAvailableData = photos.reversed().lazy.compactMap({
            self.photoData(for: $0)
        }).first {
            return newestAvailableData
        }

        return cachedAvatarDataByPetID[pet.id]
    }

    func startCreate() {
        guard !isSaving, !isUploading, sessionIsCurrent() else { return }
        editingPetID = nil
        editingRevision = nil
        editNeedsReconciliation = false
        resetForm()
        if let pending = creationStorage.pending { applyDraft(pending.draft) }
        captureFormBaseline()
        errorMessage = nil
        if hasPendingCreation { errorMessage = "Confirm the previous save before creating another pet." }
        if hasCreationRecoveryError { errorMessage = "The pending pet record could not be opened. It has been kept; a new creation cannot replace it." }
        noticeMessage = nil
        isShowingPetForm = true
    }

    func startEdit(_ pet: CustomerPet) {
        guard !isSaving, !isUploading, sessionIsCurrent() else { return }
        editingPetID = pet.id
        editingRevision = pet.revision
        editNeedsReconciliation = pet.revision == nil
        formName = pet.name
        formSpecies = CustomerPetSpecies(storedValue: pet.species) ?? .dog
        let breed = pet.breed.flatMap(CustomerPetBreed.init(storedValue:)) ?? .unspecified
        formBreed = CustomerPetBreed.options(for: formSpecies).contains(breed)
            ? breed
            : .unspecified
        formCoatType = pet.coatType
            .flatMap(CustomerPetCoatType.init(storedValue:))
            ?? .notSure
        formCoatTypeConfirmed = pet.coatTypeSource == "explicit" && formCoatType != .notSure
        formMattingConfirmed = pet.mattingConfirmed
        formWeightLbs = pet.weightLbs ?? 20
        formWeightIsKnown = pet.weightLbs != nil
        formBirthdayDate = pet.birthday.flatMap(Self.date)
        formTemperament = pet.temperament
            .flatMap(CustomerPetTemperament.init(storedValue:)) ?? .notSure
        formMedicalNotes = pet.medicalNotes ?? ""
        formGroomingNotes = pet.groomingNotes ?? ""
        pendingFormPhotos = []
        captureFormBaseline()
        errorMessage = nil
        if editNeedsReconciliation { errorMessage = "Reload this pet before saving." }
        noticeMessage = nil
        isShowingPetForm = true
    }

    func cancelForm() {
        isShowingPetForm = false
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !self.isShowingPetForm else { return }
            self.editingPetID = nil
            self.resetForm()
        }
    }

    func updateFormSpecies(_ species: CustomerPetSpecies) {
        formSpecies = species
        if !CustomerPetBreed.options(for: species).contains(formBreed) {
            formBreed = .unspecified
        }
        formCoatType = .notSure
    }

    func updateFormBreed(_ breed: CustomerPetBreed) {
        formBreed = breed
        formCoatType = .notSure
    }

    func addPendingFormPhoto(
        data: Data,
        contentType: CustomerPetPhotoContentType
    ) {
        guard data.count <= Self.maximumPhotoBytes else {
            errorMessage = "Choose a photo smaller than 10 MB."
            return
        }

        pendingFormPhotos = [
            PendingCustomerPetPhoto(
                data: data,
                contentType: contentType
            )
        ]
    }

    func removePendingFormPhoto(_ photo: PendingCustomerPetPhoto) {
        pendingFormPhotos.removeAll { $0.id == photo.id }
    }

    func savePet() async {
        guard !isSaving, !isUploading, !editNeedsReconciliation, sessionIsCurrent(), !Task.isCancelled else { return }

        let startedAt = Date()
        recordStoreStart("savePet")
        errorMessage = nil
        noticeMessage = nil

        let draft: CustomerPetDraft
        do {
            draft = try (editingPetID == nil ? creationStorage.pending?.draft : nil) ?? makeDraft()
        } catch let error as CustomerPetFormError {
            errorMessage = error.message
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning
            )
            return
        } catch {
            errorMessage = "Check the pet details and try again."
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt,
                level: .warning
            )
            return
        }

        isSaving = true
        beginMutation()
        defer { isSaving = false }

        do {
            let savedPet: CustomerPet
            let action: String
            if let editingPetID {
                guard pets.contains(where: { $0.id == editingPetID }) else { throw CustomerPetRepositoryError.petNotFound }
                guard let editingRevision else { throw CustomerPetRepositoryError.clientUpdateRequired }
                let pet = try await repository.updatePet(
                    petID: editingPetID,
                    expectedRevision: editingRevision,
                    draft: draft
                )
                guard sessionIsCurrent(), !Task.isCancelled else { throw CustomerPetRepositoryError.cancelled }
                replace(pet)
                savedPet = pet
                action = "updated"
            } else {
                let intent = creationStorage.pending ?? PendingPetCreation(customerID: customerID, draft: draft)
                try creationStorage.begin(intent)
                let result = try await repository.createPet(
                    customerID: customerID,
                    operationID: intent.operationID,
                    draft: draft
                )
#if DEBUG && targetEnvironment(simulator)
                if !droppedCreationReceipt,
                   ProcessInfo.processInfo.arguments.contains("--beckon-testops-pet-drop-receipt"),
                   ProcessInfo.processInfo.arguments.contains("--beckon-testops-run-id") {
                    droppedCreationReceipt = true
                    throw CustomerPetRepositoryError.networkUnavailable
                }
#endif
                guard sessionIsCurrent(), !Task.isCancelled else { throw CustomerPetRepositoryError.cancelled }
                if result.state == .unavailable {
                    pets.removeAll { $0.id == result.petID }
                    try creationStorage.finish(operationID: intent.operationID)
                    noticeMessage = "The previous creation was confirmed, but that pet has since been removed."
                    isShowingPetForm = false
                    resetForm()
                    return
                }
                guard let pet = result.pet, pet.id == result.petID, pet.customerID == customerID else {
                    throw CustomerPetRepositoryError.unavailable
                }
                replace(pet)
                try creationStorage.finish(operationID: intent.operationID)
                savedPet = pet
                action = result.replayed ? "confirmed" : "added"
            }

            let uploadedPhotoCount = await uploadPendingFormPhotos(for: savedPet)
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            if uploadedPhotoCount > 0 {
                noticeMessage = "\(savedPet.name) was \(action) with a new avatar."
            } else {
                noticeMessage = "\(savedPet.name) was \(action)."
            }
            isShowingPetForm = false
            editingPetID = nil
            resetForm()
            recordStoreSuccess(
                "savePet",
                startedAt: startedAt,
                metadata: [
                    "action": action,
                    "petID": savedPet.id.uuidString,
                    "uploadedPhotoCount": "\(uploadedPhotoCount)",
                ]
            )
        } catch CustomerPetRepositoryError.cancelled {
            guard sessionIsCurrent() else { return }
            markUnresolvedSave()
            recordStoreCancelled("savePet", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            guard sessionIsCurrent() else { return }
            errorMessage = message(for: error, action: "save")
            switch error {
            case .revisionConflict, .petNotFound, .clientUpdateRequired:
                if editingPetID != nil { editNeedsReconciliation = true }
            case .networkUnavailable, .cancelled, .unavailable: markUnresolvedSave()
            case .invalidInput:
                if let pending = creationStorage.pending, editingPetID == nil {
                    do { try creationStorage.finish(operationID: pending.operationID) }
                    catch { markUnresolvedSave() }
                }
            default: break
            }
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            guard sessionIsCurrent() else { return }
            markUnresolvedSave()
            recordStoreCancelled("savePet", startedAt: startedAt)
        } catch {
            guard sessionIsCurrent() else { return }
            errorMessage = message(for: .unavailable, action: "save")
            markUnresolvedSave()
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    private func markUnresolvedSave() {
        if editingPetID != nil {
            editNeedsReconciliation = true
            errorMessage = "We could not confirm the save. Your edits are still here. Reload the saved pet before saving again."
        } else if hasPendingCreation {
            errorMessage = "We could not confirm the save. Confirm Save will check the same creation, not create another pet."
        }
    }

    func reloadEditedPet() async {
        guard let id = editingPetID, !isSaving, !isUploading, sessionIsCurrent(), !Task.isCancelled else { return }
        isSaving = true
        beginMutation()
        defer { isSaving = false }
        do {
            let pet = try await repository.pet(customerID: customerID, petID: id)
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            guard let pet else { throw CustomerPetRepositoryError.petNotFound }
            replace(pet)
            isSaving = false
            startEdit(pet)
        } catch {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = "Could not reload the saved pet. Your edits are still here."
        }
    }

    private func applyDraft(_ draft: CustomerPetDraft) {
        formName = draft.name
        formSpecies = CustomerPetSpecies(storedValue: draft.species) ?? .dog
        formBreed = draft.breed.flatMap(CustomerPetBreed.init(storedValue:)) ?? .unspecified
        formCoatType = draft.coatType.flatMap(CustomerPetCoatType.init(storedValue:)) ?? .notSure
        formCoatTypeConfirmed = draft.coatTypeConfirmed
        formMattingConfirmed = draft.mattingConfirmed
        formWeightLbs = draft.weightLbs ?? 20
        formWeightIsKnown = draft.weightLbs != nil
        formBirthdayDate = draft.birthday.flatMap(Self.date)
        formTemperament = draft.temperament.flatMap(CustomerPetTemperament.init(storedValue:)) ?? .notSure
        formMedicalNotes = draft.medicalNotes ?? ""
        formGroomingNotes = draft.groomingNotes ?? ""
    }

    func softDelete(_ pet: CustomerPet) async {
        guard !isSaving, !isUploading, sessionIsCurrent(), !Task.isCancelled else { return }
        beginMutation()

        let startedAt = Date()
        recordStoreStart("softDelete", metadata: ["petID": pet.id.uuidString])
        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.softDeletePet(pet)
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            pets.removeAll { $0.id == pet.id }
            for photo in photosByPetID[pet.id, default: []] {
                photoDataByPhotoID[photo.id] = nil
                photoCache.remove(photoID: photo.id)
            }
            photosByPetID[pet.id] = nil
            cachedAvatarDataByPetID[pet.id] = nil
            noticeMessage = "\(pet.name) was removed."
            recordStoreSuccess("softDelete", startedAt: startedAt)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("softDelete", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: error, action: "delete")
            recordStoreFailure(
                "softDelete",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("softDelete", startedAt: startedAt)
        } catch {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: .unavailable, action: "delete")
            recordStoreFailure(
                "softDelete",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func uploadPhoto(
        pet: CustomerPet,
        data: Data,
        contentType: CustomerPetPhotoContentType
    ) async {
        guard !isUploading, !isSaving, sessionIsCurrent(), !Task.isCancelled else { return }
        beginMutation()

        guard data.count <= Self.maximumPhotoBytes else {
            errorMessage = "Choose a photo smaller than 10 MB."
            return
        }

        let startedAt = Date()
        recordStoreStart("uploadPhoto", metadata: ["petID": pet.id.uuidString])
        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            _ = try await replaceAvatarPhoto(
                for: pet,
                data: data,
                contentType: contentType
            )
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            noticeMessage = "\(pet.name)'s avatar was updated."
            recordStoreSuccess("uploadPhoto", startedAt: startedAt)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("uploadPhoto", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: error, action: "upload")
            recordStoreFailure(
                "uploadPhoto",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("uploadPhoto", startedAt: startedAt)
        } catch {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: .unavailable, action: "upload")
            recordStoreFailure(
                "uploadPhoto",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async {
        guard !isUploading, !isSaving, sessionIsCurrent(), !Task.isCancelled else { return }
        beginMutation()

        let startedAt = Date()
        recordStoreStart("deletePhoto", metadata: ["photoID": photo.id.uuidString])
        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePhoto(photo)
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            photosByPetID[photo.petID]?.removeAll { $0.id == photo.id }
            photoDataByPhotoID[photo.id] = nil
            photoCache.remove(photoID: photo.id)
            refreshCachedAvatarDataAfterPhotoRemoval(petID: photo.petID)
            noticeMessage = "Photo was deleted."
            recordStoreSuccess("deletePhoto", startedAt: startedAt)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("deletePhoto", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: error, action: "delete photo")
            recordStoreFailure(
                "deletePhoto",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("deletePhoto", startedAt: startedAt)
        } catch {
            guard sessionIsCurrent(), !Task.isCancelled else { return }
            errorMessage = message(for: .unavailable, action: "delete photo")
            recordStoreFailure(
                "deletePhoto",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    private func replace(_ pet: CustomerPet) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else {
            pets.insert(pet, at: 0)
            return
        }
        pets[index] = pet
    }

    private func photoDataMap(
        for photos: [CustomerPetPhoto]
    ) async -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            guard let data = try? await repository.photoData(photo) else {
                continue
            }
            dataByID[photo.id] = data
        }
        return dataByID
    }

    private func cachedAvatarDataMap(
        for pets: [CustomerPet]
    ) -> [UUID: Data] {
        var dataByPetID: [UUID: Data] = [:]
        for pet in pets {
            guard let snapshot = photoCache.snapshot(
                customerID: customerID,
                petID: pet.id
            ) else {
                continue
            }
            dataByPetID[pet.id] = snapshot.data
        }
        return dataByPetID
    }

    private func cachedPhotoDataMap(
        for photos: [CustomerPetPhoto]
    ) -> [UUID: Data] {
        var dataByID: [UUID: Data] = [:]
        for photo in photos {
            guard let snapshot = photoCache.snapshot(photo: photo) else {
                continue
            }
            dataByID[photo.id] = snapshot.data
            cachedAvatarDataByPetID[photo.petID] = snapshot.data
        }
        return dataByID
    }

    private func clearStaleCachedAvatarData() {
        for pet in pets where photosByPetID[pet.id, default: []].isEmpty {
            cachedAvatarDataByPetID[pet.id] = nil
        }
    }

    private func refreshCachedAvatarDataAfterPhotoRemoval(petID: UUID) {
        let remainingPhotos = photosByPetID[petID, default: []]
        guard !remainingPhotos.isEmpty else {
            cachedAvatarDataByPetID[petID] = nil
            return
        }

        if let newestAvailableData = remainingPhotos.reversed().lazy.compactMap({
            self.photoData(for: $0)
        }).first {
            cachedAvatarDataByPetID[petID] = newestAvailableData
        }
    }

    private func resetForm() {
        formName = ""
        formSpecies = .dog
        formBreed = .unspecified
        formCoatType = .notSure
        formWeightLbs = 20
        formWeightIsKnown = false
        formMattingConfirmed = nil
        formBirthdayDate = nil
        formTemperament = .notSure
        formMedicalNotes = ""
        formGroomingNotes = ""
        pendingFormPhotos = []
        formBaseline = nil
    }

    private var currentFormSnapshot: CustomerPetFormSnapshot {
        CustomerPetFormSnapshot(
            name: formName,
            species: formSpecies,
            breed: formBreed,
            coatType: formCoatType,
            coatTypeConfirmed: formCoatTypeConfirmed,
            mattingConfirmed: formMattingConfirmed,
            weightLbs: formWeightLbs,
            weightIsKnown: formWeightIsKnown,
            birthdayDate: formBirthdayDate,
            temperament: formTemperament,
            medicalNotes: formMedicalNotes,
            groomingNotes: formGroomingNotes,
            pendingPhotoData: pendingFormPhotos.last?.data,
            pendingPhotoContentType: pendingFormPhotos.last?.contentType
        )
    }

    private var formIsValid: Bool {
        let nameCount = formName.trimmingCharacters(in: .whitespacesAndNewlines).count
        let medicalNotesCount = formMedicalNotes
            .trimmingCharacters(in: .whitespacesAndNewlines).count
        let groomingNotesCount = formGroomingNotes
            .trimmingCharacters(in: .whitespacesAndNewlines).count

        return (1...CustomerPetFormConstraints.nameMaximumLength).contains(nameCount)
            && medicalNotesCount <= CustomerPetFormConstraints.notesMaximumLength
            && groomingNotesCount <= CustomerPetFormConstraints.notesMaximumLength
    }

    private func captureFormBaseline() {
        formBaseline = currentFormSnapshot
    }

    private func makeDraft() throws -> CustomerPetDraft {
        let name = try required(
            formName,
            field: "Pet name",
            range: 1...80
        )
        if formWeightIsKnown {
            guard formWeightLbs.isFinite, formWeightLbs > 0 else {
                throw CustomerPetFormError(message: "Enter a valid pet weight.")
            }
        }
        if !CustomerPetBreed.options(for: formSpecies).contains(formBreed) {
            formBreed = .unspecified
        }
        let coatType = formCoatType == .notSure
            ? nil
            : formCoatType
        let size = CustomerPetSizeCode.code(forWeightLbs: formWeightLbs)

        return CustomerPetDraft(
            name: name,
            species: formSpecies.rawValue,
            breed: formBreed.rawValue,
            coatType: coatType?.rawValue,
            size: formWeightIsKnown ? size.rawValue : nil,
            weightLbs: formWeightIsKnown ? formWeightLbs : nil,
            birthday: formBirthdayDate.map(Self.dateString),
            temperament: formTemperament.rawValue,
            medicalNotes: try optional(
                formMedicalNotes,
                field: "Medical notes",
                maximum: CustomerPetFormConstraints.notesMaximumLength
            ),
            groomingNotes: try optional(
                formGroomingNotes,
                field: "Grooming notes",
                maximum: CustomerPetFormConstraints.notesMaximumLength
            ),
            coatTypeConfirmed: formCoatTypeConfirmed,
            mattingConfirmed: formMattingConfirmed
        )
    }

    private func required(
        _ value: String,
        field: String,
        range: ClosedRange<Int>
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard range.contains(trimmed.count) else {
            throw CustomerPetFormError(
                message: "\(field) must be \(range.lowerBound)–\(range.upperBound) characters."
            )
        }
        return trimmed
    }

    private func optional(
        _ value: String,
        field: String,
        maximum: Int
    ) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maximum else {
            throw CustomerPetFormError(
                message: "\(field) must be \(maximum) characters or fewer."
            )
        }
        return trimmed
    }

    private static func date(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func uploadPendingFormPhotos(for pet: CustomerPet) async -> Int {
        guard !pendingFormPhotos.isEmpty else { return 0 }

        let photo = pendingFormPhotos.last
        guard let photo else { return 0 }

        var failed = false
        do {
            _ = try await replaceAvatarPhoto(
                for: pet,
                data: photo.data,
                contentType: photo.contentType
            )
        } catch {
            failed = true
        }

        guard sessionIsCurrent(), !Task.isCancelled else { return 0 }
        pendingFormPhotos = []
        if failed {
            errorMessage = "Pet was saved, but the avatar could not upload."
        }
        return failed ? 0 : 1
    }

    private func replaceAvatarPhoto(
        for pet: CustomerPet,
        data: Data,
        contentType: CustomerPetPhotoContentType
    ) async throws -> CustomerPetPhoto {
        let replacedPhotos = photosByPetID[pet.id, default: []]
        let photo = try await repository.uploadPhoto(
            customerID: customerID,
            petID: pet.id,
            data: data,
            contentType: contentType,
            caption: nil
        )

        guard sessionIsCurrent(), !Task.isCancelled else { throw CustomerPetRepositoryError.cancelled }

        photosByPetID[pet.id] = [photo]
        photoDataByPhotoID[photo.id] = data
        cachedAvatarDataByPetID[pet.id] = data
        savePhotoCache(photo: photo, data: data)

        for replacedPhoto in replacedPhotos where replacedPhoto.id != photo.id {
            guard sessionIsCurrent(), !Task.isCancelled else { break }
            photoDataByPhotoID[replacedPhoto.id] = nil
            photoCache.remove(photoID: replacedPhoto.id)
            try? await repository.deletePhoto(replacedPhoto)
        }

        return photo
    }

    private func savePhotoCache(
        photo: CustomerPetPhoto,
        data: Data
    ) {
        cachedAvatarDataByPetID[photo.petID] = data
        photoCache.save(
            CustomerPetPhotoSnapshot(
                customerID: photo.customerID,
                petID: photo.petID,
                photoID: photo.id,
                storagePath: photo.storagePath,
                data: data
            )
        )
    }

    private func message(
        for error: CustomerPetRepositoryError,
        action: String
    ) -> String {
        switch error {
        case .notAllowed:
            "This account cannot \(action) customer pets."
        case .networkUnavailable:
            "Check your connection and try again."
        case .cancelled:
            "The pet action was cancelled."
        case .unavailable:
            "We could not \(action) pet information. Please try again."
        case .revisionConflict:
            "This pet was changed elsewhere. Your edits are still here. Reload the saved pet before saving again."
        case .operationIntentChanged:
            "This creation is already associated with different details. Confirm the original save first."
        case .petNotFound:
            "This pet is no longer available. Your edits have not been saved."
        case .clientUpdateRequired:
            "Reload the saved pet or update the app before saving."
        case .invalidInput:
            "Check the pet details and try again."
        }
    }

    private var debugScope: String {
        "customer.pets"
    }

    private func recordStoreStart(
        _ operation: String,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        eventMetadata["customerID"] = customerID.uuidString
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerPetsStore.\(operation)",
            scope: debugScope,
            message: "start",
            metadata: eventMetadata
        )
    }

    private func recordStoreSuccess(
        _ operation: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerPetsStore.\(operation)",
            scope: debugScope,
            message: "success",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
    }

    private func recordStoreFailure(
        _ operation: String,
        error: any Error,
        mappedMessage: String?,
        startedAt: Date,
        level: AppDebugEventLevel = .error
    ) {
        debugRecorder?.record(
            level: level,
            category: .store,
            source: "CustomerPetsStore.\(operation)",
            scope: debugScope,
            message: mappedMessage ?? "failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }

    private func recordStoreCancelled(
        _ operation: String,
        startedAt: Date
    ) {
        debugRecorder?.record(
            level: .info,
            category: .store,
            source: "CustomerPetsStore.\(operation)",
            scope: debugScope,
            message: "cancelled ignored",
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: ["operation": operation]
        )
    }

    private static func displayString(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}

private struct CustomerPetFormError: Error {
    let message: String
}

struct PendingCustomerPetPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let data: Data
    let contentType: CustomerPetPhotoContentType

    init(
        id: UUID = UUID(),
        data: Data,
        contentType: CustomerPetPhotoContentType
    ) {
        self.id = id
        self.data = data
        self.contentType = contentType
    }
}
