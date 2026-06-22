import SwiftUI

struct CustomerRequestsView: View {
    @State private var store: CustomerRequestsStore

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository
    ) {
        _store = State(
            initialValue: CustomerRequestsStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository
            )
        )
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            requestsContent
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

    @ViewBuilder
    private var requestsContent: some View {
        if store.isLoading, store.pets.isEmpty, store.requests.isEmpty {
            GroomlyLoadingView(
                title: "Loading requests…",
                message: "Fetching your pet's grooming requests.",
                accent: .customer
            )
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .accessibilityIdentifier("customer.requests.loading")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomlySectionHeader(
                        "Grooming requests",
                        subtitle: "Track open requests and review groomer responses from one place."
                    )

                    CustomerRequestsStartCard(store: store)

                    if store.requests.isEmpty {
                        GroomlyEmptyState(
                            title: "No requests yet",
                            message: "Create a request when your pet is ready for grooming.",
                            systemImage: "doc.badge.plus",
                            accent: .customer
                        )
                        .accessibilityIdentifier("customer.requests.empty")
                    } else {
                        LazyVStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(store.requests) { request in
                                NavigationLink {
                                    CustomerRequestDetailView(
                                        requestID: request.id,
                                        store: store
                                    )
                                } label: {
                                    CustomerRequestSummaryRow(request: request)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("customer.requests.list")
        }
    }
}

private struct CustomerRequestsStartCard: View {
    @Bindable var store: CustomerRequestsStore

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "scissors")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl
                        )
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.16))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Start a grooming request")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(promptText)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    store.startCreate()
                } label: {
                    Label("Start grooming request", systemImage: "plus.circle")
                }
                .buttonStyle(GroomlyPrimaryButtonStyle())
                .disabled(store.isBusy || store.pets.isEmpty)
                .accessibilityIdentifier("customer.requests.start")

                if store.pets.isEmpty {
                    GroomlyStatusChip(
                        "Add a pet on Home first",
                        systemImage: "pawprint",
                        tone: .warning
                    )
                }
            }
        }
    }

    private var promptText: String {
        if store.pets.isEmpty {
            return "Add a pet on the Home tab before publishing a request."
        }

        return "Share the service, time window, and location so matched groomers can make offers."
    }
}

private struct CustomerRequestSummaryRow: View {
    let request: CustomerGroomingRequest

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(request.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(request.locationSummary)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }

                    Spacer(minLength: DesignTokens.Spacing.md)

                    GroomlyStatusChip(
                        request.status.title,
                        systemImage: statusSystemImage,
                        tone: statusTone
                    )
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "calendar")
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)

                    Text(timeSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statusTone: GroomlyStatusChip.Tone {
        request.status.isOpenForOffers ? .customer : .neutral
    }

    private var statusSystemImage: String {
        request.status.isOpenForOffers ? "clock" : "checkmark"
    }

    private var timeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
    }
}

struct CustomerRequestDetailView: View {
    let requestID: UUID
    let store: CustomerRequestsStore

    var body: some View {
        if let request = store.request(withID: requestID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Request details",
                            subtitle: "Review the request and compare groomer offers before booking."
                        )

                        requestCard(request)
                        petSnapshotCard(request)
                        scheduleLocationCard(request)

                        CustomerOfferReviewSection(
                            request: request,
                            store: store
                        )

                        if request.status.isOpenForOffers {
                            cancellationNotice
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(request.petSnapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.requests.detail")
            .task(id: request.id) {
                await store.loadOffers(for: request)
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Request unavailable",
                    message: "Refresh requests and try again.",
                    systemImage: "doc.text.magnifyingglass",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Request")
        }
    }

    private func requestCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: request.serviceType,
                    subtitle: request.locationSummary,
                    systemImage: "doc.text.fill"
                ) {
                    GroomlyStatusChip(
                        request.status.title,
                        systemImage: request.status.detailSystemImage,
                        tone: request.status.detailTone
                    )
                }

                if let serviceNotes = request.serviceNotes {
                    Text(serviceNotes)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func petSnapshotCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Pet snapshot",
                    subtitle: "Frozen request context from the selected pet.",
                    systemImage: "pawprint.fill"
                )

                DetailMetadataRow(title: "Pet", value: request.petSnapshot.name, systemImage: "heart.fill")
                DetailMetadataRow(title: "Species", value: request.petSnapshot.species, systemImage: "tag.fill")

                if let breed = request.petSnapshot.breed {
                    DetailMetadataRow(title: "Breed", value: breed, systemImage: "list.bullet")
                }

                if let size = request.petSnapshot.size {
                    DetailMetadataRow(title: "Size", value: size, systemImage: "ruler")
                }

                DetailMetadataRow(
                    title: "Photos",
                    value: "\(request.photoSnapshot.count)",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private func scheduleLocationCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Preferred time and location",
                    subtitle: "The window and area groomers used for this offer.",
                    systemImage: "calendar"
                )

                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )
                DetailMetadataRow(title: "City", value: request.city, systemImage: "building.2")
                DetailMetadataRow(title: "State", value: request.state, systemImage: "map")
                DetailMetadataRow(title: "ZIP", value: request.zipCode, systemImage: "number")
            }
        }
    }

    private var cancellationNotice: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Cancellation",
                    subtitle: "Request cancellation needs a controlled backend RPC and is not connected yet.",
                    systemImage: "lock.fill"
                ) {
                    GroomlyStatusChip(
                        "Deferred",
                        systemImage: "lock",
                        tone: .neutral
                    )
                }
            }
        }
    }
}

private struct CustomerOfferReviewSection: View {
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore

    private var offers: [CustomerOfferReview] {
        store.offers(for: request)
    }

    private var pendingOffers: [CustomerOfferReview] {
        offers.filter(\.isPending)
    }

    private var historicalOffers: [CustomerOfferReview] {
        offers.filter { !$0.isPending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Offers",
                subtitle: "Compare pending offers and review previous offer activity."
            )

            Group {
                if store.isLoadingOffers(for: request), offers.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading offers…",
                        message: "Checking for groomer responses.",
                        accent: .customer
                    )
                        .accessibilityIdentifier("customer.offers.loading")
                } else if let errorMessage = store.offerError(for: request) {
                    GroomlyErrorBanner(
                        title: "We could not load offers",
                        message: errorMessage
                    ) {
                        Button {
                            Task {
                                await store.loadOffers(for: request)
                            }
                        } label: {
                            Label("Refresh offers", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GroomlySecondaryButtonStyle())
                        .disabled(store.isLoadingOffers(for: request))
                    }
                        .accessibilityIdentifier("customer.offers.error")
                } else if offers.isEmpty {
                    GroomlyEmptyState(
                        title: "No offers yet",
                        message: "Matched groomers can submit offers while this request is open.",
                        systemImage: "tag",
                        accent: .customer
                    )
                    .accessibilityIdentifier("customer.offers.empty")
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        if !pendingOffers.isEmpty {
                            offerGroup(
                                title: "Pending offers",
                                offers: pendingOffers,
                                isHistorical: false
                            )
                            .accessibilityIdentifier("customer.offers.pending-list")
                        } else {
                            GroomlyCard {
                                Text("There are no pending offers for this request.")
                                    .font(DesignTokens.Typography.body)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !historicalOffers.isEmpty {
                            offerGroup(
                                title: "Offer history",
                                offers: historicalOffers,
                                isHistorical: true
                            )
                            .accessibilityIdentifier("customer.offers.history-list")
                        }
                    }
                }
            }

            Button {
                Task {
                    await store.loadOffers(for: request)
                }
            } label: {
                Label("Refresh offers", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GroomlySecondaryButtonStyle())
            .disabled(store.isLoadingOffers(for: request))
            .accessibilityIdentifier("customer.offers.refresh")
        }
    }

    private func offerGroup(
        title: String,
        offers: [CustomerOfferReview],
        isHistorical: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(offers) { offerReview in
                    NavigationLink {
                        CustomerOfferDetailView(
                            request: request,
                            offerID: offerReview.id,
                            store: store
                        )
                    } label: {
                        CustomerOfferSummaryRow(
                            offerReview: offerReview,
                            isHistorical: isHistorical
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CustomerOfferSummaryRow: View {
    let offerReview: CustomerOfferReview
    var isHistorical = false

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(offerReview.groomerTitle)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(offerReview.groomerLocationSummary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Spacer(minLength: DesignTokens.Spacing.md)

                    GroomlyStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    Text(offerReview.offer.priceSummary)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(isHistorical ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textPrimary)

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(offerReview.proposedTimeSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct CustomerOfferDetailView: View {
    let request: CustomerGroomingRequest
    let offerID: UUID
    let store: CustomerRequestsStore

    private var offerReview: CustomerOfferReview? {
        store.offers(for: request).first { $0.id == offerID }
    }

    var body: some View {
        if let offerReview {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Offer",
                            subtitle: "Review the groomer proposal before accepting."
                        )

                        groomerCard(offerReview)
                        offerCard(offerReview)
                        requestCard(offerReview)
                        acceptanceCard(offerReview)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Offer")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.offers.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Offer unavailable",
                    message: "Refresh offers and try again.",
                    systemImage: "tag.slash",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Offer")
        }
    }

    private func groomerCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.groomerTitle,
                    subtitle: offerReview.groomerLocationSummary,
                    systemImage: "person.crop.circle.fill"
                ) {
                    if offerReview.groomerProfile?.isVerified == true {
                        GroomlyStatusChip(
                            "Verified",
                            systemImage: "checkmark.seal.fill",
                            tone: .success
                        )
                        .accessibilityLabel("Verified groomer")
                    }
                }

                DetailMetadataRow(
                    title: "Rating",
                    value: offerReview.ratingSummary,
                    systemImage: "star.fill"
                )

                if let bio = offerReview.groomerProfile?.bio {
                    Text(bio)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func offerCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.offer.priceSummary,
                    subtitle: offerReview.proposedTimeSummary,
                    systemImage: "tag.fill"
                ) {
                    GroomlyStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )

                if let message = offerReview.offer.message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: request.petSnapshot.name,
                    subtitle: request.serviceType,
                    systemImage: "pawprint.fill"
                ) {
                    GroomlyStatusChip(
                        request.status.title,
                        systemImage: request.status.detailSystemImage,
                        tone: request.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Requested time",
                    value: requestTimeSummary,
                    systemImage: "calendar"
                )
            }
        }
    }

    private func acceptanceCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Acceptance",
                    subtitle: acceptanceMessage(for: offerReview),
                    systemImage: "checkmark.circle.fill"
                )

                if let errorMessage = store.errorMessage {
                    GroomlyErrorBanner(
                        title: "We could not accept this offer",
                        message: errorMessage
                    )
                }

                if offerReview.offer.status == .pending,
                   request.status.isOpenForOffers {
                    Button {
                        Task {
                            await store.accept(
                                offerReview: offerReview,
                                for: request
                            )
                        }
                    } label: {
                        Label(
                            store.isAcceptingOffer(offerReview.offer.id) ? "Accepting…" : "Accept offer",
                            systemImage: "checkmark.circle"
                        )
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle())
                    .disabled(store.isAcceptingOffer(offerReview.offer.id))
                    .accessibilityIdentifier("customer.offers.accept")

                    Text("The backend creates the booking and conversation atomically. If the groomer becomes unavailable, no local booking is created.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    GroomlyStatusChip(
                        acceptanceStatusTitle(for: offerReview),
                        systemImage: acceptanceStatusSystemImage(for: offerReview),
                        tone: acceptanceStatusTone(for: offerReview)
                    )
                }
            }
        }
    }

    private func acceptanceMessage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .pending,
           request.status.isOpenForOffers {
            return "Accepting creates the booking and booking chat through the existing backend transaction."
        } else if offerReview.offer.status == .acceptedByCustomer {
            return "This offer has been accepted. Check the Bookings tab for the appointment."
        } else if request.status == .booked {
            return "This request is already booked."
        } else {
            return "This offer can no longer be accepted."
        }
    }

    private func acceptanceStatusTitle(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer {
            return "Accepted"
        } else if request.status == .booked {
            return "Booked"
        } else {
            return "Unavailable"
        }
    }

    private func acceptanceStatusSystemImage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return "checkmark.circle.fill"
        }

        return "xmark.circle"
    }

    private func acceptanceStatusTone(for offerReview: CustomerOfferReview) -> GroomlyStatusChip.Tone {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return .success
        }

        return .neutral
    }

    private var requestTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
    }
}

private struct DetailCardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(
                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.md
                )
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

extension DetailCardHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        trailing = EmptyView()
    }
}

private struct DetailMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Label {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.caption)
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

private extension GroomingRequestStatus {
    var detailTone: GroomlyStatusChip.Tone {
        switch self {
        case .open, .hasOffers:
            .customer
        case .booked:
            .success
        case .cancelled, .expired:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .open:
            "clock"
        case .hasOffers:
            "tag"
        case .booked:
            "checkmark.circle"
        case .cancelled:
            "xmark.circle"
        case .expired:
            "hourglass"
        }
    }
}

private extension GroomerOfferStatus {
    var detailTone: GroomlyStatusChip.Tone {
        switch self {
        case .pending:
            .customer
        case .acceptedByCustomer:
            .success
        case .declinedByCustomer, .withdrawnByGroomer, .expired:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .pending:
            "clock"
        case .acceptedByCustomer:
            "checkmark.circle"
        case .declinedByCustomer:
            "xmark.circle"
        case .withdrawnByGroomer:
            "arrow.uturn.backward"
        case .expired:
            "hourglass"
        }
    }
}

struct CustomerRequestWizardView: View {
    @Bindable var store: CustomerRequestsStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Request details",
                            subtitle: "Share the basics so matched groomers can make accurate offers."
                        )

                        petCard
                        serviceCard
                        preferredTimeCard
                        locationCard
                        reviewCard

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Check request details",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.requests.form-error")
                        }

                        Button {
                            publish()
                        } label: {
                            Label(
                                store.isSubmitting ? "Publishing…" : "Publish request",
                                systemImage: "paperplane.fill"
                            )
                        }
                        .buttonStyle(GroomlyPrimaryButtonStyle())
                        .disabled(store.isSubmitting || store.pets.isEmpty)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .tint(DesignTokens.Colors.customerPrimaryDark)
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
                        publish()
                    }
                    .disabled(store.isSubmitting || store.pets.isEmpty)
                    .accessibilityIdentifier("customer.requests.publish")
                }
            }
        }
        .interactiveDismissDisabled(store.isSubmitting)
    }

    private var petCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Pet",
                    subtitle: "Choose the pet this request is for.",
                    systemImage: "pawprint.fill"
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Picker("Pet", selection: $store.selectedPetID) {
                        ForEach(store.pets) { pet in
                            Text(pet.name)
                                .tag(Optional(pet.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .groomlyFormField()

                    if store.pets.isEmpty {
                        GroomlyStatusChip(
                            "Add a pet on Home first",
                            systemImage: "pawprint",
                            tone: .warning
                        )
                    }
                }
            }
        }
    }

    private var serviceCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Service",
                    subtitle: "Describe the grooming help your pet needs.",
                    systemImage: "scissors"
                )

                TextField("Service type", text: $store.serviceType)
                    .textContentType(.none)
                    .groomlyFormField()

                TextField("Notes", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .groomlyFormField()
            }
        }
    }

    private var preferredTimeCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Preferred time",
                    subtitle: "Pick the service window you want groomers to offer around.",
                    systemImage: "calendar"
                )

                DatePicker(
                    "Start",
                    selection: $store.preferredStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .groomlyFormField()

                DatePicker(
                    "End",
                    selection: $store.preferredEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .groomlyFormField()
            }
        }
    }

    private var locationCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Location",
                    subtitle: "Use the city, state, and ZIP where the appointment should happen.",
                    systemImage: "mappin.and.ellipse"
                )

                TextField("City", text: $store.city)
                    .textContentType(.addressCity)
                    .groomlyFormField()

                TextField("State", text: $store.state)
                    .textContentType(.addressState)
                    .groomlyFormField()

                TextField("ZIP code", text: $store.zipCode)
                    .textContentType(.postalCode)
                    .keyboardType(.numbersAndPunctuation)
                    .groomlyFormField()
            }
        }
    }

    private var reviewCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Review",
                    subtitle: "Check the request before publishing it to matched groomers.",
                    systemImage: "checklist"
                )

                WizardReviewRow(
                    title: "Pet",
                    value: store.selectedPet?.name ?? "Choose a pet",
                    isMissing: store.selectedPet == nil
                )

                WizardReviewRow(
                    title: "Service",
                    value: serviceSummary,
                    isMissing: serviceSummary == "Required"
                )

                WizardReviewRow(
                    title: "Location",
                    value: reviewLocation,
                    isMissing: reviewLocation == "Required"
                )
            }
        }
    }

    private var serviceSummary: String {
        let service = store.serviceType.trimmingCharacters(in: .whitespacesAndNewlines)
        return service.isEmpty ? "Required" : service
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

    private func publish() {
        Task {
            await store.publish()
        }
    }
}

private struct WizardCardHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(width: 36, height: 36)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WizardReviewRow: View {
    let title: String
    let value: String
    let isMissing: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            if isMissing {
                GroomlyStatusChip(
                    value,
                    systemImage: "exclamationmark.circle",
                    tone: .warning
                )
            } else {
                Text(value)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct CustomerRequestsStatusView: View {
    let store: CustomerRequestsStore

    var body: some View {
        if hasStatus {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if store.isSubmitting {
                    GroomlyCard(padding: DesignTokens.Spacing.md) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.customerPrimary)

                            Text("Publishing…")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }
                    }
                }

                if let noticeMessage = store.noticeMessage {
                    GroomlyCard(padding: DesignTokens.Spacing.md) {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                            GroomlyStatusChip(
                                "Published",
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
                   !store.isShowingWizard {
                    GroomlyErrorBanner(
                        title: "We could not update requests",
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
        store.isSubmitting
            || store.noticeMessage != nil
            || (store.errorMessage != nil && !store.isShowingWizard)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CustomerRequestsView(
            customerID: UUID(),
            petRepository: CustomerRequestsPreviewPetRepository(),
            requestRepository: CustomerRequestsPreviewRequestRepository(),
            bookingRepository: CustomerRequestsPreviewBookingRepository()
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

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        [
            CustomerOfferReview(
                offer: GroomerOffer(
                    id: UUID(),
                    requestID: requestID,
                    matchID: UUID(),
                    customerID: customerID,
                    groomerID: UUID(),
                    proposedStart: "2026-06-22T16:30:00Z",
                    proposedEnd: "2026-06-22T18:00:00Z",
                    priceEstimate: 125,
                    message: "I can do a calm full groom.",
                    status: .pending,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: nil,
                    createdAt: "2026-06-20T13:00:00Z",
                    updatedAt: "2026-06-20T13:00:00Z"
                ),
                groomerProfile: GroomerProfile(
                    userID: UUID(),
                    businessName: "Fresh Paws Grooming",
                    bio: "Low-stress grooming for small dogs.",
                    yearsExperience: 5,
                    baseCity: "Seattle",
                    baseState: "WA",
                    serviceRadiusMiles: 12,
                    ratingAverage: 0,
                    ratingCount: 0,
                    isActive: true,
                    isVerified: false
                )
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

@MainActor
private final class CustomerRequestsPreviewBookingRepository: BookingRepository {
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        []
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        AcceptGroomerOfferResult(
            bookingID: UUID(),
            conversationID: UUID(),
            requestID: UUID(),
            offerID: offerID,
            bookingStatus: .confirmed,
            offerStatus: .acceptedByCustomer,
            requestStatus: .booked
        )
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
