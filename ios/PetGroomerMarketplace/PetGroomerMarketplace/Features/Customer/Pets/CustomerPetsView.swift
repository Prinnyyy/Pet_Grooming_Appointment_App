import PhotosUI
import SwiftUI

struct CustomerPetsView: View {
    private let displayName: String
    @State private var petStore: CustomerPetsStore
    @State private var requestStore: CustomerRequestsStore
    @State private var bookingStore: BookingsStore

    init(
        customerID: UUID,
        displayName: String? = nil,
        repository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository
    ) {
        let trimmedName = displayName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        self.displayName = trimmedName.isEmpty ? "there" : trimmedName
        _petStore = State(
            initialValue: CustomerPetsStore(
                customerID: customerID,
                repository: repository
            )
        )
        _requestStore = State(
            initialValue: CustomerRequestsStore(
                customerID: customerID,
                petRepository: repository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository
            )
        )
        _bookingStore = State(
            initialValue: BookingsStore(
                participantID: customerID,
                role: .customer,
                repository: bookingRepository
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
        .safeAreaInset(edge: .bottom) {
            CustomerHomeStatusView(
                petStore: petStore,
                requestStore: requestStore,
                bookingStore: bookingStore
            )
        }
        .sheet(isPresented: $petStore.isShowingPetForm) {
            CustomerPetFormView(store: petStore)
        }
        .sheet(isPresented: $requestStore.isShowingWizard) {
            CustomerRequestWizardView(store: requestStore) {
                requestStore.cancelWizard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    petStore.startCreate()
                }
            }
        }
        .task {
            await loadHome()
        }
        .accessibilityIdentifier("customer.home")
    }

    private var screenContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                CustomerHomeHeader(
                    displayName: displayName,
                    notificationAction: {}
                )

                CustomerHomeRequestHero(
                    isDisabled: requestHeroPresentation.isStartRequestDisabled,
                    action: startGroomingRequest
                )

                CustomerHomePetsSection(store: petStore)

                CustomerHomeActiveRequestSection(
                    presentation: activeRequestPresentation
                )

                CustomerHomeNextBookingSection(
                    booking: nextBooking,
                    store: bookingStore
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl * 4)
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
        bookingStore.bookings
            .sorted { lhs, rhs in
                let lhsDate = GroomingRequestDateFormatting.parsedDate(
                    from: lhs.scheduledStart
                ) ?? .distantFuture
                let rhsDate = GroomingRequestDateFormatting.parsedDate(
                    from: rhs.scheduledStart
                ) ?? .distantFuture

                return lhsDate < rhsDate
            }
            .first { $0.status == .confirmed }
            ?? bookingStore.bookings.first
    }

    @MainActor
    private func loadHome() async {
        await petStore.load()
        await requestStore.load()
        await bookingStore.load()
    }

    private func startGroomingRequest() {
        requestStore.startCreate()
    }
}

struct CustomerHomeRequestHeroPresentation: Equatable {
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

private struct CustomerHomeHeader: View {
    let displayName: String
    let notificationAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Text("🙂")
                .font(.system(size: 32))
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.groomerAccent.opacity(0.44),
                            DesignTokens.Colors.customerPrimary.opacity(0.34),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityLabel("Customer avatar")

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Hi, \(displayName)")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Welcome Back")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: notificationAction) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(DesignTokens.Shapes.circular)
                        .overlay(
                            Circle()
                                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        )
                        .groomlyShadow(DesignTokens.Shadows.smallCard)

                    Circle()
                        .fill(DesignTokens.Colors.groomerAccent)
                        .frame(width: 10, height: 10)
                        .offset(x: -10, y: 9)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("customer.home.notifications")
            .accessibilityLabel("Notifications")
        }
    }
}

private struct CustomerHomeRequestHero: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.customerPrimary,
                            DesignTokens.Colors.customerPrimary.opacity(0.66),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 160, height: 160)
                .offset(x: 46, y: -76)
                .accessibilityHidden(true)

            HStack(spacing: -8) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 38, weight: .bold))
                    .rotationEffect(.degrees(-12))

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 30, weight: .bold))
                    .rotationEffect(.degrees(18))
                    .offset(y: 26)
            }
            .foregroundStyle(DesignTokens.Colors.textPrimary.opacity(0.48))
            .padding(.trailing, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.md)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Need Grooming for\nYour Pet?")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Create one request and compare offers from available groomers.")
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: action) {
                    Label("Start Grooming Request", systemImage: "scissors")
                        .font(DesignTokens.Typography.headline.weight(.bold))
                        .foregroundStyle(
                            isDisabled
                                ? DesignTokens.Colors.textTertiary
                                : DesignTokens.Colors.customerPrimaryDark
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(.white)
                        .clipShape(Capsule())
                        .groomlyShadow(DesignTokens.Shadows.primaryAction)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityIdentifier("customer.home.start-request")
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 230)
        .clipShape(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct CustomerHomePetsSection: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Your Pets")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if store.isLoading, store.pets.isEmpty {
                GroomlyLoadingView(
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
                Text(avatar)
                    .font(.system(size: 58))
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
                    .background(avatarBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(DesignTokens.Typography.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(petBreedLine)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(width: 172, height: 232, alignment: .topLeading)
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
            .groomlyShadow(DesignTokens.Shadows.smallCard)
        }
        .buttonStyle(.plain)
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
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .frame(width: 58, height: 58)
                    .background(DesignTokens.Colors.surfaceRaised)
                    .clipShape(DesignTokens.Shapes.circular)

                Text("Add Pet")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .frame(width: 172, height: 232)
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
        .accessibilityIdentifier("customer.pets.add")
    }
}

private struct CustomerHomeActiveRequestSection: View {
    let presentation: CustomerHomeActiveRequestPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Active Request")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if presentation.shouldShowCarousel {
                CustomerRequestActionCardSummaryCarousel(cards: presentation.cards)
                    .accessibilityIdentifier("customer.home.active-request.carousel")
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(CustomerRequestEmptyCopy.title)
                        .font(DesignTokens.Typography.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(CustomerRequestEmptyCopy.message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .accessibilityIdentifier("customer.home.active-request.empty")
            }
        }
    }
}

private struct CustomerHomeNextBookingSection: View {
    let booking: Booking?
    let store: BookingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Next Booking")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if store.isLoading, booking == nil {
                GroomlyLoadingView(
                    title: "Loading Booking…",
                    message: "Checking confirmed appointments.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.home.next-booking.loading")
            } else if let booking {
                NavigationLink {
                    BookingDetailView(
                        bookingID: booking.id,
                        role: .customer,
                        store: store
                    )
                } label: {
                    CustomerHomeNextBookingCard(booking: booking)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("customer.home.next-booking.view")
            } else {
                GroomlyCard {
                    CustomerHomeDetailHeader(
                        title: "No Booking Yet",
                        subtitle: "Accepted offers will appear here as upcoming appointments.",
                        systemImage: "calendar.badge.clock"
                    )
                }
            }
        }
    }
}

private struct CustomerHomeNextBookingCard: View {
    let booking: Booking

    var body: some View {
        GroomlyCard {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Text("💇🏻‍♀️")
                    .font(.system(size: 30))
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Colors.customerPrimary)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(booking.participantSummary(for: .customer))
                        .font(DesignTokens.Typography.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(bookingTime)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.title.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.border)
                    .accessibilityHidden(true)
            }
        }
    }

    private var bookingTime: String {
        GroomingRequestDateFormatting.displayString(from: booking.scheduledStart)
    }
}

private struct CustomerHomeStatusView: View {
    let petStore: CustomerPetsStore
    let requestStore: CustomerRequestsStore
    let bookingStore: BookingsStore

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            CustomerPetsStatusView(store: petStore)
            CustomerRequestsStatusView(store: requestStore)

            if let errorMessage = bookingStore.errorMessage {
                GroomlyErrorBanner(
                    title: "We Could Not Load Bookings",
                    message: errorMessage
                )
                .padding(.horizontal, DesignTokens.Spacing.standard)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
        }
    }
}

private struct CustomerHomeDetailHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(width: 44, height: 44)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
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
        [pet.displaySpecies, pet.displayBreed, pet.displaySize]
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

                    Picker("Species", selection: speciesBinding) {
                        ForEach(CustomerPetSpecies.allCases) { species in
                            Text(species.title).tag(species)
                        }
                    }

                    Picker("Breed", selection: $store.formBreed) {
                        ForEach(CustomerPetBreed.options(for: store.formSpecies)) { breed in
                            Text(breed.title).tag(breed)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section("Optional details") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("Weight")
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Spacer()

                            Text(weightText)
                                .font(DesignTokens.Typography.body.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        }

                        Slider(
                            value: $store.formWeightLbs,
                            in: 5...101,
                            step: 1
                        )
                        .tint(DesignTokens.Colors.customerPrimary)

                        Text("Size: \(CustomerPetSizeCode.code(forWeightLbs: store.formWeightLbs).title)")
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)

                    Toggle("Birthday Known", isOn: birthdayKnownBinding)
                        .tint(DesignTokens.Colors.customerPrimary)

                    if store.formBirthdayDate != nil {
                        DatePicker(
                            "Birthday",
                            selection: birthdayBinding,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }

                    Picker("Temperament", selection: $store.formTemperament) {
                        ForEach(CustomerPetTemperament.allCases) { temperament in
                            Text(temperament.title).tag(temperament)
                        }
                    }

                    TextField("Medical notes", text: $store.formMedicalNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .groomlyFormField()

                    TextField("Grooming notes", text: $store.formGroomingNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .groomlyFormField()
                }
                .listRowBackground(Color.clear)

                Section("Photos") {
                    CustomerPetFormPhotoPicker(store: store)

                    ForEach(store.pendingFormPhotos) { photo in
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "photo")
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .accessibilityHidden(true)

                            Text("\(photo.contentType.fileExtension.uppercased()) photo")
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Spacer()

                            Button(role: .destructive) {
                                store.removePendingFormPhoto(photo)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isSaving)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                if let errorMessage = store.errorMessage {
                    Section {
                        GroomlyErrorBanner(
                            title: "Check Pet Details",
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

    private var speciesBinding: Binding<CustomerPetSpecies> {
        Binding(
            get: { store.formSpecies },
            set: { store.updateFormSpecies($0) }
        )
    }

    private var birthdayKnownBinding: Binding<Bool> {
        Binding(
            get: { store.formBirthdayDate != nil },
            set: { isKnown in
                store.formBirthdayDate = isKnown
                    ? store.formBirthdayDate ?? Date()
                    : nil
            }
        )
    }

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { store.formBirthdayDate ?? Date() },
            set: { store.formBirthdayDate = $0 }
        )
    }

    private var weightText: String {
        if store.formWeightLbs < 10 {
            return "<10 lbs"
        }
        if store.formWeightLbs > 100 {
            return ">100 lbs"
        }
        return "\(Int(store.formWeightLbs.rounded())) lbs"
    }
}

private struct CustomerPetFormPhotoPicker: View {
    @Bindable var store: CustomerPetsStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label("Add Pet Photo", systemImage: "camera")
                .lineLimit(1)
        }
        .buttonStyle(GroomlySecondaryButtonStyle(isFullWidth: false))
        .disabled(store.isSaving)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await addPendingPhoto(newItem)
            }
        }
    }

    private func addPendingPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(CustomerPetPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        store.addPendingFormPhoto(
            data: data,
            contentType: contentType
        )
    }
}

private struct CustomerPetsStatusView: View {
    let store: CustomerPetsStore

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }

            if hasInlineStatus {
                inlineStatus
            }
        }
    }

    private var inlineStatus: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if store.isSaving || store.isUploading {
                GroomlyStatusProgressToast(
                    store.isUploading ? "Uploading…" : "Saving…",
                    tint: DesignTokens.Colors.customerPrimary
                )
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingPetForm {
                GroomlyErrorBanner(
                    title: "We Could Not Update Your Pets",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.standard)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isSaving
            || store.isUploading
            || (store.errorMessage != nil && !store.isShowingPetForm)
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
