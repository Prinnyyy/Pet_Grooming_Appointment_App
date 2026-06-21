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
        Group {
            if store.isLoading, store.matchedRequests.isEmpty {
                ProgressView("Loading matched requests…")
                    .accessibilityIdentifier("groomer.requests.loading")
            } else {
                List {
                    if store.matchedRequests.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No matched requests",
                                systemImage: "tray",
                                description: Text("New active customer requests will appear here when they match your profile and services.")
                            )
                            .accessibilityIdentifier("groomer.requests.empty")
                        }
                    } else {
                        Section("Matched requests") {
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
                            }
                        }
                    }
                }
                .accessibilityIdentifier("groomer.requests.list")
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
            GroomerRequestsStatusView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct GroomerRequestSummaryRow: View {
    let matchedRequest: GroomerMatchedRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(matchedRequest.title)
                    .font(.headline)

                Spacer()

                Text(statusSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(matchedRequest.locationSummary)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text(
                "\(GroomingRequestDateFormatting.displayString(from: matchedRequest.request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: matchedRequest.request.preferredEnd))"
            )
            .font(.caption)
            .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private var statusSummary: String {
        if let offer = matchedRequest.offer {
            return "Offer \(offer.status.title.lowercased())"
        }

        return matchedRequest.matchSummary
    }

    private var statusColor: Color {
        if matchedRequest.offer?.status == .pending {
            return .orange
        }

        return matchedRequest.request.status.isOpenForOffers ? .green : .secondary
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
            List {
                Section("Match") {
                    LabeledContent("Status", value: matchedRequest.match.status.title)
                    if let score = matchedRequest.match.matchScore {
                        LabeledContent("Score", value: "\(Int(score.rounded()))")
                    }
                    if let reason = matchedRequest.match.matchReason {
                        Text(reason)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }

                Section("Request") {
                    LabeledContent(
                        "Request status",
                        value: matchedRequest.request.status.title
                    )
                    LabeledContent("Service", value: matchedRequest.request.serviceType)
                    if let notes = matchedRequest.request.serviceNotes {
                        Text(notes)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }

                Section("Pet snapshot") {
                    LabeledContent("Pet", value: matchedRequest.request.petSnapshot.name)
                    LabeledContent(
                        "Species",
                        value: matchedRequest.request.petSnapshot.species
                    )
                    if let breed = matchedRequest.request.petSnapshot.breed {
                        LabeledContent("Breed", value: breed)
                    }
                    if let size = matchedRequest.request.petSnapshot.size {
                        LabeledContent("Size", value: size)
                    }
                    LabeledContent(
                        "Photos",
                        value: "\(matchedRequest.request.photoSnapshot.count)"
                    )
                }

                Section("Preferred time") {
                    LabeledContent(
                        "Start",
                        value: GroomingRequestDateFormatting.displayString(
                            from: matchedRequest.request.preferredStart
                        )
                    )
                    LabeledContent(
                        "End",
                        value: GroomingRequestDateFormatting.displayString(
                            from: matchedRequest.request.preferredEnd
                        )
                    )
                }

                Section("Location") {
                    LabeledContent("City", value: matchedRequest.request.city)
                    LabeledContent("State", value: matchedRequest.request.state)
                    LabeledContent("ZIP", value: matchedRequest.request.zipCode)
                }

                offerSection(for: matchedRequest)

                Section("Actions") {
                    Button(role: .destructive) {
                        Task {
                            await store.dismiss(matchedRequest)
                        }
                    } label: {
                        Label("Dismiss match", systemImage: "xmark.circle")
                    }
                    .disabled(
                        store.isDismissing || !matchedRequest.match.status.isDismissible
                    )
                    .accessibilityIdentifier("groomer.requests.dismiss")

                    if !matchedRequest.match.status.isDismissible {
                        Text("Matches with an active or completed offer cannot be dismissed.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }
            }
            .navigationTitle(matchedRequest.request.petSnapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("groomer.requests.detail")
            .task(id: matchedRequest.request.id) {
                initializeOfferFormIfNeeded(for: matchedRequest)
            }
        } else {
            ContentUnavailableView(
                "Request unavailable",
                systemImage: "tray",
                description: Text("Refresh matched requests and try again.")
            )
            .navigationTitle("Request")
        }
    }

    @ViewBuilder
    private func offerSection(for matchedRequest: GroomerMatchedRequest) -> some View {
        Section("Offer") {
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

private struct GroomerRequestsStatusView: View {
    let store: GroomerRequestsStore

    var body: some View {
        VStack(spacing: 8) {
            if store.isDismissing {
                ProgressView("Dismissing…")
                    .font(.footnote)
            }

            if store.isSubmittingOffer {
                ProgressView("Submitting offer…")
                    .font(.footnote)
            }

            if store.isWithdrawingOffer {
                ProgressView("Withdrawing offer…")
                    .font(.footnote)
            }

            if let noticeMessage = store.noticeMessage {
                Text(noticeMessage)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if let errorMessage = store.errorMessage {
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
