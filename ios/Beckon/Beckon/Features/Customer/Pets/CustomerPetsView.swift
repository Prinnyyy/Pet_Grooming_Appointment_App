import SwiftUI

struct CustomerPetsView: View {
    private let displayName: String
    private let isActiveTab: Bool
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let onActiveRequestSelected: (UUID) -> Void
    private let onBookingChatSelected: (Booking) -> Void
    @State private var petStore: CustomerPetsStore
    @State private var requestStore: CustomerRequestsStore
    @State private var bookingStore: BookingsStore
    @State private var notificationStore: CustomerNotificationsStore
    @State private var isShowingNotifications = false

    init(
        customerID: UUID,
        displayName: String? = nil,
        isActiveTab: Bool = true,
        repository: any CustomerPetRepository,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        requestRepository: any CustomerRequestRepository,
        notificationRepository: any CustomerNotificationRepository,
        bookingRepository: any BookingRepository,
        debugRecorder: AppDebugEventRecorder? = nil,
        notificationStore: CustomerNotificationsStore? = nil,
        requestStore: CustomerRequestsStore? = nil,
        onActiveRequestSelected: @escaping (UUID) -> Void = { _ in },
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in }
    ) {
        let trimmedName = displayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        self.displayName = trimmedName.isEmpty ? "there" : trimmedName
        self.isActiveTab = isActiveTab
        self.customerProfileRepository = customerProfileRepository
        self.onActiveRequestSelected = onActiveRequestSelected
        self.onBookingChatSelected = onBookingChatSelected
        _petStore = State(
            initialValue: CustomerPetsStore(
                customerID: customerID,
                repository: repository,
                debugRecorder: debugRecorder
            )
        )
        _requestStore = State(
            initialValue: requestStore ?? CustomerRequestsStore(
                customerID: customerID,
                petRepository: repository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
        _bookingStore = State(
            initialValue: BookingsStore(
                participantID: customerID,
                role: .customer,
                repository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
        _notificationStore = State(
            initialValue: notificationStore ?? CustomerNotificationsStore(
                customerID: customerID,
                repository: notificationRepository
            )
        )
    }

    var body: some View {
        @Bindable var petStore = petStore
        @Bindable var requestStore = requestStore

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            screenContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .background {
            CustomerHomeStatusView(
                petStore: petStore,
                requestStore: requestStore,
                nextBookingPresentation: nextBookingPresentation
            )
        }
        .sheet(isPresented: $petStore.isShowingPetForm) {
            CustomerPetFormView(store: petStore)
        }
        .sheet(isPresented: requestWizardPresentationBinding) {
            CustomerRequestWizardView(
                store: requestStore,
                customerProfileRepository: customerProfileRepository
            ) {
                requestStore.cancelWizard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    petStore.startCreate()
                }
            }
        }
        .navigationDestination(isPresented: $isShowingNotifications) {
            CustomerNotificationsView(store: notificationStore)
        }
        .foregroundRefreshable {
            await loadHome()
        }
        .accessibilityIdentifier("customer.home")
    }

    private var screenContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                CustomerHomeHeader(
                    displayName: displayName,
                    unreadNotificationCount: notificationStore.unreadCount,
                    notificationAction: {
                        isShowingNotifications = true
                    }
                )

                CustomerHomeRequestHero(
                    isDisabled: requestHeroPresentation.isStartRequestDisabled,
                    action: startGroomingRequest
                )

                CustomerHomePetsSection(store: petStore)

                CustomerHomeActiveRequestSection(
                    presentation: activeRequestPresentation,
                    onSelectRequest: onActiveRequestSelected
                )

                CustomerHomeNextBookingSection(
                    presentation: nextBookingPresentation,
                    store: bookingStore,
                    onOpenChat: onBookingChatSelected
                )
            }
            .beckonPageInsets(bottom: DesignTokens.Layout.pageBottomInset * 2)
        }
        .scrollContentBackground(.hidden)
    }

    private var requestHeroPresentation: CustomerHomeRequestHeroPresentation {
        CustomerHomeRequestHeroPresentation(
            hasPets: !petStore.pets.isEmpty,
            isRequestStoreBusy: requestStore.isBusy
        )
    }

    private var activeRequestPresentation: CustomerHomeActiveRequestPresentation {
        CustomerHomeActiveRequestPresentation(
            cards: requestStore.visibleActionCards,
            isLoading: requestStore.isLoading
        )
    }

    private var nextBooking: Booking? {
        let referenceDate = Date()
        return bookingStore.bookings
            .filter {
                BookingListScope.upcoming.contains(
                    $0,
                    referenceDate: referenceDate
                )
            }
            .sortedByScheduledStart(ascending: true)
            .first
    }

    private var nextBookingPresentation: CustomerHomeNextBookingPresentation {
        CustomerHomeNextBookingPresentation(
            booking: nextBooking,
            isLoading: bookingStore.isLoading,
            loadErrorMessage: bookingStore.errorMessage
        )
    }

    @MainActor
    private func loadHome() async {
        await petStore.load()
        await requestStore.load()
        await bookingStore.load()
        await notificationStore.load()
    }

    private func startGroomingRequest() {
        requestStore.startCreate()
    }

    private var requestWizardPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                CustomerRequestWizardPresentationOwnership.shouldPresent(
                    storeRequested: requestStore.isShowingWizard,
                    isActiveTab: isActiveTab
                )
            },
            set: { isPresented in
                guard isActiveTab else { return }
                requestStore.setWizardPresentation(isPresented)
            }
        )
    }
}

struct CustomerHomeRequestHeroPresentation: Equatable {
    static let title = "Need grooming for your pet?"
    static let message = "Create one request and compare offers from available groomers."
    static let actionTitle = "Start Grooming Request"

    let hasPets: Bool
    let isRequestStoreBusy: Bool

    var isStartRequestDisabled: Bool {
        !hasPets
    }
}

struct CustomerHomeActiveRequestPresentation: Equatable {
    let cards: [CustomerRequestActionCardItem]
    let isLoading: Bool

    var shouldShowCarousel: Bool {
        !cards.isEmpty
    }

    var shouldShowEmptyText: Bool {
        cards.isEmpty
    }

    var shouldShowLoadingCard: Bool {
        false
    }
}

struct CustomerHomeNextBookingPresentation: Equatable {
    let booking: Booking?
    let isLoading: Bool
    let loadErrorMessage: String?

    init(
        booking: Booking?,
        isLoading: Bool,
        loadErrorMessage: String? = nil
    ) {
        self.booking = booking
        self.isLoading = isLoading
        self.loadErrorMessage = loadErrorMessage
    }

    var shouldShowBooking: Bool {
        booking != nil
    }

    var shouldShowLoading: Bool {
        false
    }

    var shouldShowLoadError: Bool {
        false
    }

    var shouldShowEmptyText: Bool {
        booking == nil
    }

    var shouldShowEmptyCard: Bool {
        false
    }

    var globalErrorPrompt: BeckonGlobalFeedbackError? {
        nil
    }
}

private struct CustomerHomeHeader: View {
    let displayName: String
    let unreadNotificationCount: Int
    let notificationAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Hi, \(displayName)")
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Welcome Back")
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: notificationAction) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(DesignTokens.Shapes.circular)
                        .overlay(
                            Circle()
                                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        )
                        .beckonShadow(DesignTokens.Shadows.smallCard)

                    if unreadNotificationCount > 0 {
                        Circle()
                            .fill(DesignTokens.Colors.notificationUnread)
                            .frame(width: 10, height: 10)
                            .padding(.top, DesignTokens.Spacing.sm)
                            .padding(.trailing, DesignTokens.Spacing.sm)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customer.home.notifications")
            .accessibilityLabel("Notifications")
            .accessibilityValue("\(unreadNotificationCount) unread")
        }
    }
}

private struct CustomerHomeRequestHero: View {
    private enum Metrics {
        static let contentWidth: CGFloat = 232
    }

    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.customerHeroBackgroundStart,
                            DesignTokens.Colors.customerHeroBackgroundEnd,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(DesignTokens.Colors.customerHeroBubble)
                        .frame(width: 110, height: 110)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottomTrailing) {
                    // beckon-ui-audit: review UI102 -- Decorative paw placement is isolated to hero bounds and never repairs content layout.
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "pawprint.fill")
                            .font(DesignTokens.Typography.pageTitle)
                            .rotationEffect(.degrees(-18))
                            .offset(x: -26, y: -24)

                        Image(systemName: "pawprint.fill")
                            .font(DesignTokens.Typography.title)
                            .rotationEffect(.degrees(20))
                    }
                    .foregroundStyle(DesignTokens.Colors.customerHeroDecoration)
                    .padding(.trailing, DesignTokens.Spacing.xl)
                    .padding(.bottom, DesignTokens.Spacing.xs)
                    .accessibilityHidden(true)
                }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(CustomerHomeRequestHeroPresentation.title)
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(CustomerHomeRequestHeroPresentation.message)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: Metrics.contentWidth, alignment: .leading)

                Button(action: action) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "scissors")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                DesignTokens.Colors.error,
                                DesignTokens.Colors.textSecondary
                            )

                        Text(CustomerHomeRequestHeroPresentation.actionTitle)
                    }
                }
                .buttonStyle(
                    BeckonSecondaryButtonStyle(
                        accent: .customerHero,
                        isFullWidth: false,
                        font: DesignTokens.Typography.action
                    )
                )
                .disabled(isDisabled)
                .accessibilityIdentifier("customer.home.start-request")
                .accessibilityLabel(CustomerHomeRequestHeroPresentation.actionTitle)

                if isDisabled {
                    Label(
                        "Add a pet profile before starting a grooming request.",
                        systemImage: "pawprint"
                    )
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("customer.home.start-request.requirement")
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
    }
}

private struct CustomerHomePetsSection: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        BeckonSection("Pets") {
            if store.isLoading, store.pets.isEmpty {
                BeckonLoadingView(
                    title: "Loading Pets…",
                    message: "Fetching your saved pet profiles.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.pets.loading")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        ForEach(store.pets) { pet in
                            CustomerHomePetTile(
                                pet: pet,
                                store: store
                            )
                        }

                        CustomerHomeAddPetTile {
                            store.startCreate()
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .accessibilityIdentifier("customer.pets.list")
            }
        }
    }
}

private struct CustomerHomePetTile: View {
    let pet: CustomerPet
    @Bindable var store: CustomerPetsStore

    var body: some View {
        Button {
            store.startEdit(pet)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                BeckonPetAvatar(
                    data: store.primaryPhotoData(for: pet),
                    fallbackText: avatar,
                    background: AnyShapeStyle(avatarBackground),
                    width: 140,
                    height: 116,
                    cornerRadius: DesignTokens.CornerRadius.input
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(DesignTokens.Typography.cardTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(petBreedLine)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(pet.displayAge ?? "Age not set")
                        .font(DesignTokens.Typography.status)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let weightAndSize = pet.displayWeightAndSize {
                        Text(weightAndSize)
                            .font(DesignTokens.Typography.status)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(width: 172, alignment: .topLeading)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            )
            .beckonShadow(DesignTokens.Shadows.carouselCard)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pet.name)
        .accessibilityValue(pet.accessibilitySummary)
        .accessibilityHint("Opens pet profile for editing.")
        .contextMenu {
            Button("Edit") {
                store.startEdit(pet)
            }

            Button("Remove", role: .destructive) {
                Task {
                    await store.softDelete(pet)
                }
            }
        }
        .accessibilityIdentifier("customer.pets.card")
    }

    private var petBreedLine: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return breed
        }

        return pet.displaySpecies
    }

    private var avatar: String {
        let searchText = "\(pet.displayBreed ?? "") \(pet.displaySpecies)"
            .lowercased()

        if searchText.contains("poodle") {
            return "🐩"
        } else if searchText.contains("cat") {
            return "🐱"
        } else if searchText.contains("bird") {
            return "🐦"
        } else if searchText.contains("rabbit") {
            return "🐰"
        } else if searchText.contains("dog") {
            return "🐶"
        }

        return "🐾"
    }

    private var avatarBackground: Color {
        let palette = [
            DesignTokens.Colors.groomerAccent.opacity(0.22),
            DesignTokens.Colors.customerPrimary.opacity(0.22),
            DesignTokens.Colors.warning.opacity(0.18),
        ]
        return palette[abs(pet.name.hashValue) % palette.count]
    }
}

private struct CustomerHomeAddPetTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .frame(width: 58, height: 58)
                    .background(DesignTokens.Colors.surfaceRaised)
                    .clipShape(DesignTokens.Shapes.circular)

                Text("Add Pet")
                    .font(DesignTokens.Typography.action)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .frame(width: 172)
            .frame(minHeight: 252)
            .background(DesignTokens.Colors.surface.opacity(0.34))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(
                    DesignTokens.Colors.border,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 5])
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Pet")
        .accessibilityHint("Opens the pet profile form.")
        .accessibilityIdentifier("customer.pets.add")
    }
}

private struct CustomerHomeActiveRequestSection: View {
    let presentation: CustomerHomeActiveRequestPresentation
    let onSelectRequest: (UUID) -> Void

    var body: some View {
        BeckonSection("Active Request") {
            if presentation.shouldShowCarousel {
                CustomerRequestActionCardSummaryCarousel(
                    cards: presentation.cards,
                    onSelectRequest: onSelectRequest
                )
                    .accessibilityIdentifier("customer.home.active-request.carousel")
            } else {
                CustomerHomeInlineDescription(CustomerRequestEmptyCopy.message)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .accessibilityIdentifier("customer.home.active-request.empty")
            }
        }
    }
}

private struct CustomerHomeNextBookingSection: View {
    let presentation: CustomerHomeNextBookingPresentation
    let store: BookingsStore
    let onOpenChat: (Booking) -> Void

    var body: some View {
        BeckonSection("Next Booking") {
            if presentation.shouldShowLoading {
                BeckonLoadingView(
                    title: "Loading Booking…",
                    message: "Checking confirmed appointments.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.home.next-booking.loading")
            } else if let booking = presentation.booking {
                NavigationLink {
                    BookingDetailView(
                        bookingID: booking.id,
                        role: .customer,
                        store: store,
                        onOpenChat: onOpenChat
                    )
                } label: {
                    BookingSummaryRow(
                        booking: booking,
                        role: .customer
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("customer.home.next-booking.view")
            } else {
                CustomerHomeInlineDescription(
                    "Accepted offers will appear here as upcoming appointments."
                )
                .padding(.vertical, DesignTokens.Spacing.sm)
                .accessibilityIdentifier("customer.home.next-booking.empty")
            }
        }
    }
}

private struct CustomerHomeStatusView: View {
    let petStore: CustomerPetsStore
    let requestStore: CustomerRequestsStore
    let nextBookingPresentation: CustomerHomeNextBookingPresentation

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            CustomerPetsStatusView(store: petStore)
            CustomerRequestsStatusView(store: requestStore)

            if let errorPrompt = nextBookingPresentation.globalErrorPrompt {
                BeckonGlobalFeedbackForwarder(error: errorPrompt)
            }
        }
    }
}

private struct CustomerHomeInlineDescription: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        CustomerPetsView(
            customerID: UUID(),
            displayName: "Lian",
            repository: CustomerPetsPreviewRepository(),
            requestRepository: CustomerHomePreviewRequestRepository(),
            notificationRepository: CustomerHomePreviewNotificationRepository(),
            bookingRepository: CustomerHomePreviewBookingRepository()
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
                coatType: nil,
                size: "M",
                weightLbs: 22,
                birthday: "2022-03-10",
                temperament: "Friendly",
                medicalNotes: nil,
                groomingNotes: "Sensitive paws",
                isActive: true
            ),
            CustomerPet(
                id: UUID(),
                customerID: customerID,
                name: "Biscuit",
                species: "Dog",
                breed: "Pomeranian",
                coatType: nil,
                size: "S",
                weightLbs: 12,
                birthday: "2023-05-14",
                temperament: "Playful",
                medicalNotes: nil,
                groomingNotes: nil,
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
            coatType: draft.coatType,
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
            coatType: draft.coatType,
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

@MainActor
private final class CustomerHomePreviewRequestRepository: CustomerRequestRepository {
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
                    breed: "Toy Poodle",
                    coatType: nil,
                    size: "S",
                    weightLbs: 18,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: "Sensitive paws",
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .fullGroom,
                serviceNotes: "Trim and brush out.",
                preferredStart: "2026-06-24T16:00:00Z",
                preferredEnd: "2026-06-24T18:00:00Z",
                locationMode: .groomerComesToCustomer,
                streetAddress: "123 Pine Street",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                travelRadiusMiles: nil,
                status: .open,
                expiresAt: "2026-06-23T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
        ]
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        []
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

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: GroomingRequestPhotoPath.make(
                customerID: customerID,
                requestID: requestID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0,
            createdAt: "2026-06-20T14:00:00Z"
        )
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        CancelGroomingRequestResult(
            requestID: requestID,
            requestStatus: .cancelled,
            cancelledTimestamp: "2026-06-20T14:00:00Z"
        )
    }
}

@MainActor
private final class CustomerHomePreviewNotificationRepository: CustomerNotificationRepository {
    func notifications(customerID: UUID) async throws -> [CustomerNotification] {
        []
    }

    func markRead(notificationID: UUID) async throws -> CustomerNotification {
        throw CustomerNotificationRepositoryError.unavailable
    }

    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        []
    }
}

@MainActor
private final class CustomerHomePreviewBookingRepository: BookingRepository {
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        [
            Booking(
                id: UUID(),
                requestID: UUID(),
                offerID: UUID(),
                customerID: participantID,
                groomerID: UUID(),
                scheduledStart: "2026-06-26T21:30:00Z",
                scheduledEnd: "2026-06-26T23:00:00Z",
                priceEstimate: 120,
                status: .confirmed,
                cancelledBy: nil,
                cancelledAt: nil,
                completedAt: nil,
                completedBy: nil,
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z",
                review: nil
            ),
        ]
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
#endif
