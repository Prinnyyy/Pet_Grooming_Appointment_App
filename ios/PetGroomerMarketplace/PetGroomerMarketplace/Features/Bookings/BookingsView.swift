import SwiftUI

struct BookingsView: View {
    private let role: UserRole
    @State private var store: BookingsStore

    init(
        participantID: UUID,
        role: UserRole,
        repository: any BookingRepository
    ) {
        self.role = role
        _store = State(
            initialValue: BookingsStore(
                participantID: participantID,
                role: role,
                repository: repository
            )
        )
    }

    var body: some View {
        Group {
            if store.isLoading, store.bookings.isEmpty {
                ProgressView("Loading bookings…")
                    .accessibilityIdentifier("bookings.loading")
            } else {
                List {
                    if store.bookings.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No bookings yet",
                                systemImage: "calendar.badge.clock",
                                description: Text("Confirmed appointments will appear here after an offer is accepted.")
                            )
                            .accessibilityIdentifier("bookings.empty")
                        }
                    } else {
                        Section("Bookings") {
                            ForEach(store.bookings) { booking in
                                NavigationLink {
                                    BookingDetailView(
                                        bookingID: booking.id,
                                        role: role,
                                        store: store
                                    )
                                } label: {
                                    BookingSummaryRow(
                                        booking: booking,
                                        role: role
                                    )
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("bookings.list")
            }
        }
        .navigationTitle("Bookings")
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
            BookingsStatusView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct BookingSummaryRow: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(booking.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(booking.status == .confirmed ? .green : .secondary)
            }

            Text("Booking ref \(booking.referenceCode)")
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text(booking.scheduledTimeSummary)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text(booking.priceSummary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        booking.participantSummary(for: role)
    }
}

private struct BookingDetailView: View {
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore

    var body: some View {
        if let booking = store.booking(withID: bookingID) {
            List {
                Section("Booking") {
                    LabeledContent("Status", value: booking.status.title)
                    LabeledContent("Participant", value: booking.participantSummary(for: role))
                    LabeledContent("Price", value: booking.priceSummary)
                    LabeledContent(
                        "Start",
                        value: GroomingRequestDateFormatting.displayString(
                            from: booking.scheduledStart
                        )
                    )
                    LabeledContent(
                        "End",
                        value: GroomingRequestDateFormatting.displayString(
                            from: booking.scheduledEnd
                        )
                    )
                }

                Section("Support references") {
                    LabeledContent("Booking", value: booking.referenceCode)
                    LabeledContent("Request", value: booking.requestReferenceCode)
                    LabeledContent("Offer", value: booking.offerReferenceCode)
                    LabeledContent(participantLabel, value: booking.participantReferenceCode(for: role))
                }

                Section("Conversation") {
                    Text("Messaging is reserved for T-020 and is not connected yet.")
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                Section("Lifecycle") {
                    if booking.status == .confirmed {
                        Button(role: .destructive) {
                            Task {
                                await store.cancel(booking)
                            }
                        } label: {
                            Label("Cancel booking", systemImage: "xmark.circle")
                        }
                        .disabled(store.isCancelling)
                        .accessibilityIdentifier("bookings.cancel")

                        Text("Cancellation closes this booking only. The original request and offers do not reopen.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    } else if booking.status.isCancellation {
                        Text("This booking was cancelled. Create a new request if a replacement appointment is needed.")
                            .foregroundStyle(DesignTokens.Colors.secondaryText)

                        if let cancelledAt = booking.cancelledAt {
                            LabeledContent(
                                "Cancelled",
                                value: GroomingRequestDateFormatting.displayString(
                                    from: cancelledAt
                                )
                            )
                        }
                    } else {
                        Text("Completion and reviews are reserved for T-021.")
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }
            }
            .navigationTitle("Booking \(booking.referenceCode)")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("bookings.detail")
        } else {
            ContentUnavailableView(
                "Booking unavailable",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Refresh bookings and try again.")
            )
            .navigationTitle("Booking")
        }
    }

    private var participantLabel: String {
        switch role {
        case .customer:
            "Groomer"
        case .groomer:
            "Customer"
        }
    }

    private var booking: Booking? {
        store.booking(withID: bookingID)
    }
}

private struct BookingsStatusView: View {
    let store: BookingsStore

    var body: some View {
        VStack(spacing: 8) {
            if store.isCancelling {
                ProgressView("Cancelling…")
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
        BookingsView(
            participantID: UUID(),
            role: .customer,
            repository: BookingsPreviewRepository()
        )
    }
}

@MainActor
private final class BookingsPreviewRepository: BookingRepository {
    private var bookings: [Booking] = [
        Booking(
            id: UUID(),
            requestID: UUID(),
            offerID: UUID(),
            customerID: UUID(),
            groomerID: UUID(),
            scheduledStart: "2026-06-22T16:00:00Z",
            scheduledEnd: "2026-06-22T18:00:00Z",
            priceEstimate: 125,
            status: .confirmed,
            cancelledBy: nil,
            cancelledAt: nil,
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z"
        ),
    ]

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        bookings
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        throw BookingRepositoryError.unavailable
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        bookings[0] = bookings[0].replacing(
            status: .cancelledByCustomer,
            cancelledBy: bookings[0].customerID,
            cancelledAt: "2026-06-20T13:00:00Z"
        )
        return CancelBookingResult(
            bookingID: bookingID,
            bookingStatus: .cancelledByCustomer,
            cancelledTimestamp: "2026-06-20T13:00:00Z",
            cancelledBy: bookings[0].customerID
        )
    }
}
#endif
