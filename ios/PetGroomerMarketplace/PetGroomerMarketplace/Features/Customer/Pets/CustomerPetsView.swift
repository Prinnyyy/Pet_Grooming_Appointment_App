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
            CustomerRequestWizardView(store: requestStore)
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
                    isDisabled: petStore.pets.isEmpty || requestStore.isBusy,
                    action: startGroomingRequest
                )

                CustomerHomePetsSection(store: petStore)

                CustomerHomeActiveRequestSection(
                    request: activeRequest,
                    store: requestStore,
                    startRequestAction: startGroomingRequest
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

    private var activeRequest: CustomerGroomingRequest? {
        requestStore.requests.first { $0.status.isOpenForOffers }
            ?? requestStore.requests.first
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
                Text("Welcome back")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.secondaryText)

                Text("Hi, \(displayName)")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
                    Text("Need grooming for\nyour pet?")
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
        .accessibilityElement(children: .contain)
    }
}

private struct CustomerHomePetsSection: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Your pets")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if store.isLoading, store.pets.isEmpty {
                GroomlyLoadingView(
                    title: "Loading pets…",
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
        let breed = pet.breed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return breed
        }

        return pet.species
    }

    private var avatar: String {
        let searchText = "\(pet.breed ?? "") \(pet.species)"
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

                Text("Add pet")
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
    let request: CustomerGroomingRequest?
    let store: CustomerRequestsStore
    let startRequestAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Active request")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if store.isLoading, request == nil {
                GroomlyLoadingView(
                    title: "Loading request…",
                    message: "Checking your active grooming request.",
                    accent: .customer
                )
                .accessibilityIdentifier("customer.home.active-request.loading")
            } else if let request {
                CustomerHomeActiveRequestCard(
                    request: request,
                    store: store
                )
            } else {
                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        CustomerHomeDetailHeader(
                            title: "No active request",
                            subtitle: "Create a grooming request when your pet is ready.",
                            systemImage: "doc.badge.plus"
                        )

                        Button(action: startRequestAction) {
                            Label("Start Request", systemImage: "scissors")
                        }
                        .buttonStyle(GroomlyPrimaryButtonStyle())
                        .accessibilityIdentifier("customer.home.active-request.start")
                    }
                }
            }
        }
    }
}

private struct CustomerHomeActiveRequestCard: View {
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Text(petAvatar)
                        .font(.system(size: 30))
                        .frame(width: 54, height: 54)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.2))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Open Request")
                            .font(DesignTokens.Typography.title.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)

                        Text("\(request.petSnapshot.name) · \(request.serviceType)")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        statusTitle,
                        systemImage: statusIcon,
                        tone: request.status.isOpenForOffers ? .warning : .neutral
                    )
                }

                Text(requestPrompt)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    CustomerRequestDetailView(
                        requestID: request.id,
                        store: store
                    )
                } label: {
                    Text("View Request")
                        .font(DesignTokens.Typography.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("customer.home.active-request.view")
            }
        }
    }

    private var petAvatar: String {
        let searchText = "\(request.petSnapshot.breed ?? "") \(request.petSnapshot.species)"
            .lowercased()

        if searchText.contains("poodle") {
            return "🐩"
        } else if searchText.contains("cat") {
            return "🐱"
        } else if searchText.contains("dog") {
            return "🐶"
        }

        return "🐾"
    }

    private var statusTitle: String {
        switch request.status {
        case .open:
            "Waiting for offers"
        case .hasOffers:
            "Offers ready"
        case .booked:
            "Booked"
        case .cancelled:
            "Cancelled"
        case .expired:
            "Expired"
        }
    }

    private var statusIcon: String {
        request.status.isOpenForOffers ? "clock.fill" : "checkmark.circle"
    }

    private var requestPrompt: String {
        switch request.status {
        case .open:
            "Matched groomers can review your request and send offers."
        case .hasOffers:
            "You have groomer responses waiting in the request detail."
        case .booked:
            "This request has become a booking."
        case .cancelled, .expired:
            "This request is closed."
        }
    }
}

private struct CustomerHomeNextBookingSection: View {
    let booking: Booking?
    let store: BookingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Next booking")
                .font(.title2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            if store.isLoading, booking == nil {
                GroomlyLoadingView(
                    title: "Loading booking…",
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
                        title: "No booking yet",
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
        if hasStatus {
            VStack(spacing: 0) {
                CustomerPetsStatusView(store: petStore)
                CustomerRequestsStatusView(store: requestStore)

                if let errorMessage = bookingStore.errorMessage {
                    GroomlyErrorBanner(
                        title: "We could not load bookings",
                        message: errorMessage
                    )
                    .padding(.horizontal, DesignTokens.Spacing.standard)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private var hasStatus: Bool {
        petStore.isSaving
            || petStore.isUploading
            || petStore.noticeMessage != nil
            || (petStore.errorMessage != nil && !petStore.isShowingPetForm)
            || requestStore.isSubmitting
            || requestStore.noticeMessage != nil
            || (requestStore.errorMessage != nil && !requestStore.isShowingWizard)
            || bookingStore.errorMessage != nil
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
                size: "Small",
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
                size: "Small",
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
                    size: "Small",
                    weightLbs: 18,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: "Sensitive paws",
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: "Full Groom",
                serviceNotes: "Trim and brush out.",
                preferredStart: "2026-06-24T16:00:00Z",
                preferredEnd: "2026-06-24T18:00:00Z",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
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
