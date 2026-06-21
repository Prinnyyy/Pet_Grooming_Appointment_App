import SwiftUI

struct CustomerRequestsView: View {
    @State private var store: CustomerRequestsStore

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository
    ) {
        _store = State(
            initialValue: CustomerRequestsStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository
            )
        )
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading, store.pets.isEmpty, store.requests.isEmpty {
                ProgressView("Loading requests…")
                    .accessibilityIdentifier("customer.requests.loading")
            } else {
                List {
                    Section {
                        Button {
                            store.startCreate()
                        } label: {
                            Label("Start grooming request", systemImage: "plus.circle")
                        }
                        .disabled(store.isBusy || store.pets.isEmpty)
                        .accessibilityIdentifier("customer.requests.start")

                        if store.pets.isEmpty {
                            Text("Add a pet on the Home tab before publishing a request.")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }
                    }

                    if store.requests.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No requests yet",
                                systemImage: "doc.badge.plus",
                                description: Text("Create a request when your pet is ready for grooming.")
                            )
                            .accessibilityIdentifier("customer.requests.empty")
                        }
                    } else {
                        Section("Your requests") {
                            ForEach(store.requests) { request in
                                NavigationLink {
                                    CustomerRequestDetailView(request: request)
                                } label: {
                                    CustomerRequestSummaryRow(request: request)
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("customer.requests.list")
            }
        }
        .navigationTitle("Requests")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.load()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isBusy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CustomerRequestsStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingWizard) {
            CustomerRequestWizardView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct CustomerRequestSummaryRow: View {
    let request: CustomerGroomingRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(request.title)
                    .font(.headline)

                Spacer()

                Text(request.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(request.status.isOpenForOffers ? .green : .secondary)
            }

            Text(request.locationSummary)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text(
                "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
            )
            .font(.caption)
            .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

private struct CustomerRequestDetailView: View {
    let request: CustomerGroomingRequest

    var body: some View {
        List {
            Section("Request") {
                LabeledContent("Status", value: request.status.title)
                LabeledContent("Service", value: request.serviceType)
                if let serviceNotes = request.serviceNotes {
                    Text(serviceNotes)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }
            }

            Section("Pet snapshot") {
                LabeledContent("Pet", value: request.petSnapshot.name)
                LabeledContent("Species", value: request.petSnapshot.species)
                if let breed = request.petSnapshot.breed {
                    LabeledContent("Breed", value: breed)
                }
                if let size = request.petSnapshot.size {
                    LabeledContent("Size", value: size)
                }
                LabeledContent(
                    "Photos",
                    value: "\(request.photoSnapshot.count)"
                )
            }

            Section("Preferred time") {
                LabeledContent(
                    "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredStart
                    )
                )
                LabeledContent(
                    "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredEnd
                    )
                )
            }

            Section("Location") {
                LabeledContent("City", value: request.city)
                LabeledContent("State", value: request.state)
                LabeledContent("ZIP", value: request.zipCode)
            }

            if request.status.isOpenForOffers {
                Section("Cancellation") {
                    Text("Request cancellation needs a controlled backend RPC and is not connected yet.")
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }
            }
        }
        .navigationTitle(request.petSnapshot.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.requests.detail")
    }
}

private struct CustomerRequestWizardView: View {
    @Bindable var store: CustomerRequestsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Pet") {
                    Picker("Pet", selection: $store.selectedPetID) {
                        ForEach(store.pets) { pet in
                            Text(pet.name)
                                .tag(Optional(pet.id))
                        }
                    }
                }

                Section("Service") {
                    TextField("Service type", text: $store.serviceType)
                        .textContentType(.none)

                    TextField("Notes", text: $store.serviceNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Preferred time") {
                    DatePicker(
                        "Start",
                        selection: $store.preferredStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End",
                        selection: $store.preferredEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Location") {
                    TextField("City", text: $store.city)
                        .textContentType(.addressCity)

                    TextField("State", text: $store.state)
                        .textContentType(.addressState)

                    TextField("ZIP code", text: $store.zipCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Review") {
                    LabeledContent(
                        "Pet",
                        value: store.selectedPet?.name ?? "Choose a pet"
                    )
                    LabeledContent(
                        "Service",
                        value: store.serviceType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Required"
                            : store.serviceType.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    LabeledContent(
                        "Location",
                        value: reviewLocation
                    )
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("customer.requests.form-error")
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelWizard()
                    }
                    .disabled(store.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        Task {
                            await store.publish()
                        }
                    }
                    .disabled(store.isSubmitting || store.pets.isEmpty)
                    .accessibilityIdentifier("customer.requests.publish")
                }
            }
        }
        .interactiveDismissDisabled(store.isSubmitting)
    }

    private var reviewLocation: String {
        let parts = [
            store.city.trimmingCharacters(in: .whitespacesAndNewlines),
            store.state.trimmingCharacters(in: .whitespacesAndNewlines),
            store.zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }

        return parts.isEmpty ? "Required" : parts.joined(separator: ", ")
    }
}

private struct CustomerRequestsStatusView: View {
    let store: CustomerRequestsStore

    var body: some View {
        VStack(spacing: 8) {
            if store.isSubmitting {
                ProgressView("Publishing…")
                    .font(.footnote)
            }

            if let noticeMessage = store.noticeMessage {
                Text(noticeMessage)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingWizard {
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
        CustomerRequestsView(
            customerID: UUID(),
            petRepository: CustomerRequestsPreviewPetRepository(),
            requestRepository: CustomerRequestsPreviewRequestRepository()
        )
    }
}

@MainActor
private final class CustomerRequestsPreviewPetRepository: CustomerPetRepository {
    private let pet = CustomerPet(
        id: UUID(),
        customerID: UUID(),
        name: "Mochi",
        species: "Dog",
        breed: "Corgi",
        size: "Small",
        weightLbs: 22,
        birthday: nil,
        temperament: "Gentle",
        medicalNotes: nil,
        groomingNotes: nil,
        isActive: true
    )

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        [pet]
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        []
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        throw CustomerPetRepositoryError.unavailable
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}
}

@MainActor
private final class CustomerRequestsPreviewRequestRepository: CustomerRequestRepository {
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        [
            CustomerGroomingRequest(
                id: UUID(),
                customerID: customerID,
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    size: "Small",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: "Full groom",
                serviceNotes: "Please be gentle around the paws.",
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
        ]
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        GroomingRequestPublishResult(
            requestID: UUID(),
            matchCount: 2
        )
    }
}
#endif
