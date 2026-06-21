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
                                        matchedRequest: matchedRequest,
                                        isDismissing: store.isDismissing,
                                        onDismiss: {
                                            await store.dismiss(matchedRequest)
                                        }
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

                Text(matchedRequest.matchSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
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
}

private struct GroomerRequestDetailView: View {
    let matchedRequest: GroomerMatchedRequest
    let isDismissing: Bool
    let onDismiss: @MainActor () async -> Void

    var body: some View {
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

            Section("Actions") {
                Button(role: .destructive) {
                    Task {
                        await onDismiss()
                    }
                } label: {
                    Label("Dismiss match", systemImage: "xmark.circle")
                }
                .disabled(isDismissing || !matchedRequest.match.status.isDismissible)
                .accessibilityIdentifier("groomer.requests.dismiss")

                Text("Offer creation is planned for T-016 and is not connected in this task.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
        }
        .navigationTitle(matchedRequest.request.petSnapshot.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.requests.detail")
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
            )
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
}
#endif
