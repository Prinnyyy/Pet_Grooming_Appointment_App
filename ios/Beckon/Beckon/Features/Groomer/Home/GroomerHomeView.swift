import SwiftUI

struct GroomerHomeView: View {
    @State private var store: GroomerHomeStore
    @State private var notificationRequestsStore: GroomerRequestsStore
    @State private var notificationBookingsStore: BookingsStore
    private let chatStore: ChatStore?
    @State private var isShowingNotifications = false
    let unreadNotificationCount: Int
    let unreadMessageCount: Int
    let notificationStore: GroomerNotificationsStore?
    let requestsAction: () -> Void
    let offersAction: () -> Void
    let bookingAction: (Booking) -> Void
    let messagesAction: () -> Void
    let availabilityAction: () -> Void

    init(
        groomerID: UUID,
        displayName: String,
        profileRepository: any GroomerProfileRepository,
        requestRepository: any GroomerRequestRepository,
        bookingRepository: any BookingRepository,
        unreadNotificationCount: Int,
        unreadMessageCount: Int,
        notificationStore: GroomerNotificationsStore?,
        debugRecorder: AppDebugEventRecorder? = nil,
        chatStore: ChatStore? = nil,
        requestsAction: @escaping () -> Void,
        offersAction: @escaping () -> Void,
        bookingAction: @escaping (Booking) -> Void,
        messagesAction: @escaping () -> Void,
        availabilityAction: @escaping () -> Void
    ) {
        _store = State(
            initialValue: GroomerHomeStore(
                groomerID: groomerID,
                displayName: displayName,
                profileRepository: profileRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
        self.unreadNotificationCount = unreadNotificationCount
        self.unreadMessageCount = unreadMessageCount
        self.notificationStore = notificationStore
        self.chatStore = chatStore
        _notificationRequestsStore = State(initialValue: GroomerRequestsStore(groomerID: groomerID,
            repository: requestRepository, profileRepository: profileRepository, debugRecorder: debugRecorder))
        _notificationBookingsStore = State(initialValue: BookingsStore(participantID: groomerID, role: .groomer,
            repository: bookingRepository, groomerProfileRepository: profileRepository, debugRecorder: debugRecorder))
        self.requestsAction = requestsAction
        self.offersAction = offersAction
        self.bookingAction = bookingAction
        self.messagesAction = messagesAction
        self.availabilityAction = availabilityAction
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                GroomerHomeHeader(
                    greetingName: store.greetingName,
                    businessName: store.businessName,
                    avatarPhotoData: store.avatarPhotoData,
                    unreadNotificationCount: unreadNotificationCount,
                    showsNotifications: notificationStore != nil,
                    notificationAction: {
                        isShowingNotifications = true
                    }
                )

                BeckonSection("Next appointment") {
                    nextAppointmentContent
                }

                BeckonSection("Needs attention") {
                    GroomerHomeAttentionSurface(
                        newMatchCount: store.newMatchCount,
                        pendingOfferCount: store.pendingOfferCount,
                        hasMoreMatches: store.hasMoreMatches,
                        hasMoreOffers: store.hasMoreOffers,
                        isLoading: store.isLoading,
                        unreadMessageCount: unreadMessageCount,
                        requestsAction: requestsAction,
                        offersAction: offersAction,
                        messagesAction: messagesAction
                    )
                }

                BeckonSection("Availability") {
                    GroomerHomeAvailabilityRow(
                        state: store.availabilityState,
                        isLoading: store.isLoading,
                        action: availabilityAction
                    )
                }

                if !store.issues.isEmpty {
                    Button("Retry unavailable sections", systemImage: "arrow.clockwise") {
                        Task { await store.load() }
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isLoading)
                    .accessibilityIdentifier("groomer.home.retry")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingNotifications) {
            if let notificationStore {
                GroomerNotificationsView(
                    store: notificationStore,
                    requestStore: notificationRequestsStore,
                    bookingStore: notificationBookingsStore,
                    chatStore: chatStore
                )
                .toolbar(.visible, for: .navigationBar)
            }
        }
        .foregroundRefreshable {
            await store.load()
        }
        .task {
            await store.load()
        }
        .background {
            ForEach(store.issues) { issue in
                BeckonGlobalFeedbackForwarder(error: issue.feedbackError)
            }
        }
        .accessibilityIdentifier("groomer.home")
    }

    @ViewBuilder
    private var nextAppointmentContent: some View {
        if let booking = store.nextBooking {
            if store.isLoading || store.issues.contains(where: { $0.section == .bookings }) {
                Text(store.isLoading ? "Refreshing appointment..." : "Appointment not refreshed. Pull to retry.")
                    .font(DesignTokens.Typography.supporting).foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            GroomerHomeNextBookingCard(
                booking: booking,
                photoData: store.nextBookingPhotoData,
                action: { bookingAction(booking) }
            )
        } else if store.isLoading || (store.bookingsVerifiedAt == nil && !store.issues.contains(where: { $0.section == .bookings })) {
            GroomerHomeLoadingSurface(
                title: "Loading your schedule",
                accessibilityIdentifier: "groomer.home.next-booking.loading"
            )
        } else if store.issues.contains(where: { $0.section == .bookings }) {
            GroomerHomeUnavailableSurface(
                title: "Schedule unavailable",
                message: "Pull to refresh this section while the rest of Home remains available.",
                accessibilityIdentifier: "groomer.home.next-booking.error"
            )
        } else {
            GroomerHomeUnavailableSurface(
                title: "No upcoming appointment",
                message: "Confirmed bookings will appear here.",
                accessibilityIdentifier: "groomer.home.next-booking.empty"
            )
        }
    }
}

private struct GroomerHomeHeader: View {
    let greetingName: String
    let businessName: String
    let avatarPhotoData: Data?
    let unreadNotificationCount: Int
    let showsNotifications: Bool
    let notificationAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
          HStack(spacing: DesignTokens.Spacing.md) {
            BeckonProfileAvatar(
                data: avatarPhotoData,
                tone: .groomer,
                size: 48,
                cornerRadius: 24,
                placeholderSize: 26
            )
            .overlay {
                Circle()
                    .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }

                Text("Good \(GroomerHomeDateFormatting.dayPeriod), \(greetingName)")
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

            if showsNotifications {
                BeckonNotificationBellButton(
                    unreadCount: unreadNotificationCount,
                    accessibilityIdentifier: "groomer.home.notifications",
                    action: notificationAction
                )
            }
          }
            Text(businessName)
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

private struct GroomerHomeNextBookingCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let booking: Booking
    let photoData: Data?
    let action: () -> Void

    var body: some View {
        BeckonCard(padding: DesignTokens.Spacing.lg) {
            VStack(spacing: DesignTokens.Spacing.lg) {
                bookingLayout {
                    BeckonModuleImage(data: photoData) {
                        ZStack {
                            DesignTokens.Colors.groomerAccent.opacity(0.12)
                            Image(systemName: "pawprint.fill")
                                .font(DesignTokens.Typography.sectionTitle)
                                .foregroundStyle(DesignTokens.Colors.groomerOnAccent)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.requestPetSnapshot?.name ?? "Pet appointment")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(booking.appointmentServiceTitle)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                    }
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Label(booking.scheduledTimeSummary, systemImage: "calendar")
                        .font(DesignTokens.Typography.supporting.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Label(booking.appointmentAddressSummary, systemImage: "mappin")
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                Button(action: action) {
                    HStack {
                        Text("View booking")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
                .accessibilityIdentifier("groomer.home.next-booking.view")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.home.next-booking")
    }

    private var bookingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
    }
}

private struct GroomerHomeAttentionSurface: View {
    let newMatchCount: Int?
    let pendingOfferCount: Int?
    let hasMoreMatches: Bool
    let hasMoreOffers: Bool
    let isLoading: Bool
    let unreadMessageCount: Int
    let requestsAction: () -> Void
    let offersAction: () -> Void
    let messagesAction: () -> Void

    var body: some View {
        BeckonGroupedSurface {
            VStack(spacing: 0) {
                GroomerHomeAttentionRow(
                    title: "New matches",
                    detail: countDetail(
                        newMatchCount,
                        hasMore: hasMoreMatches,
                        singular: "request matches your services",
                        plural: "requests match your services",
                        empty: "No new matching requests"
                    ),
                    systemImage: "person.2",
                    tint: DesignTokens.Colors.successText,
                    identifier: "groomer.home.matches",
                    action: requestsAction
                )

                BeckonGroupedDivider(leadingInset: 76)

                GroomerHomeAttentionRow(
                    title: "Pending offers",
                    detail: countDetail(
                        pendingOfferCount,
                        hasMore: hasMoreOffers,
                        singular: "offer is awaiting a response",
                        plural: "offers are awaiting responses",
                        empty: "No offers awaiting a response"
                    ),
                    systemImage: "tag",
                    tint: DesignTokens.Colors.warningText,
                    identifier: "groomer.home.offers",
                    action: offersAction
                )

                BeckonGroupedDivider(leadingInset: 76)

                GroomerHomeAttentionRow(
                    title: "Unread messages",
                    detail: countDetail(
                        unreadMessageCount,
                        singular: "conversation needs attention",
                        plural: "conversations need attention",
                        empty: "Open messages to check for updates"
                    ),
                    systemImage: "message",
                    tint: DesignTokens.Colors.textTertiary,
                    identifier: "groomer.home.messages",
                    action: messagesAction
                )
            }
        }
    }

    private func countDetail(
        _ count: Int?,
        hasMore: Bool = false,
        singular: String,
        plural: String,
        empty: String
    ) -> String {
        guard let count else { return isLoading ? "Checking..." : "Not refreshed. Open to review." }
        if hasMore { return "Open to review the complete list" }
        return switch count {
        case 0:
            empty
        case 1:
            "1 \(singular)"
        default:
            "\(count) \(plural)"
        }
    }
}

private struct GroomerHomeAttentionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )

                        .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(detail)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.supporting.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

private struct GroomerHomeAvailabilityRow: View {
    let state: GroomerHomeAvailabilityState
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerOnAccent)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(minHeight: 76)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("groomer.home.availability")
    }

    private var indicatorColor: Color {
        switch state {
        case .available:
            DesignTokens.Colors.success
        case .needsSchedule:
            DesignTokens.Colors.warning
        case .paused, .unavailable:
            DesignTokens.Colors.textTertiary
        }
    }

    private var title: String {
        if isLoading { return "Checking availability..." }
        return switch state {
        case .available:
            "Weekly hours set"
        case .paused:
            "Requests paused"
        case .needsSchedule:
            "Weekly hours needed"
        case .unavailable:
            "Availability unavailable"
        }
    }

    private var detail: String {
        if isLoading { return "Refreshing your saved hours" }
        return switch state {
        case .available:
            "Accepting requests within your saved hours"
        case .paused:
            "Your profile is not accepting new requests"
        case .needsSchedule:
            "Add enabled hours before accepting requests"
        case .unavailable:
            "Open to review your saved hours"
        }
    }
}

private struct GroomerHomeLoadingSurface: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .tint(DesignTokens.Colors.groomerAccentDark)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct GroomerHomeUnavailableSurface: View {
    let title: String
    let message: String
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text(message)
                .font(.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private enum GroomerHomeDateFormatting {
    static var dayPeriod: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return switch hour {
        case 5..<12:
            "morning"
        case 12..<18:
            "afternoon"
        default:
            "evening"
        }
    }

}
