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
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            bookingsContent
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
            BookingsStatusView(
                store: store,
                role: role
            )
        }
        .task {
            await store.load()
        }
    }

    @ViewBuilder
    private var bookingsContent: some View {
        if store.isLoading, store.bookings.isEmpty {
            GroomlyLoadingView(
                title: "Loading bookings…",
                message: "Fetching confirmed appointments for your account.",
                accent: role.loadingAccent
            )
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .accessibilityIdentifier("bookings.loading")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomlySectionHeader(
                        "Bookings",
                        subtitle: role.bookingsSubtitle
                    )

                    if store.bookings.isEmpty {
                        GroomlyEmptyState(
                            title: "No bookings yet",
                            message: "Confirmed appointments will appear here after an offer is accepted.",
                            systemImage: "calendar.badge.clock",
                            accent: role.emptyStateAccent
                        )
                        .accessibilityIdentifier("bookings.empty")
                    } else {
                        LazyVStack(spacing: DesignTokens.Spacing.md) {
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
            .accessibilityIdentifier("bookings.list")
        }
    }
}

private struct BookingSummaryRow: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(role.primaryColor)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl
                        )
                        .background(role.primaryColor.opacity(0.14))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Appointment")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(booking.scheduledTimeSummary)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        booking.status.title,
                        systemImage: booking.status.chipIcon,
                        tone: booking.status.chipTone(for: role)
                    )
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    BookingMetadataRow(
                        systemImage: "creditcard",
                        text: booking.priceSummary
                    )

                    BookingMetadataRow(
                        systemImage: role == .groomer ? "person" : "scissors",
                        text: booking.participantSummary(for: role)
                    )

                    BookingMetadataRow(
                        systemImage: "number",
                        text: "Support ref \(booking.referenceCode)"
                    )
                }
            }
        }
    }
}

private struct BookingDetailView: View {
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore

    var body: some View {
        if let booking = store.booking(withID: bookingID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Appointment",
                            subtitle: "Stable booking facts and support references."
                        )

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                                    Text("Booking \(booking.referenceCode)")
                                        .font(DesignTokens.Typography.headline)
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    GroomlyStatusChip(
                                        booking.status.title,
                                        systemImage: booking.status.chipIcon,
                                        tone: booking.status.chipTone(for: role)
                                    )
                                }

                                BookingFactRow("Price", value: booking.priceSummary)
                                BookingFactRow(
                                    "Start",
                                    value: GroomingRequestDateFormatting.displayString(
                                        from: booking.scheduledStart
                                    )
                                )
                                BookingFactRow(
                                    "End",
                                    value: GroomingRequestDateFormatting.displayString(
                                        from: booking.scheduledEnd
                                    )
                                )
                            }
                        }

                        GroomlySectionHeader("Participant")

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                BookingFactRow(
                                    "Counterparty",
                                    value: booking.participantSummary(for: role)
                                )

                                Text("Names and richer pet context require a later participant summary contract; this screen only shows stable booking facts and support references for now.")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        GroomlySectionHeader("Support references")

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                BookingFactRow("Booking", value: booking.referenceCode)
                                BookingFactRow("Request", value: booking.requestReferenceCode)
                                BookingFactRow("Offer", value: booking.offerReferenceCode)
                                BookingFactRow(
                                    participantLabel,
                                    value: booking.participantReferenceCode(for: role)
                                )
                            }
                        }

                        GroomlySectionHeader("Conversation")

                        GroomlyCard {
                            BookingMetadataRow(
                                systemImage: "message",
                                text: "Use the Messages tab for participant chat tied to this booking."
                            )
                        }

                        BookingLifecycleCard(
                            booking: booking,
                            role: role,
                            store: store
                        )

                        if booking.status == .completed {
                            GroomlySectionHeader("Review")

                            if let review = booking.review {
                                BookingReviewDisplay(review: review)
                            } else if booking.canReview(for: role) {
                                BookingReviewForm(
                                    booking: booking,
                                    store: store,
                                    accent: role.primaryButtonAccent
                                )
                            } else {
                                GroomlyCard {
                                    BookingMetadataRow(
                                        systemImage: "star",
                                        text: "Waiting for the customer to leave a review."
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
                }
            }
            .navigationTitle("Booking \(booking.referenceCode)")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("bookings.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Booking unavailable",
                    message: "Refresh bookings and try again.",
                    systemImage: "calendar.badge.exclamationmark",
                    accent: role.emptyStateAccent
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
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
}

private struct BookingLifecycleCard: View {
    let booking: Booking
    let role: UserRole
    let store: BookingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader("Lifecycle")

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if booking.status == .confirmed {
                        if role == .groomer {
                            Button {
                                Task {
                                    await store.complete(booking)
                                }
                            } label: {
                                Label("Mark service completed", systemImage: "checkmark.seal")
                            }
                            .buttonStyle(GroomlyPrimaryButtonStyle(accent: role.primaryButtonAccent))
                            .disabled(store.isCompleting)
                            .accessibilityIdentifier("bookings.complete")

                            Text("Completion closes the service lifecycle and lets the customer leave one review.")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            BookingMetadataRow(
                                systemImage: "checkmark.seal",
                                text: "The groomer can mark this booking completed after the service."
                            )
                        }

                        Button(role: .destructive) {
                            Task {
                                await store.cancel(booking)
                            }
                        } label: {
                            Label("Cancel booking", systemImage: "xmark.circle")
                        }
                        .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                        .disabled(store.isCancelling)
                        .accessibilityIdentifier("bookings.cancel")

                        Text("Cancellation closes this booking only. The original request and offers do not reopen.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if booking.status.isCancellation {
                        BookingMetadataRow(
                            systemImage: "xmark.circle",
                            text: "This booking was cancelled. Create a new request if a replacement appointment is needed."
                        )

                        if let cancelledAt = booking.cancelledAt {
                            BookingFactRow(
                                "Cancelled",
                                value: GroomingRequestDateFormatting.displayString(
                                    from: cancelledAt
                                )
                            )
                        }
                    } else {
                        BookingMetadataRow(
                            systemImage: "checkmark.circle",
                            text: "This booking is completed."
                        )

                        if let completedAt = booking.completedAt {
                            BookingFactRow(
                                "Completed",
                                value: GroomingRequestDateFormatting.displayString(
                                    from: completedAt
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct BookingReviewDisplay: View {
    let review: BookingReview

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(DesignTokens.Colors.warning)
                        .accessibilityHidden(true)

                    Text(review.ratingSummary)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                Text(review.displayContent)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                BookingFactRow(
                    "Submitted",
                    value: GroomingRequestDateFormatting.displayString(
                        from: review.createdAt
                    )
                )
            }
        }
        .accessibilityIdentifier("bookings.review.display")
    }
}

private struct BookingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    let accent: GroomlyPrimaryButtonStyle.Accent
    @State private var rating = 5
    @State private var content = ""

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Picker("Rating", selection: $rating) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .tint(DesignTokens.Colors.customerPrimary)
                .accessibilityIdentifier("bookings.review.rating")

                TextEditor(text: $content)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .groomlyFormField()
                    .accessibilityIdentifier("bookings.review.content")

                Text("Optional review text, up to 2,000 characters.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

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
                .buttonStyle(GroomlyPrimaryButtonStyle(accent: accent))
                .disabled(store.isSubmittingReview)
                .accessibilityIdentifier("bookings.review.submit")
            }
        }
    }
}

private struct BookingsStatusView: View {
    let store: BookingsStore
    let role: UserRole

    var body: some View {
        if hasStatus {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if store.isCancelling {
                    progressRow("Cancelling…")
                }

                if store.isCompleting {
                    progressRow("Completing…")
                }

                if store.isSubmittingReview {
                    progressRow("Submitting review…")
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
                        title: "Booking update failed",
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
        store.isCancelling ||
            store.isCompleting ||
            store.isSubmittingReview ||
            store.noticeMessage != nil ||
            store.errorMessage != nil
    }

    private func progressRow(_ title: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .tint(role.primaryColor)

            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct BookingFactRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BookingMetadataRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(width: DesignTokens.Spacing.lg)
                .accessibilityHidden(true)

            Text(text)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension UserRole {
    var primaryButtonAccent: GroomlyPrimaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var loadingAccent: GroomlyLoadingView.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var emptyStateAccent: GroomlyEmptyState<EmptyView>.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var primaryColor: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerPrimaryDark
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
        }
    }

    var bookingsSubtitle: String {
        switch self {
        case .customer:
            "Track confirmed appointments and review completed services."
        case .groomer:
            "Review confirmed appointments and close completed services."
        }
    }
}

private extension BookingStatus {
    var chipIcon: String {
        switch self {
        case .confirmed:
            "calendar.badge.checkmark"
        case .completed:
            "checkmark.circle.fill"
        case .cancelledByCustomer, .cancelledByGroomer:
            "xmark.circle.fill"
        }
    }

    func chipTone(for role: UserRole) -> GroomlyStatusChip.Tone {
        switch self {
        case .confirmed:
            role == .groomer ? .groomer : .customer
        case .completed:
            .success
        case .cancelledByCustomer, .cancelledByGroomer:
            .error
        }
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
