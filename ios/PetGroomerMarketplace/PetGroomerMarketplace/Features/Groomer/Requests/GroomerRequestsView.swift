import SwiftUI

struct GroomerRequestsView: View {
    @State private var store: GroomerRequestsStore

    init(
        groomerID: UUID,
        repository: any GroomerRequestRepository
    ) {
        _store = State(
            initialValue: GroomerRequestsStore(
                groomerID: groomerID,
                repository: repository
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            feedContent
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
            GroomerRequestsStatusView(store: store)
        }
        .task {
            await store.load()
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if store.isLoading, store.matchedRequests.isEmpty {
            ScrollView {
                GroomlyLoadingView(
                    title: "Loading matched requests…",
                    message: "We are checking active customer requests that match your services.",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.requests.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomlySectionHeader(
                        "Matched requests",
                        subtitle: "Review open requests that fit your profile before making an offer."
                    )

                    if store.matchedRequests.isEmpty {
                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Requests unavailable",
                                message: errorMessage
                            ) {
                                Button {
                                    Task {
                                        await store.load()
                                    }
                                } label: {
                                    Label("Try again", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                                .disabled(store.isBusy)
                            }
                            .accessibilityIdentifier("groomer.requests.error")
                        } else {
                            GroomlyEmptyState(
                                title: "No matched requests",
                                message: "New active customer requests will appear here when they match your profile and services.",
                                systemImage: "tray",
                                accent: .groomer
                            ) {
                                Button {
                                    Task {
                                        await store.load()
                                    }
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                                .disabled(store.isBusy)
                            }
                            .accessibilityIdentifier("groomer.requests.empty")
                        }
                    } else {
                        ForEach(store.matchedRequests) { matchedRequest in
                            NavigationLink {
                                GroomerRequestDetailView(
                                    matchID: matchedRequest.id,
                                    store: store
                                )
                            } label: {
                                GroomerRequestSummaryRow(
                                    matchedRequest: matchedRequest
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
            .accessibilityIdentifier("groomer.requests.list")
        }
    }
}

private struct GroomerRequestSummaryRow: View {
    let matchedRequest: GroomerMatchedRequest

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(matchedRequest.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(matchedRequest.request.serviceType)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        statusSummary,
                        systemImage: statusSystemImage,
                        tone: statusTone
                    )
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Label(matchedRequest.locationSummary, systemImage: "mappin.and.ellipse")
                    Label(timeSummary, systemImage: "calendar")
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(matchedRequest.matchSummary)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var statusSummary: String {
        if let offer = matchedRequest.offer {
            return "Offer \(offer.status.title.lowercased())"
        }

        return matchedRequest.matchSummary
    }

    private var statusTone: GroomlyStatusChip.Tone {
        if matchedRequest.offer?.status == .pending {
            return .warning
        }

        return matchedRequest.request.status.isOpenForOffers ? .groomer : .neutral
    }

    private var statusSystemImage: String {
        if matchedRequest.offer?.status == .pending {
            return "paperplane.fill"
        }

        return matchedRequest.request.status.isOpenForOffers ? "sparkles" : "checkmark"
    }

    private var timeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: matchedRequest.request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: matchedRequest.request.preferredEnd))"
    }
}

private struct GroomerRequestDetailView: View {
    let matchID: UUID
    let store: GroomerRequestsStore

    @State private var didInitializeOfferForm = false
    @State private var proposedStart = Date().addingTimeInterval(24 * 60 * 60)
    @State private var proposedEnd = Date().addingTimeInterval(26 * 60 * 60)
    @State private var priceEstimateText = ""
    @State private var message = ""

    var body: some View {
        if let matchedRequest = store.matchedRequest(withID: matchID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        detailHero(for: matchedRequest)
                        matchCard(for: matchedRequest)
                        requestCard(for: matchedRequest)
                        petSnapshotCard(for: matchedRequest)
                        scheduleLocationCard(for: matchedRequest)
                        offerSection(for: matchedRequest)
                        actionsCard(for: matchedRequest)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                }
            }
            .navigationTitle(matchedRequest.request.petSnapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("groomer.requests.detail")
            .task(id: matchedRequest.request.id) {
                initializeOfferFormIfNeeded(for: matchedRequest)
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Request unavailable",
                    message: "Refresh matched requests and try again.",
                    systemImage: "tray",
                    accent: .groomer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Request")
        }
    }

    private func detailHero(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(matchedRequest.request.petSnapshot.name)
                            .font(DesignTokens.Typography.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(matchedRequest.request.serviceType)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        matchedRequest.request.status.title,
                        systemImage: matchedRequest.request.status.groomerSystemImage,
                        tone: matchedRequest.request.status.groomerTone
                    )
                }

                Text(matchedRequest.locationSummary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }

    private func matchCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Match", subtitle: matchedRequest.matchSummary) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Status",
                    value: matchedRequest.match.status.title,
                    systemImage: matchedRequest.match.status.groomerSystemImage
                )

                if let score = matchedRequest.match.matchScore {
                    DetailMetadataRow(
                        title: "Score",
                        value: "\(Int(score.rounded()))",
                        systemImage: "gauge.with.dots.needle.50percent"
                    )
                }

                if let reason = matchedRequest.match.matchReason {
                    Text(reason)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Request") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    DetailMetadataRow(
                        title: "Service",
                        value: matchedRequest.request.serviceType,
                        systemImage: "scissors"
                    )

                    Spacer(minLength: DesignTokens.Spacing.sm)

                    GroomlyStatusChip(
                        matchedRequest.request.status.title,
                        systemImage: matchedRequest.request.status.groomerSystemImage,
                        tone: matchedRequest.request.status.groomerTone
                    )
                }

                if let notes = matchedRequest.request.serviceNotes {
                    Text(notes)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func petSnapshotCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Pet snapshot") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Pet",
                    value: matchedRequest.request.petSnapshot.name,
                    systemImage: "pawprint.fill"
                )
                DetailMetadataRow(
                    title: "Species",
                    value: matchedRequest.request.petSnapshot.species,
                    systemImage: "tag"
                )
                if let breed = matchedRequest.request.petSnapshot.breed {
                    DetailMetadataRow(
                        title: "Breed",
                        value: breed,
                        systemImage: "sparkles"
                    )
                }
                if let size = matchedRequest.request.petSnapshot.size {
                    DetailMetadataRow(
                        title: "Size",
                        value: size,
                        systemImage: "ruler"
                    )
                }
                DetailMetadataRow(
                    title: "Photos",
                    value: "\(matchedRequest.request.photoSnapshot.count)",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private func scheduleLocationCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Schedule and location") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: matchedRequest.request.preferredStart
                    ),
                    systemImage: "calendar"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: matchedRequest.request.preferredEnd
                    ),
                    systemImage: "clock"
                )
                Divider()
                    .overlay(DesignTokens.Colors.divider)
                DetailMetadataRow(
                    title: "City",
                    value: matchedRequest.request.city,
                    systemImage: "mappin.and.ellipse"
                )
                DetailMetadataRow(
                    title: "State",
                    value: matchedRequest.request.state,
                    systemImage: "map"
                )
                DetailMetadataRow(
                    title: "ZIP",
                    value: matchedRequest.request.zipCode,
                    systemImage: "number"
                )
            }
        }
    }

    @ViewBuilder
    private func offerSection(for matchedRequest: GroomerMatchedRequest) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader("Offer")

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if let offer = matchedRequest.offer {
                        LabeledContent("Status", value: offer.status.title)
                        LabeledContent("Price", value: offer.priceSummary)
                        LabeledContent(
                            "Proposed start",
                            value: GroomingRequestDateFormatting.displayString(
                                from: offer.proposedStart
                            )
                        )
                        LabeledContent(
                            "Proposed end",
                            value: GroomingRequestDateFormatting.displayString(
                                from: offer.proposedEnd
                            )
                        )
                        if let message = offer.message {
                            Text(message)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }

                        if offer.status == .pending {
                            Button(role: .destructive) {
                                Task {
                                    await store.withdrawOffer(for: matchedRequest)
                                }
                            } label: {
                                Label("Withdraw offer", systemImage: "arrow.uturn.backward.circle")
                            }
                            .disabled(store.isWithdrawingOffer)
                            .accessibilityIdentifier("groomer.offers.withdraw")
                        }
                    }

                    if matchedRequest.canCreateOffer {
                        DatePicker(
                            "Proposed start",
                            selection: $proposedStart,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        DatePicker(
                            "Proposed end",
                            selection: $proposedEnd,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        TextField("Price estimate", text: $priceEstimateText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("groomer.offers.price")

                        TextField("Message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("groomer.offers.message")

                        Button {
                            Task {
                                await store.submitOffer(
                                    for: matchedRequest,
                                    proposedStart: proposedStart,
                                    proposedEnd: proposedEnd,
                                    priceEstimateText: priceEstimateText,
                                    message: message
                                )
                            }
                        } label: {
                            Label("Submit offer", systemImage: "paperplane")
                        }
                        .disabled(store.isSubmittingOffer)
                        .accessibilityIdentifier("groomer.offers.submit")
                    } else if matchedRequest.offer?.status != .pending {
                        Text("This request can no longer receive a new offer from this account.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private func actionsCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Actions") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Button(role: .destructive) {
                    Task {
                        await store.dismiss(matchedRequest)
                    }
                } label: {
                    Label("Dismiss match", systemImage: "xmark.circle")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                .disabled(
                    store.isDismissing || !matchedRequest.match.status.isDismissible
                )
                .accessibilityIdentifier("groomer.requests.dismiss")

                if !matchedRequest.match.status.isDismissible {
                    Text("Matches with an active or completed offer cannot be dismissed.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func initializeOfferFormIfNeeded(
        for matchedRequest: GroomerMatchedRequest
    ) {
        guard !didInitializeOfferForm else { return }

        let range = GroomerRequestsStore.defaultOfferRange(
            for: matchedRequest.request
        )
        proposedStart = range.start
        proposedEnd = range.end
        didInitializeOfferForm = true
    }
}

private struct DetailShellCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(title, subtitle: subtitle)

            GroomlyCard {
                content
            }
        }
    }
}

private struct DetailMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
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
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text(value)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension GroomingRequestStatus {
    var groomerTone: GroomlyStatusChip.Tone {
        isOpenForOffers ? .groomer : .neutral
    }

    var groomerSystemImage: String {
        isOpenForOffers ? "clock" : "checkmark"
    }
}

private extension RequestMatchStatus {
    var groomerSystemImage: String {
        isDismissible ? "sparkles" : "checkmark"
    }
}

private struct GroomerRequestsStatusView: View {
    let store: GroomerRequestsStore

    var body: some View {
        if hasStatus {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if store.isDismissing {
                    progressRow("Dismissing…")
                }

                if store.isSubmittingOffer {
                    progressRow("Submitting offer…")
                }

                if store.isWithdrawingOffer {
                    progressRow("Withdrawing offer…")
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

                if let errorMessage = store.errorMessage {
                    GroomlyErrorBanner(
                        title: "Request update failed",
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
        store.isDismissing ||
            store.isSubmittingOffer ||
            store.isWithdrawingOffer ||
            store.noticeMessage != nil ||
            store.errorMessage != nil
    }

    private func progressRow(_ title: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .tint(DesignTokens.Colors.groomerAccent)

            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerRequestsView(
            groomerID: UUID(),
            repository: GroomerRequestsPreviewRepository()
        )
    }
}

@MainActor
private final class GroomerRequestsPreviewRepository: GroomerRequestRepository {
    private var matches = [
        GroomerMatchedRequest(
            match: GroomerRequestMatch(
                id: UUID(),
                requestID: UUID(),
                groomerID: UUID(),
                customerID: UUID(),
                matchScore: 100,
                matchReason: "Same city",
                dismissReason: nil,
                status: .visible,
                viewedAt: nil,
                dismissedAt: nil,
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            request: GroomerMatchedGroomingRequest(
                id: UUID(),
                customerID: UUID(),
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
                serviceNotes: "Sensitive paws.",
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
            offer: nil
        )
    ]

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        matches
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        matches.removeAll { $0.match.id == matchID }
        return DismissRequestMatchResult(
            matchID: matchID,
            status: .dismissed,
            dismissedAt: "2026-06-20T13:00:00Z"
        )
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        CreateGroomerOfferResult(
            offerID: UUID(),
            offerStatus: .pending,
            requestStatus: .hasOffers
        )
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        WithdrawGroomerOfferResult(
            offerID: offerID,
            offerStatus: .withdrawnByGroomer,
            withdrawnTimestamp: "2026-06-20T14:00:00Z",
            requestStatus: .open
        )
    }
}
#endif
