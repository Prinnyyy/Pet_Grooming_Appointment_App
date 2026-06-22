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

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            if store.isLoading, store.profile == nil {
                GroomlyLoadingView(
                    title: "Loading groomer profile…",
                    message: "We are preparing your profile, services, and portfolio settings.",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.profile.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Groomer profile",
                            subtitle: "Keep your business details and service menu ready for matched requests."
                        )

                        GroomerProfileFormSection(store: store)
                        GroomerServicesSection(store: store)
                        GroomerPortfolioSection(store: store)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Marketplace profile",
                subtitle: "Complete these fields before making your profile active."
            ) {
                if let profile = store.profile {
                    GroomlyStatusChip(
                        profile.isActive ? "Active" : "Hidden",
                        systemImage: profile.isActive ? "checkmark.circle.fill" : "eye.slash",
                        tone: profile.isActive ? .success : .neutral
                    )
                }
            }

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomerProfileTextField(
                        title: "Business name",
                        text: $store.businessName,
                        prompt: "Business name"
                    )
                    .textContentType(.organizationName)

                    GroomerProfileTextField(
                        title: "Bio",
                        text: $store.bio,
                        prompt: "Bio",
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    GroomerProfileTextField(
                        title: "Years of experience",
                        text: $store.yearsExperience,
                        prompt: "Years of experience"
                    )
                    .keyboardType(.numberPad)

                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        GroomerProfileTextField(
                            title: "City",
                            text: $store.baseCity,
                            prompt: "City"
                        )

                        GroomerProfileTextField(
                            title: "State",
                            text: $store.baseState,
                            prompt: "State"
                        )
                    }

                    GroomerProfileTextField(
                        title: "Service radius in miles",
                        text: $store.serviceRadiusMiles,
                        prompt: "Service radius in miles"
                    )
                    .keyboardType(.numberPad)

                    GroomlyToggleRow(
                        title: "Profile visible to authenticated customers",
                        subtitle: "Customers can discover and receive offers from active groomer profiles.",
                        systemImage: "eye",
                        isOn: $store.isActive
                    )

                    if let profile = store.profile {
                        ProfileBadges(profile: profile)
                    }

                    Button {
                        Task {
                            await store.saveProfile()
                        }
                    } label: {
                        if store.isSaving {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                ProgressView()
                                    .tint(DesignTokens.Colors.surface)
                                Text("Saving…")
                            }
                        } else {
                            Label("Save Profile", systemImage: "checkmark.circle")
                        }
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("groomer.profile.save")

                    if store.profile == nil {
                        Text("Save your profile once these details are ready.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Services",
                subtitle: "Empty size selection means the service accepts all pet sizes."
            ) {
                Button {
                    store.startCreateService()
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.services.add")
            }

            if store.services.isEmpty {
                GroomlyEmptyState(
                    title: "No services yet",
                    message: "Add services before responding to future requests.",
                    systemImage: "scissors",
                    accent: .groomer
                ) {
                    Button {
                        store.startCreateService()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
                }
                .accessibilityIdentifier("groomer.services.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.services) { service in
                        GroomerServiceRow(
                            service: service,
                            store: store
                        )
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
        GroomlyCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(service.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("$\(service.basePrice, specifier: "%.2f") • \(service.durationMinutes) min")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GroomlyStatusChip(
                            service.isActive ? "Visible" : "Hidden",
                            systemImage: service.isActive ? "eye.fill" : "eye.slash",
                            tone: service.isActive ? .success : .neutral
                        )
                    }

                    Label(service.acceptedPetSizeSummary, systemImage: "pawprint")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    if let description = service.description {
                        Text(description)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

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
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .accessibilityLabel("Service actions")
                }
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerProfileTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let axis: Axis

    init(
        title: String,
        text: Binding<String>,
        prompt: String,
        axis: Axis = .horizontal
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            TextField(prompt, text: $text, axis: axis)
                .groomlyFormField()
                .tint(DesignTokens.Colors.groomerAccentDark)
        }
    }
}

private struct GroomlyToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerServiceSizeToggleRow: View {
    let size: GroomerServicePetSize
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "pawprint")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            Text(size.title)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(size.title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileBadges: View {
    let profile: GroomerProfile

    var body: some View {
        if profile.ratingCount > 0 || profile.isVerified {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if profile.ratingCount > 0 {
                    GroomlyStatusChip(
                        "\(profile.ratingAverage.formatted(.number.precision(.fractionLength(2)))) from \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")",
                        systemImage: "star.fill",
                        tone: .warning
                    )
                }

                if profile.isVerified {
                    GroomlyStatusChip(
                        "Verified",
                        systemImage: "checkmark.seal.fill",
                        tone: .success
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            store.serviceFormTitle,
                            subtitle: "Define the service customers can review when you make offers."
                        )

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                GroomerProfileTextField(
                                    title: "Title",
                                    text: $store.serviceTitle,
                                    prompt: "Title"
                                )

                                GroomerProfileTextField(
                                    title: "Description",
                                    text: $store.serviceDescription,
                                    prompt: "Description",
                                    axis: .vertical
                                )
                                .lineLimit(2...4)

                                GroomerProfileTextField(
                                    title: "Base price",
                                    text: $store.serviceBasePrice,
                                    prompt: "Base price"
                                )
                                .keyboardType(.decimalPad)

                                GroomerProfileTextField(
                                    title: "Duration in minutes",
                                    text: $store.serviceDurationMinutes,
                                    prompt: "Duration in minutes"
                                )
                                .keyboardType(.numberPad)

                                GroomlyToggleRow(
                                    title: "Visible to customers",
                                    subtitle: "Hidden services stay saved but do not appear as active options.",
                                    systemImage: "eye",
                                    isOn: $store.serviceIsActive
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            GroomlySectionHeader(
                                "Accepted pet sizes",
                                subtitle: "Leave all sizes off when this service accepts every pet size."
                            )

                            GroomlyCard {
                                VStack(spacing: DesignTokens.Spacing.md) {
                                    ForEach(GroomerServicePetSize.allCases) { size in
                                        GroomerServiceSizeToggleRow(
                                            size: size,
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

                                        if size.id != GroomerServicePetSize.allCases.last?.id {
                                            Divider()
                                                .overlay(DesignTokens.Colors.divider)
                                        }
                                    }
                                }
                            }
                        }

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Service could not be saved",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("groomer.services.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                }
            }
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
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
        if hasStatus {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if store.isSaving || store.isUploading {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.groomerAccent)

                        Text(store.isUploading ? "Uploading…" : "Saving…")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }

                if let noticeMessage = store.noticeMessage {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.success)
                            .accessibilityHidden(true)

                        Text(noticeMessage)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }

                if let errorMessage = store.errorMessage,
                   !store.isShowingServiceForm {
                    GroomlyErrorBanner(
                        title: "Profile update failed",
                        message: errorMessage
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(.ultraThinMaterial)
        }
    }

    private var hasStatus: Bool {
        store.isSaving ||
            store.isUploading ||
            store.noticeMessage != nil ||
            (store.errorMessage != nil && !store.isShowingServiceForm)
    }
}


private struct GroomerCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GroomlyCard {
            content
        }
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
