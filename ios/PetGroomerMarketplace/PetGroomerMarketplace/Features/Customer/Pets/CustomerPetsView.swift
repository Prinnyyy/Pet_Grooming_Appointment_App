import PhotosUI
import SwiftUI

struct CustomerPetsView: View {
    @State private var store: CustomerPetsStore

    init(
        customerID: UUID,
        repository: any CustomerPetRepository
    ) {
        _store = State(
            initialValue: CustomerPetsStore(
                customerID: customerID,
                repository: repository
            )
        )
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading, store.pets.isEmpty {
                ProgressView("Loading pets…")
                    .accessibilityIdentifier("customer.pets.loading")
            } else if store.pets.isEmpty {
                ContentUnavailableView(
                    "No pets yet",
                    systemImage: "pawprint",
                    description: Text("Add your pet before creating a grooming request.")
                )
                .accessibilityIdentifier("customer.pets.empty")
            } else {
                List {
                    ForEach(store.pets) { pet in
                        CustomerPetCardView(
                            pet: pet,
                            photos: store.photos(for: pet),
                            store: store
                        )
                    }
                }
                .accessibilityIdentifier("customer.pets.list")
            }
        }
        .navigationTitle("Pets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.startCreate()
                } label: {
                    Label("Add Pet", systemImage: "plus")
                }
                .accessibilityIdentifier("customer.pets.add")
            }
        }
        .safeAreaInset(edge: .bottom) {
            CustomerPetsStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingPetForm) {
            CustomerPetFormView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct CustomerPetCardView: View {
    let pet: CustomerPet
    let photos: [CustomerPetPhoto]
    @Bindable var store: CustomerPetsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.standard) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)

                    Text(detailLine)
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        store.startEdit(pet)
                    }

                    Button("Remove", role: .destructive) {
                        Task {
                            await store.softDelete(pet)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Pet actions")
                }
                .disabled(store.isBusy)
            }

            if let notes = notesLine {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(photos.count) photo\(photos.count == 1 ? "" : "s")", systemImage: "photo")
                        .font(.subheadline)

                    Spacer()

                    CustomerPetPhotoUploadButton(
                        pet: pet,
                        store: store
                    )
                }

                ForEach(photos) { photo in
                    HStack {
                        Text(photo.fileName)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                            .lineLimit(1)

                        Spacer()

                        Button("Delete", role: .destructive) {
                            Task {
                                await store.deletePhoto(photo)
                            }
                        }
                        .font(.caption)
                        .disabled(store.isBusy)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var detailLine: String {
        [pet.species, pet.breed, pet.size]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var notesLine: String? {
        let values = [
            pet.temperament.map { "Temperament: \($0)" },
            pet.medicalNotes.map { "Medical: \($0)" },
            pet.groomingNotes.map { "Grooming: \($0)" },
        ]
        .compactMap { $0 }

        return values.isEmpty ? nil : values.joined(separator: "\n")
    }
}

private struct CustomerPetPhotoUploadButton: View {
    let pet: CustomerPet
    @Bindable var store: CustomerPetsStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label("Add Photo", systemImage: "plus.circle")
                .font(.caption)
        }
        .disabled(store.isBusy)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await upload(newItem)
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(CustomerPetPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        await store.uploadPhoto(
            pet: pet,
            data: data,
            contentType: contentType
        )
    }
}

private struct CustomerPetFormView: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $store.formName)
                        .textContentType(.name)

                    TextField("Species", text: $store.formSpecies)

                    TextField("Breed", text: $store.formBreed)

                    TextField("Size", text: $store.formSize)
                }

                Section("Optional details") {
                    TextField("Weight in lbs", text: $store.formWeightLbs)
                        .keyboardType(.decimalPad)

                    TextField("Birthday YYYY-MM-DD", text: $store.formBirthday)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Temperament", text: $store.formTemperament, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Medical notes", text: $store.formMedicalNotes, axis: .vertical)
                        .lineLimit(2...5)

                    TextField("Grooming notes", text: $store.formGroomingNotes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("customer.pets.form-error")
                }
            }
            .navigationTitle(store.formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelForm()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.savePet()
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }
}

private struct CustomerPetsStatusView: View {
    let store: CustomerPetsStore

    var body: some View {
        VStack(spacing: 8) {
            if store.isSaving || store.isUploading {
                ProgressView(store.isUploading ? "Uploading…" : "Saving…")
                    .font(.footnote)
            }

            if let noticeMessage = store.noticeMessage {
                Text(noticeMessage)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingPetForm {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.standard)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CustomerPetsView(
            customerID: UUID(),
            repository: CustomerPetsPreviewRepository()
        )
    }
}

@MainActor
private final class CustomerPetsPreviewRepository: CustomerPetRepository {
    private let customerID = UUID()
    private var storedPets: [CustomerPet]
    private var storedPhotos: [CustomerPetPhoto] = []

    init() {
        let petID = UUID()
        storedPets = [
            CustomerPet(
                id: petID,
                customerID: customerID,
                name: "Mochi",
                species: "Dog",
                breed: "Shiba Inu",
                size: "Small",
                weightLbs: 22,
                birthday: "2022-03-10",
                temperament: "Friendly",
                medicalNotes: nil,
                groomingNotes: "Sensitive paws",
                isActive: true
            ),
        ]
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        storedPets
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        storedPhotos
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        let pet = CustomerPet(
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
        storedPets.insert(pet, at: 0)
        return pet
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        CustomerPet(
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

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        CustomerPetPhoto(
            id: UUID(),
            petID: petID,
            customerID: customerID,
            storageBucket: "pet-photos",
            storagePath: CustomerPetPhotoPath.make(
                customerID: customerID,
                petID: petID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0,
            isPrimary: false
        )
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}
}
#endif
