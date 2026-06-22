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

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            screenContent
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

    @ViewBuilder
    private var screenContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Your pets",
                    subtitle: "Keep each pet's details ready before creating a grooming request."
                )

                if store.isLoading, store.pets.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading pets…",
                        message: "Fetching your saved pet profiles.",
                        accent: .customer
                    )
                    .accessibilityIdentifier("customer.pets.loading")
                } else if store.pets.isEmpty {
                    GroomlyEmptyState(
                        title: "No pets yet",
                        message: "Add your pet before creating a grooming request.",
                        systemImage: "pawprint",
                        accent: .customer
                    ) {
                        Button {
                            store.startCreate()
                        } label: {
                            Label("Add Pet", systemImage: "plus")
                        }
                        .buttonStyle(GroomlyPrimaryButtonStyle())
                    }
                    .accessibilityIdentifier("customer.pets.empty")
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
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
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct CustomerPetCardView: View {
    let pet: CustomerPet
    let photos: [CustomerPetPhoto]
    @Bindable var store: CustomerPetsStore

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "pawprint.fill")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.16))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(pet.name)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        if !detailLine.isEmpty {
                            Text(detailLine)
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }
                    }

                    Spacer(minLength: DesignTokens.Spacing.md)

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
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .accessibilityLabel("Pet actions")
                    }
                    .disabled(store.isBusy)
                }

                if let notes = notesLine {
                    Text(notes)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                        GroomlyStatusChip(
                            "\(photos.count) photo\(photos.count == 1 ? "" : "s")",
                            systemImage: "photo",
                            tone: .customer
                        )

                        Spacer(minLength: DesignTokens.Spacing.md)

                        CustomerPetPhotoUploadButton(
                            pet: pet,
                            store: store
                        )
                    }

                    ForEach(photos) { photo in
                        CustomerPetPhotoRow(
                            photo: photo,
                            store: store
                        )
                    }
                }
            }
        }
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

private struct CustomerPetPhotoRow: View {
    let photo: CustomerPetPhoto
    @Bindable var store: CustomerPetsStore

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "photo")
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .accessibilityHidden(true)

            Text(photo.fileName)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.secondaryText)
                .lineLimit(1)

            Spacer(minLength: DesignTokens.Spacing.sm)

            Button(role: .destructive) {
                Task {
                    await store.deletePhoto(photo)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .font(DesignTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.error)
            .buttonStyle(.plain)
            .disabled(store.isBusy)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
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
                .lineLimit(1)
        }
        .buttonStyle(GroomlySecondaryButtonStyle(isFullWidth: false))
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
                        .groomlyFormField()

                    TextField("Species", text: $store.formSpecies)
                        .groomlyFormField()

                    TextField("Breed", text: $store.formBreed)
                        .groomlyFormField()

                    TextField("Size", text: $store.formSize)
                        .groomlyFormField()
                }
                .listRowBackground(Color.clear)

                Section("Optional details") {
                    TextField("Weight in lbs", text: $store.formWeightLbs)
                        .keyboardType(.decimalPad)
                        .groomlyFormField()

                    TextField("Birthday YYYY-MM-DD", text: $store.formBirthday)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .groomlyFormField()

                    TextField("Temperament", text: $store.formTemperament, axis: .vertical)
                        .lineLimit(2...4)
                        .groomlyFormField()

                    TextField("Medical notes", text: $store.formMedicalNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .groomlyFormField()

                    TextField("Grooming notes", text: $store.formGroomingNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .groomlyFormField()
                }
                .listRowBackground(Color.clear)

                if let errorMessage = store.errorMessage {
                    Section {
                        GroomlyErrorBanner(
                            title: "Check pet details",
                            message: errorMessage
                        )
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("customer.pets.form-error")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DesignTokens.Colors.background)
            .tint(DesignTokens.Colors.customerPrimaryDark)
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
        if hasStatus {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if store.isSaving || store.isUploading {
                    GroomlyCard(padding: DesignTokens.Spacing.md) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.customerPrimary)

                            Text(store.isUploading ? "Uploading…" : "Saving…")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }
                    }
                }

                if let noticeMessage = store.noticeMessage {
                    GroomlyCard(padding: DesignTokens.Spacing.md) {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                            GroomlyStatusChip(
                                "Saved",
                                systemImage: "checkmark",
                                tone: .success
                            )

                            Text(noticeMessage)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let errorMessage = store.errorMessage,
                   !store.isShowingPetForm {
                    GroomlyErrorBanner(
                        title: "We could not update your pets",
                        message: errorMessage
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.standard)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(.ultraThinMaterial)
        }
    }

    private var hasStatus: Bool {
        store.isSaving
            || store.isUploading
            || store.noticeMessage != nil
            || (store.errorMessage != nil && !store.isShowingPetForm)
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
