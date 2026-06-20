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
    var formSpecies = ""
    var formBreed = ""
    var formSize = ""
    var formWeightLbs = ""
    var formBirthday = ""
    var formTemperament = ""
    var formMedicalNotes = ""
    var formGroomingNotes = ""

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
        formSpecies = pet.species
        formBreed = pet.breed ?? ""
        formSize = pet.size ?? ""
        formWeightLbs = pet.weightLbs.map(Self.displayString) ?? ""
        formBirthday = pet.birthday ?? ""
        formTemperament = pet.temperament ?? ""
        formMedicalNotes = pet.medicalNotes ?? ""
        formGroomingNotes = pet.groomingNotes ?? ""
        errorMessage = nil
        noticeMessage = nil
        isShowingPetForm = true
    }

    func cancelForm() {
        isShowingPetForm = false
        editingPetID = nil
        resetForm()
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
            if let editingPetID,
               let currentPet = pets.first(where: { $0.id == editingPetID }) {
                let pet = try await repository.updatePet(
                    pet: currentPet,
                    draft: draft
                )
                replace(pet)
                noticeMessage = "\(pet.name) was updated."
            } else {
                let pet = try await repository.createPet(
                    customerID: customerID,
                    draft: draft
                )
                pets.insert(pet, at: 0)
                noticeMessage = "\(pet.name) was added."
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
        formSpecies = ""
        formBreed = ""
        formSize = ""
        formWeightLbs = ""
        formBirthday = ""
        formTemperament = ""
        formMedicalNotes = ""
        formGroomingNotes = ""
    }

    private func makeDraft() throws -> CustomerPetDraft {
        let name = try required(
            formName,
            field: "Pet name",
            range: 1...80
        )
        let species = try required(
            formSpecies,
            field: "Species",
            range: 1...40
        )

        return CustomerPetDraft(
            name: name,
            species: species,
            breed: try optional(formBreed, field: "Breed", maximum: 80),
            size: try optional(formSize, field: "Size", maximum: 40),
            weightLbs: try weight(from: formWeightLbs),
            birthday: try birthday(from: formBirthday),
            temperament: try optional(
                formTemperament,
                field: "Temperament",
                maximum: 500
            ),
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

    private func weight(from value: String) throws -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let weight = Double(trimmed), weight > 0, weight <= 1000 else {
            throw CustomerPetFormError(
                message: "Weight must be greater than 0 and at most 1000 lbs."
            )
        }
        return weight
    }

    private func birthday(from value: String) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: trimmed),
              formatter.string(from: date) == trimmed else {
            throw CustomerPetFormError(
                message: "Birthday must use YYYY-MM-DD."
            )
        }

        let today = Calendar.current.startOfDay(for: Date())
        guard date <= today else {
            throw CustomerPetFormError(
                message: "Birthday cannot be in the future."
            )
        }

        return trimmed
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
