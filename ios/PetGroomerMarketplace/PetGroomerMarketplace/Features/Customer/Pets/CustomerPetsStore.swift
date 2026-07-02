import Foundation
import Observation

@MainActor
@Observable
final class CustomerPetsStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024

    private let customerID: UUID
    private let repository: any CustomerPetRepository
    private let photoCache: any CustomerPetPhotoCaching
    private let debugRecorder: AppDebugEventRecorder?

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
    var formCoatType: CustomerPetCoatType = .notSure
    var formWeightLbs = 20.0
    var formBirthdayDate: Date?
    var formTemperament: CustomerPetTemperament = .notSure
    var formMedicalNotes = ""
    var formGroomingNotes = ""
    private(set) var pendingFormPhotos: [PendingCustomerPetPhoto] = []

    var formTitle: String {
        editingPetID == nil ? "Add Pet" : "Edit Pet"
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
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.customerID = customerID
        self.repository = repository
        self.photoCache = photoCache
        self.debugRecorder = debugRecorder
    }

    func load() async {
        let startedAt = Date()
        recordStoreStart("load")
        isLoading = true
        errorMessage = nil

        do {
            let loadedPets = try await repository.pets(customerID: customerID)
            cachedAvatarDataByPetID = cachedAvatarDataMap(for: loadedPets)
            pets = loadedPets

            let photos = try await repository.photos(customerID: customerID)
            photosByPetID = Dictionary(grouping: photos, by: \.petID)
            photoDataByPhotoID = cachedPhotoDataMap(for: photos)
            clearStaleCachedAvatarData()
            isLoading = false

            let downloadedPhotoData = await photoDataMap(for: photos)
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
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            isLoading = false
            errorMessage = message(for: error, action: "load")
            recordStoreFailure(
                "load",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            isLoading = false
            recordStoreCancelled("load", startedAt: startedAt)
        } catch {
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
        editingPetID = nil
        resetForm()
        errorMessage = nil
        noticeMessage = nil
        isShowingPetForm = true
    }

    func startEdit(_ pet: CustomerPet) {
        editingPetID = pet.id
        formName = pet.name
        formSpecies = CustomerPetSpecies(storedValue: pet.species) ?? .dog
        let breed = pet.breed.flatMap(CustomerPetBreed.init(storedValue:)) ?? .unspecified
        formBreed = CustomerPetBreed.options(for: formSpecies).contains(breed)
            ? breed
            : .unspecified
        formCoatType = pet.coatType
            .flatMap(CustomerPetCoatType.init(storedValue:))
            ?? formBreed.recommendedCoatType
            ?? .notSure
        formWeightLbs = Self.clampedFormWeight(pet.weightLbs ?? 20)
        formBirthdayDate = pet.birthday.flatMap(Self.date)
        formTemperament = pet.temperament
            .flatMap(CustomerPetTemperament.init(storedValue:)) ?? .notSure
        formMedicalNotes = pet.medicalNotes ?? ""
        formGroomingNotes = pet.groomingNotes ?? ""
        pendingFormPhotos = []
        errorMessage = nil
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
        formCoatType = formBreed.recommendedCoatType ?? .notSure
    }

    func updateFormBreed(_ breed: CustomerPetBreed) {
        formBreed = breed
        formCoatType = breed.recommendedCoatType ?? .notSure
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
        guard !isSaving else { return }

        let startedAt = Date()
        recordStoreStart("savePet")
        errorMessage = nil
        noticeMessage = nil

        let draft: CustomerPetDraft
        do {
            draft = try makeDraft()
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
        defer { isSaving = false }

        do {
            let savedPet: CustomerPet
            let action: String
            if let editingPetID,
               let currentPet = pets.first(where: { $0.id == editingPetID }) {
                let pet = try await repository.updatePet(
                    pet: currentPet,
                    draft: draft
                )
                replace(pet)
                savedPet = pet
                action = "updated"
            } else {
                let pet = try await repository.createPet(
                    customerID: customerID,
                    draft: draft
                )
                pets.insert(pet, at: 0)
                savedPet = pet
                action = "added"
            }

            let uploadedPhotoCount = await uploadPendingFormPhotos(for: savedPet)
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
            recordStoreCancelled("savePet", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "save")
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        } catch where AppDebugErrorClassifier.isCancellation(error) {
            recordStoreCancelled("savePet", startedAt: startedAt)
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
            recordStoreFailure(
                "savePet",
                error: error,
                mappedMessage: errorMessage,
                startedAt: startedAt
            )
        }
    }

    func softDelete(_ pet: CustomerPet) async {
        guard !isSaving else { return }

        let startedAt = Date()
        recordStoreStart("softDelete", metadata: ["petID": pet.id.uuidString])
        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.softDeletePet(pet)
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
        guard !isUploading else { return }

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
            noticeMessage = "\(pet.name)'s avatar was updated."
            recordStoreSuccess("uploadPhoto", startedAt: startedAt)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("uploadPhoto", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
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
        guard !isUploading else { return }

        let startedAt = Date()
        recordStoreStart("deletePhoto", metadata: ["photoID": photo.id.uuidString])
        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePhoto(photo)
            photosByPetID[photo.petID]?.removeAll { $0.id == photo.id }
            photoDataByPhotoID[photo.id] = nil
            photoCache.remove(photoID: photo.id)
            refreshCachedAvatarDataAfterPhotoRemoval(petID: photo.petID)
            noticeMessage = "Photo was deleted."
            recordStoreSuccess("deletePhoto", startedAt: startedAt)
        } catch CustomerPetRepositoryError.cancelled {
            recordStoreCancelled("deletePhoto", startedAt: startedAt)
        } catch let error as CustomerPetRepositoryError {
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
            savePhotoCache(photo: photo, data: data)
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
        formBirthdayDate = nil
        formTemperament = .notSure
        formMedicalNotes = ""
        formGroomingNotes = ""
        pendingFormPhotos = []
    }

    private func makeDraft() throws -> CustomerPetDraft {
        let name = try required(
            formName,
            field: "Pet name",
            range: 1...80
        )
        formWeightLbs = Self.clampedFormWeight(formWeightLbs)
        if !CustomerPetBreed.options(for: formSpecies).contains(formBreed) {
            formBreed = .unspecified
        }
        let coatType = formCoatType == .notSure
            ? formBreed.recommendedCoatType
            : formCoatType
        let size = CustomerPetSizeCode.code(forWeightLbs: formWeightLbs)

        return CustomerPetDraft(
            name: name,
            species: formSpecies.rawValue,
            breed: formBreed.rawValue,
            coatType: coatType?.rawValue,
            size: size.rawValue,
            weightLbs: formWeightLbs,
            birthday: formBirthdayDate.map(Self.dateString),
            temperament: formTemperament.rawValue,
            medicalNotes: try optional(
                formMedicalNotes,
                field: "Medical notes",
                maximum: 2000
            ),
            groomingNotes: try optional(
                formGroomingNotes,
                field: "Grooming notes",
                maximum: 2000
            )
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

    private static func clampedFormWeight(_ value: Double) -> Double {
        min(101, max(5, value.rounded()))
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

        photosByPetID[pet.id] = [photo]
        photoDataByPhotoID[photo.id] = data
        cachedAvatarDataByPetID[pet.id] = data
        savePhotoCache(photo: photo, data: data)

        for replacedPhoto in replacedPhotos where replacedPhoto.id != photo.id {
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
