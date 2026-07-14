import SwiftUI

struct GroomerHomeView: View {
    @State private var store: GroomerHomeStore
    @State private var isShowingNotifications = false
    let unreadNotificationCount: Int
    let unreadMessageCount: Int
    let notificationStore: GroomerNotificationsStore?
    let notificationRouteAction: (GroomerNotificationRoute) -> Void
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
        notificationRouteAction: @escaping (GroomerNotificationRoute) -> Void,
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
        self.notificationRouteAction = notificationRouteAction
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

                GroomerWorkspaceSection(title: "Next appointment") {
                    nextAppointmentContent
                }

                GroomerWorkspaceSection(title: "Needs attention") {
                    GroomerHomeAttentionSurface(
                        newMatchCount: store.newMatchCount,
                        pendingOfferCount: store.pendingOfferCount,
                        unreadMessageCount: unreadMessageCount,
                        requestsAction: requestsAction,
                        offersAction: offersAction,
                        messagesAction: messagesAction
                    )
                }

                GroomerWorkspaceSection(title: "Availability") {
                    GroomerHomeAvailabilityRow(
                        state: store.availabilityState,
                        action: availabilityAction
                    )
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
                    routeAction: notificationRouteAction
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
            GroomerHomeNextBookingCard(
                booking: booking,
                photoData: store.nextBookingPhotoData,
                action: { bookingAction(booking) }
            )
        } else if store.isLoading {
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
        HStack(spacing: DesignTokens.Spacing.md) {
            BeckonProfileAvatar(
                data: avatarPhotoData,
                tone: .groomer,
                size: 68,
                cornerRadius: 34,
                placeholderSize: 26
            )
            .overlay {
                Circle()
                    .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Good \(GroomerHomeDateFormatting.dayPeriod), \(greetingName)")
                    .font(.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)

                Text(businessName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Label("Groomer", systemImage: "scissors")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.chip)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsNotifications {
                BeckonNotificationBellButton(
                    unreadCount: unreadNotificationCount,
                    accessibilityIdentifier: "groomer.home.notifications",
                    action: notificationAction
                )
            }
        }
    }
}

private struct GroomerHomeNextBookingCard: View {
    let booking: Booking
    let photoData: Data?
    let action: () -> Void

    var body: some View {
        BeckonCard(padding: DesignTokens.Spacing.lg) {
            VStack(spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                    BeckonModuleImage(data: photoData) {
                        ZStack {
                            DesignTokens.Colors.groomerAccent.opacity(0.12)
                            Image(systemName: "pawprint.fill")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        }
                    }
                    .frame(width: 116, height: 116)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(booking.requestPetSnapshot?.name ?? "Pet appointment")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)

                        Text(booking.appointmentServiceTitle)
                            .font(.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)

                        Label(
                            GroomerHomeDateFormatting.date(from: booking.scheduledStart),
                            systemImage: "calendar"
                        )
                        .font(.subheadline.weight(.semibold))

                        Label(
                            GroomerHomeDateFormatting.time(from: booking.scheduledStart),
                            systemImage: "clock"
                        )
                        .font(.headline)

                        Label(booking.appointmentAddressSummary, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                Button(action: action) {
                    HStack {
                        Text("View booking")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: 52)
                    .background(DesignTokens.Colors.groomerAccentDark)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.button,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("groomer.home.next-booking.view")
            }
        }
        .accessibilityIdentifier("groomer.home.next-booking")
    }
}

private struct GroomerHomeAttentionSurface: View {
    let newMatchCount: Int
    let pendingOfferCount: Int
    let unreadMessageCount: Int
    let requestsAction: () -> Void
    let offersAction: () -> Void
    let messagesAction: () -> Void

    var body: some View {
        GroomerGroupedSurface {
            VStack(spacing: 0) {
                GroomerHomeAttentionRow(
                    title: "New matches",
                    detail: countDetail(
                        newMatchCount,
                        singular: "request matches your services",
                        plural: "requests match your services",
                        empty: "No new matching requests"
                    ),
                    count: newMatchCount,
                    systemImage: "person.2",
                    tint: DesignTokens.Colors.success,
                    action: requestsAction
                )

                GroomerWorkspaceDivider(leadingInset: 76)

                GroomerHomeAttentionRow(
                    title: "Pending offers",
                    detail: countDetail(
                        pendingOfferCount,
                        singular: "offer is awaiting a response",
                        plural: "offers are awaiting responses",
                        empty: "No offers awaiting a response"
                    ),
                    count: pendingOfferCount,
                    systemImage: "tag",
                    tint: DesignTokens.Colors.warning,
                    action: offersAction
                )

                GroomerWorkspaceDivider(leadingInset: 76)

                GroomerHomeAttentionRow(
                    title: "Unread messages",
                    detail: countDetail(
                        unreadMessageCount,
                        singular: "conversation needs attention",
                        plural: "conversations need attention",
                        empty: "All conversations are read"
                    ),
                    count: unreadMessageCount,
                    systemImage: "message",
                    tint: Color.blue,
                    action: messagesAction
                )
            }
            .accessibilityIdentifier("groomer.home.attention")
        }
    }

    private func countDetail(
        _ count: Int,
        singular: String,
        plural: String,
        empty: String
    ) -> String {
        switch count {
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
    let count: Int
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )

                    if count > 0 {
                        Text("\(min(count, 99))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(tint)
                            .clipShape(DesignTokens.Shapes.circular)
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GroomerHomeAvailabilityRow: View {
    let state: GroomerHomeAvailabilityState
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

                Text("Manage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
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
        switch state {
        case .available:
            "Available"
        case .paused:
            "Requests paused"
        case .needsSchedule:
            "Weekly hours needed"
        case .unavailable:
            "Availability unavailable"
        }
    }

    private var detail: String {
        switch state {
        case .available:
            "Taking new booking requests"
        case .paused:
            "Your profile is not accepting new requests"
        case .needsSchedule:
            "Add enabled hours before accepting requests"
        case .unavailable:
            "Pull to refresh your current status"
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

    static func date(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return "Date unavailable"
        }
        return date.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
        )
    }

    static func time(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return "Time unavailable"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
