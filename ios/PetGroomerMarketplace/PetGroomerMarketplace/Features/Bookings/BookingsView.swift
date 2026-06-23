import SwiftUI

struct BookingsView: View {
    private let role: UserRole
    @State private var store: BookingsStore
    @State private var selectedScope: BookingListScope = .upcoming

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BookingsStatusView(
                store: store,
                role: role
            )
        }
        .refreshable {
            await store.load()
        }
        .task {
            await store.load()
        }
    }

    private var bookingsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CustomerTabTitle("Bookings")

                BookingScopeControl(selection: $selectedScope)

                if store.isLoading, store.bookings.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading Bookings...",
                        message: "Fetching confirmed appointments for your account.",
                        accent: role.loadingAccent
                    )
                    .accessibilityIdentifier("bookings.loading")
                } else if visibleBookings.isEmpty {
                    GroomlyEmptyState(
                        title: selectedScope.emptyTitle,
                        message: selectedScope.emptyMessage,
                        systemImage: "calendar.badge.clock",
                        accent: role.emptyStateAccent
                    )
                    .accessibilityIdentifier("bookings.empty")
                } else {
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(visibleBookings) { booking in
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
            .padding(.top, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("bookings.list")
    }

    private var visibleBookings: [Booking] {
        store.bookings.filter(selectedScope.contains)
    }
}

private struct BookingSummaryRow: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center) {
                    GroomlyStatusChip(
                        booking.status.title,
                        systemImage: booking.status.chipIcon,
                        tone: booking.status.chipTone(for: role)
                    )

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(BookingListDateFormatting.day(from: booking.scheduledStart))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                    BookingAvatar(role: role)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.partnerDisplayTitle(for: role))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.listContextSummary)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct BookingAvatar: View {
    let role: UserRole

    var body: some View {
        Image(systemName: role == .customer ? "person.fill" : "person.crop.square.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(role.primaryColor)
            .frame(width: 64, height: 64)
            .background(role.primaryColor.opacity(0.24))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }
}

private enum BookingListScope: String, CaseIterable, Identifiable {
    case upcoming
    case past

    var id: Self { self }

    var title: String {
        switch self {
        case .upcoming:
            "Upcoming"
        case .past:
            "Past"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming:
            "No Upcoming Bookings"
        case .past:
            "No Past Bookings"
        }
    }

    var emptyMessage: String {
        switch self {
        case .upcoming:
            "Confirmed appointments will appear here after an offer is accepted."
        case .past:
            "Completed and cancelled appointments will appear here."
        }
    }

    func contains(_ booking: Booking) -> Bool {
        switch self {
        case .upcoming:
            booking.status == .confirmed
        case .past:
            booking.status != .confirmed
        }
    }
}

private struct BookingScopeControl: View {
    @Binding var selection: BookingListScope

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BookingListScope.allCases) { scope in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = scope
                    }
                } label: {
                    Text(scope.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(
                            selection == scope
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background {
                            if selection == scope {
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.input,
                                    style: .continuous
                                )
                                .fill(DesignTokens.Colors.surface)
                                .groomlyShadow(DesignTokens.Shadows.smallCard)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.72))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct CustomerTabTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.Spacing.sm)
    }
}

private enum BookingListDateFormatting {
    static func day(from value: String) -> String {
        format(value, pattern: "EEE, MMM d")
    }

    static func time(from value: String) -> String {
        format(value, pattern: "h:mm a")
    }

    private static func format(_ value: String, pattern: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private extension Booking {
    var listContextSummary: String {
        "\(BookingListDateFormatting.time(from: scheduledStart)) · \(priceSummary)"
    }

    var timeWindowSummary: String {
        "\(BookingListDateFormatting.time(from: scheduledStart)) - \(BookingListDateFormatting.time(from: scheduledEnd))"
    }

    var detailTitle: String {
        switch status {
        case .confirmed:
            "Booking Confirmed"
        case .completed:
            "Booking Completed"
        case .cancelledByCustomer, .cancelledByGroomer:
            "Booking Cancelled"
        }
    }

    func partnerDisplayTitle(for role: UserRole) -> String {
        switch role {
        case .customer:
            "Assigned Groomer"
        case .groomer:
            "Booking Customer"
        }
    }

    func detailSubtitle(for role: UserRole) -> String {
        switch role {
        case .customer:
            "Your appointment is managed from Bookings."
        case .groomer:
            "This appointment is managed from Bookings."
        }
    }
}

struct BookingDetailView: View {
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
                        BookingDetailHeroCard(
                            booking: booking,
                            role: role
                        )

                        BookingDetailInfoCard(
                            title: "Appointment",
                            systemImage: "calendar.badge.clock"
                        ) {
                            BookingDetailFactRow("Date", value: BookingListDateFormatting.day(from: booking.scheduledStart))
                            BookingDetailFactRow("Time", value: booking.timeWindowSummary)
                            BookingDetailFactRow("Price", value: booking.priceSummary)
                        }

                        BookingPartnerOverviewCard(
                            booking: booking,
                            role: role
                        )

                        BookingDetailInfoCard(
                            title: "Conversation",
                            systemImage: "message.fill"
                        ) {
                            BookingMetadataRow(
                                systemImage: "message",
                                text: "Messages for this appointment stay connected to the booking."
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
            .navigationTitle("Booking")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("bookings.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Booking Unavailable",
                    message: "Refresh bookings and try again.",
                    systemImage: "calendar.badge.exclamationmark",
                    accent: role.emptyStateAccent
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Booking")
        }
    }
}

private struct BookingDetailHeroCard: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .center) {
                    GroomlyStatusChip(
                        booking.status.title,
                        systemImage: booking.status.chipIcon,
                        tone: booking.status.chipTone(for: role)
                    )

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text("Order #\(booking.referenceCode)")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                    BookingAvatar(role: role)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.detailTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.detailSubtitle(for: role))
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct BookingDetailInfoCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(width: 38, height: 38)
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.15))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                content
            }
        }
    }
}

private struct BookingPartnerOverviewCard: View {
    let booking: Booking
    let role: UserRole

    var body: some View {
        BookingDetailInfoCard(
            title: role == .customer ? "Groomer" : "Customer",
            systemImage: "person.fill"
        ) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BookingAvatar(role: role)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(booking.partnerDisplayTitle(for: role))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(role == .customer ? "Confirmed grooming provider" : "Booking customer")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                BookingMiniChip(title: "Chat Ready", systemImage: "message")
                BookingMiniChip(title: booking.status.title, systemImage: booking.status.chipIcon)
            }
        }
    }
}

private struct BookingMiniChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DesignTokens.Typography.caption.weight(.bold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.borderSoft.opacity(0.72))
            .clipShape(Capsule())
    }
}

private struct BookingDetailFactRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
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
                                Label("Mark Service Completed", systemImage: "checkmark.seal")
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
                            Label("Cancel Booking", systemImage: "xmark.circle")
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
                    Label("Submit Review", systemImage: "star.bubble")
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
            if store.isCancelling {
                progressRow("Cancelling…")
            }

            if store.isCompleting {
                progressRow("Completing…")
            }

            if store.isSubmittingReview {
                progressRow("Submitting Review…")
            }

            if let errorMessage = store.errorMessage {
                GroomlyErrorBanner(
                    title: "Booking Update Failed",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isCancelling ||
            store.isCompleting ||
            store.isSubmittingReview ||
            store.errorMessage != nil
    }

    private func progressRow(_ title: String) -> some View {
        GroomlyStatusProgressToast(title, tint: role.primaryColor)
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
