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
                Text("Appointment")
                    .font(.headline)

                Spacer()

                Text(booking.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(booking.status == .confirmed ? .green : .secondary)
            }

            Text(booking.scheduledTimeSummary)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text("\(booking.priceSummary) • \(booking.participantSummary(for: role))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text("Support ref \(booking.referenceCode)")
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

private struct BookingDetailView: View {
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore

    var body: some View {
        if let booking = store.booking(withID: bookingID) {
            List {
                Section("Appointment") {
                    LabeledContent("Status", value: booking.status.title)
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

                Section("Participant") {
                    LabeledContent("Counterparty", value: booking.participantSummary(for: role))
                    Text("Names and richer pet context require a later participant summary contract; this screen only shows stable booking facts and support references for now.")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                Section("Support references") {
                    LabeledContent("Booking", value: booking.referenceCode)
                    LabeledContent("Request", value: booking.requestReferenceCode)
                    LabeledContent("Offer", value: booking.offerReferenceCode)
                    LabeledContent(participantLabel, value: booking.participantReferenceCode(for: role))
                }

                Section("Conversation") {
                    Text("Use the Messages tab for participant chat tied to this booking.")
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                Section("Lifecycle") {
                    if booking.status == .confirmed {
                        if role == .groomer {
                            Button {
                                Task {
                                    await store.complete(booking)
                                }
                            } label: {
                                Label("Mark service completed", systemImage: "checkmark.seal")
                            }
                            .disabled(store.isCompleting)
                            .accessibilityIdentifier("bookings.complete")

                            Text("Completion closes the service lifecycle and lets the customer leave one review.")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        } else {
                            Text("The groomer can mark this booking completed after the service.")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }

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
                        Text("This booking is completed.")
                            .foregroundStyle(DesignTokens.Colors.secondaryText)

                        if let completedAt = booking.completedAt {
                            LabeledContent(
                                "Completed",
                                value: GroomingRequestDateFormatting.displayString(
                                    from: completedAt
                                )
                            )
                        }
                    }
                }

                if booking.status == .completed {
                    Section("Review") {
                        if let review = booking.review {
                            BookingReviewDisplay(review: review)
                        } else if booking.canReview(for: role) {
                            BookingReviewForm(
                                booking: booking,
                                store: store
                            )
                        } else {
                            Text("Waiting for the customer to leave a review.")
                                .foregroundStyle(DesignTokens.Colors.secondaryText)
                        }
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

private struct BookingReviewDisplay: View {
    let review: BookingReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Rating", value: review.ratingSummary)

            Text(review.displayContent)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            LabeledContent(
                "Submitted",
                value: GroomingRequestDateFormatting.displayString(
                    from: review.createdAt
                )
            )
            .font(.footnote)
        }
        .accessibilityIdentifier("bookings.review.display")
    }
}

private struct BookingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    @State private var rating = 5
    @State private var content = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Rating", selection: $rating) {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("bookings.review.rating")

            TextEditor(text: $content)
                .frame(minHeight: 96)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                        .stroke(.quaternary)
                }
                .accessibilityIdentifier("bookings.review.content")

            Text("Optional review text, up to 2,000 characters.")
                .font(.footnote)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Button {
                Task {
                    await store.createReview(
                        for: booking,
                        rating: rating,
                        content: content
                    )
                }
            } label: {
                Label("Submit review", systemImage: "star.bubble")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSubmittingReview)
            .accessibilityIdentifier("bookings.review.submit")
        }
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

            if store.isCompleting {
                ProgressView("Completing…")
                    .font(.footnote)
            }

            if store.isSubmittingReview {
                ProgressView("Submitting review…")
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
            completedAt: nil,
            completedBy: nil,
            createdAt: "2026-06-20T12:00:00Z",
            updatedAt: "2026-06-20T12:00:00Z",
            review: nil
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

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        bookings[0] = bookings[0].replacing(
            status: .completed,
            cancelledBy: nil,
            cancelledAt: nil,
            completedAt: "2026-06-22T18:05:00Z",
            completedBy: bookings[0].groomerID
        )
        return CompleteBookingResult(
            bookingID: bookingID,
            bookingStatus: .completed,
            completedTimestamp: "2026-06-22T18:05:00Z",
            completedBy: bookings[0].groomerID
        )
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        let review = BookingReview(
            id: UUID(),
            bookingID: bookingID,
            customerID: bookings[0].customerID,
            groomerID: bookings[0].groomerID,
            rating: draft.rating,
            content: draft.content,
            createdAt: "2026-06-22T19:00:00Z"
        )
        bookings[0] = bookings[0].adding(review: review)
        return CreateReviewResult(
            review: review,
            groomerRatingAverage: Double(draft.rating),
            groomerRatingCount: 1
        )
    }
}
#endif
