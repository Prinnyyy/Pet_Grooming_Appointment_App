import Foundation
import Observation

@MainActor
@Observable
final class CustomerPetsStore {
    static let maximumPhotoBytes = 10 * 1024 * 1024

    private let customerID: UUID
    private let repository: any CustomerPetRepository

    private(set) var pets: [CustomerPet] = []
    private(set) var photosByPetID: [UUID: [CustomerPetPhoto]] = [:]
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
    var formWeightLbs = 20.0
    var formBirthdayDate: Date?
    var formTemperament: CustomerPetTemperament = .notSure
    var formMedicalNotes = ""
    var formGroomingNotes = ""
    private(set) var pendingFormPhotos: [PendingCustomerPetPhoto] = []

    var formTitle: String {
        editingPetID == nil ? "Add Pet" : "Edit Pet"
    }

    var isBusy: Bool {
        isLoading || isSaving || isUploading
    }

    init(
        customerID: UUID,
        repository: any CustomerPetRepository
    ) {
        self.customerID = customerID
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            pets = try await repository.pets(customerID: customerID)
            let photos = try await repository.photos(customerID: customerID)
            photosByPetID = Dictionary(grouping: photos, by: \.petID)
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "load")
        } catch {
            errorMessage = message(for: .unavailable, action: "load")
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
        editingPetID = nil
        resetForm()
    }

    func updateFormSpecies(_ species: CustomerPetSpecies) {
        formSpecies = species
        if !CustomerPetBreed.options(for: species).contains(formBreed) {
            formBreed = .unspecified
        }
    }

    func addPendingFormPhoto(
        data: Data,
        contentType: CustomerPetPhotoContentType
    ) {
        guard data.count <= Self.maximumPhotoBytes else {
            errorMessage = "Choose a photo smaller than 10 MB."
            return
        }

        pendingFormPhotos.append(
            PendingCustomerPetPhoto(
                data: data,
                contentType: contentType
            )
        )
    }

    func removePendingFormPhoto(_ photo: PendingCustomerPetPhoto) {
        pendingFormPhotos.removeAll { $0.id == photo.id }
    }

    func savePet() async {
        guard !isSaving else { return }

        errorMessage = nil
        noticeMessage = nil

        let draft: CustomerPetDraft
        do {
            draft = try makeDraft()
        } catch let error as CustomerPetFormError {
            errorMessage = error.message
            return
        } catch {
            errorMessage = "Check the pet details and try again."
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
                noticeMessage =
                    "\(savedPet.name) was \(action) with \(uploadedPhotoCount) photo\(uploadedPhotoCount == 1 ? "" : "s")."
            } else {
                noticeMessage = "\(savedPet.name) was \(action)."
            }
            isShowingPetForm = false
            editingPetID = nil
            resetForm()
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "save")
        } catch {
            errorMessage = message(for: .unavailable, action: "save")
        }
    }

    func softDelete(_ pet: CustomerPet) async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSaving = false }

        do {
            try await repository.softDeletePet(pet)
            pets.removeAll { $0.id == pet.id }
            photosByPetID[pet.id] = nil
            noticeMessage = "\(pet.name) was removed."
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "delete")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete")
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

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            let photo = try await repository.uploadPhoto(
                customerID: customerID,
                petID: pet.id,
                data: data,
                contentType: contentType,
                caption: nil
            )
            photosByPetID[pet.id, default: []].append(photo)
            noticeMessage = "Photo was uploaded for \(pet.name)."
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "upload")
        } catch {
            errorMessage = message(for: .unavailable, action: "upload")
        }
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async {
        guard !isUploading else { return }

        isUploading = true
        errorMessage = nil
        noticeMessage = nil
        defer { isUploading = false }

        do {
            try await repository.deletePhoto(photo)
            photosByPetID[photo.petID]?.removeAll { $0.id == photo.id }
            noticeMessage = "Photo was deleted."
        } catch let error as CustomerPetRepositoryError {
            errorMessage = message(for: error, action: "delete photo")
        } catch {
            errorMessage = message(for: .unavailable, action: "delete photo")
        }
    }

    private func replace(_ pet: CustomerPet) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else {
            pets.insert(pet, at: 0)
            return
        }
        pets[index] = pet
    }

    private func resetForm() {
        formName = ""
        formSpecies = .dog
        formBreed = .unspecified
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
        let size = CustomerPetSizeCode.code(forWeightLbs: formWeightLbs)

        return CustomerPetDraft(
            name: name,
            species: formSpecies.rawValue,
            breed: formBreed.rawValue,
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

        var uploadedCount = 0
        var failed = false
        for photo in pendingFormPhotos {
            do {
                let uploaded = try await repository.uploadPhoto(
                    customerID: customerID,
                    petID: pet.id,
                    data: photo.data,
                    contentType: photo.contentType,
                    caption: nil
                )
                photosByPetID[pet.id, default: []].append(uploaded)
                uploadedCount += 1
            } catch {
                failed = true
            }
        }

        pendingFormPhotos = []
        if failed {
            errorMessage = "Pet was saved, but some photos could not upload."
        }
        return uploadedCount
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
        case .unavailable:
            "We could not \(action) pet information. Please try again."
        }
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
