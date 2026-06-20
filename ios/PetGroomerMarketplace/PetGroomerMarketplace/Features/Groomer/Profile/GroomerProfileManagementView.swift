import PhotosUI
import SwiftUI

struct GroomerProfileManagementView: View {
    @State private var store: GroomerProfileStore
    let accountContent: AnyView?

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        accountContent: AnyView? = nil
    ) {
        _store = State(
            initialValue: GroomerProfileStore(
                groomerID: groomerID,
                repository: repository
            )
        )
        self.accountContent = accountContent
    }

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading, store.profile == nil {
                ProgressView("Loading groomer profile…")
                    .accessibilityIdentifier("groomer.profile.loading")
            } else {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.standard) {
                        GroomerProfileFormSection(store: store)
                        GroomerServicesSection(store: store)
                        GroomerPortfolioSection(store: store)
                    }
                    .padding(DesignTokens.Spacing.standard)
                }
                .accessibilityIdentifier("groomer.profile.management")
            }
        }
        .navigationTitle("Groomer Profile")
        .toolbar {
            if let accountContent {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        accountContent
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                    .accessibilityIdentifier("groomer.profile.account")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            GroomerProfileStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingServiceForm) {
            GroomerServiceFormView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct GroomerProfileFormSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomerCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.standard) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marketplace profile")
                            .font(.headline)
                        Text("Complete these fields before making your profile active.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }

                    Spacer()

                    if let profile = store.profile {
                        Label(
                            profile.isActive ? "Active" : "Hidden",
                            systemImage: profile.isActive ? "checkmark.circle" : "eye.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            profile.isActive
                                ? Color.green
                                : DesignTokens.Colors.secondaryText
                        )
                    }
                }

                TextField("Business name", text: $store.businessName)
                    .textContentType(.organizationName)

                TextField("Bio", text: $store.bio, axis: .vertical)
                    .lineLimit(3...6)

                TextField("Years of experience", text: $store.yearsExperience)
                    .keyboardType(.numberPad)

                HStack {
                    TextField("City", text: $store.baseCity)
                    TextField("State", text: $store.baseState)
                }

                TextField("Service radius in miles", text: $store.serviceRadiusMiles)
                    .keyboardType(.numberPad)

                Toggle("Profile visible to authenticated customers", isOn: $store.isActive)

                if let profile = store.profile,
                   profile.ratingCount > 0 {
                    Label(
                        "\(profile.ratingAverage, specifier: "%.2f") from \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")",
                        systemImage: "star.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                if store.profile?.isVerified == true {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Button {
                    Task {
                        await store.saveProfile()
                    }
                } label: {
                    HStack {
                        if store.isSaving {
                            ProgressView()
                        }
                        Text(store.isSaving ? "Saving…" : "Save Profile")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.profile.save")
            }
        }
    }
}

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomerCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.standard) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Services")
                            .font(.headline)
                        Text("Empty size selection means the service accepts all pet sizes.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }

                    Spacer()

                    Button {
                        store.startCreateService()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("groomer.services.add")
                }

                if store.services.isEmpty {
                    ContentUnavailableView(
                        "No services yet",
                        systemImage: "scissors",
                        description: Text("Add services before responding to future requests.")
                    )
                    .frame(minHeight: 140)
                    .accessibilityIdentifier("groomer.services.empty")
                } else {
                    ForEach(store.services) { service in
                        GroomerServiceRow(
                            service: service,
                            store: store
                        )

                        if service.id != store.services.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct GroomerServiceRow: View {
    let service: GroomerService
    @Bindable var store: GroomerProfileStore

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(service.title)
                        .font(.subheadline.bold())

                    if !service.isActive {
                        Text("Hidden")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }

                Text("$\(service.basePrice, specifier: "%.2f") • \(service.durationMinutes) min")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)

                Text(service.acceptedPetSizeSummary)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)

                if let description = service.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }
            }

            Spacer()

            Menu {
                Button("Edit") {
                    store.startEditService(service)
                }

                Button("Delete", role: .destructive) {
                    Task {
                        await store.deleteService(service)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Service actions")
            }
            .disabled(store.isBusy)
        }
    }
}

private struct GroomerPortfolioSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        GroomerCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.standard) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Portfolio")
                            .font(.headline)
                        Text("Images upload to the private groomer-portfolio bucket.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }

                    Spacer()

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Add Photo", systemImage: "plus.circle")
                    }
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("groomer.portfolio.add")
                }

                if store.portfolioPhotos.isEmpty {
                    ContentUnavailableView(
                        "No portfolio photos",
                        systemImage: "photo.on.rectangle",
                        description: Text("Add work examples after completing your profile.")
                    )
                    .frame(minHeight: 140)
                    .accessibilityIdentifier("groomer.portfolio.empty")
                } else {
                    ForEach(store.sortedPortfolioPhotos()) { photo in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.fileName)
                                    .font(.footnote)
                                    .lineLimit(1)

                                if let caption = photo.caption {
                                    Text(caption)
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                                }
                            }

                            Spacer()

                            Button("Delete", role: .destructive) {
                                Task {
                                    await store.deletePortfolioPhoto(photo)
                                }
                            }
                            .font(.caption)
                            .disabled(store.isBusy)
                        }
                    }
                }
            }
        }
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
            .compactMap(GroomerPortfolioPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        await store.uploadPortfolioPhoto(
            data: data,
            contentType: contentType
        )
    }
}

private struct GroomerServiceFormView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Title", text: $store.serviceTitle)

                    TextField("Description", text: $store.serviceDescription, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Base price", text: $store.serviceBasePrice)
                        .keyboardType(.decimalPad)

                    TextField("Duration in minutes", text: $store.serviceDurationMinutes)
                        .keyboardType(.numberPad)

                    Toggle("Visible to customers", isOn: $store.serviceIsActive)
                }

                Section {
                    ForEach(GroomerServicePetSize.allCases) { size in
                        Toggle(
                            size.title,
                            isOn: Binding(
                                get: {
                                    store.selectedServiceSizes.contains(size)
                                },
                                set: { isSelected in
                                    if isSelected {
                                        store.selectedServiceSizes.insert(size)
                                    } else {
                                        store.selectedServiceSizes.remove(size)
                                    }
                                }
                            )
                        )
                    }
                } header: {
                    Text("Accepted pet sizes")
                } footer: {
                    Text("Leave all sizes off when this service accepts every pet size.")
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("groomer.services.form-error")
                }
            }
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelServiceForm()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.saveService()
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }
}

private struct GroomerProfileStatusView: View {
    let store: GroomerProfileStore

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
               !store.isShowingServiceForm {
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

private struct GroomerCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.Spacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerProfileManagementView(
            groomerID: UUID(),
            repository: GroomerProfilePreviewRepository()
        )
    }
}

@MainActor
private final class GroomerProfilePreviewRepository: GroomerProfileRepository {
    private let groomerID = UUID()
    private var storedProfile: GroomerProfile
    private var storedServices: [GroomerService]
    private var storedPhotos: [GroomerPortfolioPhoto] = []

    init() {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Fresh Coat Grooming",
            bio: "Calm, one-on-one grooming for small and medium dogs.",
            yearsExperience: 6,
            baseCity: "Seattle",
            baseState: "WA",
            serviceRadiusMiles: 12,
            ratingAverage: 0,
            ratingCount: 0,
            isActive: false,
            isVerified: false
        )
        storedServices = [
            GroomerService(
                id: UUID(),
                groomerID: groomerID,
                title: "Full Groom",
                description: "Bath, haircut, nails, and ear cleaning.",
                basePrice: 95,
                durationMinutes: 120,
                acceptedPetSizes: [.small, .medium],
                isActive: true
            ),
        ]
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        storedProfile
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        storedServices
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        storedPhotos
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: draft.businessName,
            bio: draft.bio,
            yearsExperience: draft.yearsExperience,
            baseCity: draft.baseCity,
            baseState: draft.baseState,
            serviceRadiusMiles: draft.serviceRadiusMiles,
            ratingAverage: storedProfile.ratingAverage,
            ratingCount: storedProfile.ratingCount,
            isActive: draft.isActive,
            isVerified: storedProfile.isVerified
        )
        return storedProfile
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        let service = GroomerService(
            id: UUID(),
            groomerID: groomerID,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
        storedServices.insert(service, at: 0)
        return service
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        GroomerService(
            id: service.id,
            groomerID: service.groomerID,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func deleteService(_ service: GroomerService) async throws {}

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        GroomerPortfolioPhoto(
            id: UUID(),
            groomerID: groomerID,
            storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(
                groomerID: groomerID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0
        )
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {}
}
#endif
