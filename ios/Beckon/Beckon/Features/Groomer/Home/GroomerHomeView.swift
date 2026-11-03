// The groomer's Home, redesigned in the customer Home's language with the groomer's coral (design). Same job as
// Features/Groomer/Home/GroomerHomeView.swift: the next appointment, what needs attention (new matches, pending offers, unread
// messages), whether the groomer is available, and the bell. The store (`GroomerHomeStore`), its counts and issues, the bell's
// destination and every id are the real ones. What is new is the surface: the greeting and the bell over the scene (sky, two
// ranges, a lawn, in coral), a card with the shared pup that says what is next, and tiles that carry the
// counts as numbers.
//
// design: the Availability card is gone. It said "Available" every day, and the same hours are one tap away in Account; Home shows
// what changes. In its place stands Coming up (the appointments after the one on the card, and the way to the whole schedule).
// Availability is on Home only while it is why no request can reach the groomer (profile paused, no weekly hours): a strip card at
// the top of Needs attention, in the family of the needs-you and error cards.
import SwiftUI


struct GroomerHomeView: View {
    let home: GroomerHomeStore
    let notifications: GroomerNotificationsStore?
    let requests: GroomerRequestsStore
    let offers: GroomerOffersStore
    let bookings: BookingsStore
    let chat: ChatStore?
    let isActiveTab: Bool
    let unreadMessageCount: Int
    let requestsAction: () -> Void
    let offersAction: () -> Void
    let bookingAction: (Booking) -> Void
    let messagesAction: () -> Void
    let availabilityAction: () -> Void
    /// Coming up's "See schedule": the Schedule tab.
    let scheduleAction: () -> Void
    /// Where a paused profile is switched back on: the Account tab (its Profile settings hold the Visibility switch; the real
    /// `GroomerProfileRoute` has no route straight to it, only `.availability`).
    let accountAction: () -> Void
    /// The first load is over (design): until then each place shows its own shape in bars, never an empty state.
    private var isSettled: Bool { home.hasLoadedOnce }
    @State private var isShowingNotifications = false
    /// Where the page is scrolled (design): the scene's layers and the header read it; the page itself does not.
    @State private var scrollDepth = BeckonScrollDepth()
    @State private var isPullArmed = false
    @State private var isHeroActionPressed = false

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            screenContent

        }
        .toolbar(.hidden, for: .navigationBar)

        .beckonResetsNavigation { isShowingNotifications = false }
        .beckonNavigationDestination(isPresented: $isShowingNotifications) {
            if let notifications { GroomerNotificationsView(store: notifications, requestStore: requests, offerStore: offers, bookingStore: bookings,
                chatStore: chat, onOpenBooking: bookingAction) }
        }
        .foregroundRefreshable(isEnabled: isActiveTab) { await load() }
        .accessibilityIdentifier("groomer.home")
    }

    /// Coming up reads the bookings list the Schedule tab reads (the real Home store only asks for the nearest booking).
    private func load() async {
        await home.load()
        await notifications?.load()
    }

    private var screenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                top
                attention.beckonEntrance(2)
                if showsComingUp {
                    comingUp.beckonEntrance(3)
                }
                ForEach(home.issues) { issue in
                    BeckonErrorBanner(title: issue.title, message: issue.message)
                }
                if !home.issues.isEmpty {
                    Button { Task { await home.load() } } label: {
                        DesignQuietAction(title: "Retry unavailable sections", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .disabled(home.isLoading)
                    .accessibilityIdentifier("groomer.home.retry")
                    .beckonEntrance(4)
                }
            }
            .beckonPageInsets(bottom: DesignTokens.Layout.pageBottomInset * 2)
            .beckonEntranceClock()
        }
        .beckonTracksScroll()
        .scrollContentBackground(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollDepth.offset = offset
            let armed = -offset >= BeckonScrollDepth.armedPull
            if armed != isPullArmed { isPullArmed = armed }
        }
        // Pull down and let go: refresh the page (the same load as coming back to the app), as on the customer's Home.
        .onScrollPhaseChange { old, new in
            guard old == .interacting, new != .interacting, isPullArmed, isActiveTab, !scrollDepth.isRefreshing else { return }
            scrollDepth.isRefreshing = true
            Task {
                let started = Date()
                await load()
                let rest = 1.0 - Date().timeIntervalSince(started)
                if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
                scrollDepth.isRefreshing = false
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPullArmed) { _, armed in armed }
    }

    // MARK: Top

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .beckonEntrance(0)
                .beckonStaysWhilePulled(scrollDepth)
                // The scene stands behind the card and reaches up behind the title, so the title is drawn above it.
                .zIndex(1)

            BeckonLoadingHero(isLoading: !isSettled, isExcited: isHeroActionPressed) {
                nextAppointment
            } placeholder: {
                heroBars
            }
            .beckonEntrance(1)
            .beckonScrollEase()
            .background(alignment: .top) {
                BeckonHomeScene(depth: scrollDepth)
                    .padding(.horizontal, -DesignTokens.Layout.pageHorizontalInset)
                    .offset(y: -BeckonHomeScene.headroom)
            }
        }
    }

    private var header: some View {
        HomeHeader(displayName: home.greetingName, unreadNotificationCount: notifications?.unreadCount ?? 0,
            notificationIdentifier: "groomer.home.notifications") {
            isShowingNotifications = true
        }
    }

    /// The live content and its skeleton use the same room. These regions also provide the geometry regression boundary.
    var nextAppointment: some View {
        appointmentLayout(isLoading: false)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(home.nextBooking != nil ? "groomer.home.next-booking" :
                appointmentHasIssue ? "groomer.home.next-booking.error" : "groomer.home.next-booking.empty")
    }

    private var appointmentHasIssue: Bool { home.issues.contains { $0.section == .bookings } }

    private var emptyAppointmentWords: some View {
        heroWords(title: "No upcoming appointment", message: "Confirmed bookings will appear here.")
    }

    private var unavailableAppointmentWords: some View {
        heroWords(title: "Schedule unavailable",
            message: "Pull to refresh this section while the rest of Home remains available.")
    }

    /// Only layout is shared with the approved prototype: all words, photos and actions remain the real Home's.
    private func appointmentLayout(isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    emptyAppointmentWords
                    unavailableAppointmentWords
                    heroBarsMain
                    appointmentMain
                }
                .hidden().accessibilityHidden(true).allowsHitTesting(false)
                .environment(\.scenePhase, .inactive)
                if isLoading { heroBarsMain }
                else { appointmentMain }
            }
            ZStack(alignment: .topLeading) {
                // Measure both real labels, including wrapping at large text sizes. No hidden controls or actions.
                ZStack(alignment: .topLeading) {
                    BeckonLedgePrimaryLabel(title: "View booking", systemImage: "calendar").beckonLedge(.primary)
                    BeckonLedgePrimaryLabel(title: "See new requests", systemImage: "tray.full").beckonLedge(.primary)
                }
                .padding(.top, DesignTokens.Spacing.sm)
                .hidden().accessibilityHidden(true).allowsHitTesting(false)
                if isLoading { heroBarsFooter }
                else { appointmentFooter }
            }
        }
    }

    /// The card's words: the next appointment as it is in the Schedule, or what to do while there is none.
    @ViewBuilder private var appointmentMain: some View {
        if let booking = home.nextBooking {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    GroomerPetAvatar(species: booking.requestPetSnapshot?.species ?? "Dog", data: home.nextBookingPhotoData)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next appointment")
                            .font(DesignTokens.Typography.Expressive.label)
                            .foregroundStyle(DesignTokens.Colors.customerInk)
                        Text(booking.requestPetSnapshot?.name ?? "Pet appointment")
                            .font(DesignTokens.Typography.Expressive.hero)
                            .foregroundStyle(DesignTokens.Colors.customerInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                    BeckonMetaChip(text: booking.appointmentServiceTitle, systemImage: "scissors")
                    BeckonMetaChip(text: booking.scheduledTimeSummary, systemImage: "calendar")
                    BeckonMetaChip(text: Self.shortAddress(of: booking), systemImage: "mappin")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(booking.appointmentServiceTitle), \(booking.scheduledTimePresentation.accessibilityLabel), \(booking.appointmentAddressSummary)")
            }
        } else if appointmentHasIssue {
            unavailableAppointmentWords
        } else {
            emptyAppointmentWords
        }
    }

    @ViewBuilder private var appointmentFooter: some View {
        if let booking = home.nextBooking {
            heroButton(title: "View booking", systemImage: "calendar", identifier: "groomer.home.next-booking.view") {
                bookingAction(booking)
            }
        } else if !appointmentHasIssue {
            heroButton(title: "See new requests", systemImage: "tray.full", identifier: "groomer.home.next-booking.requests",
                action: requestsAction)
        }
    }

    /// Where the appointment is, as short as it can be said: the street and the city.
    private static func shortAddress(of booking: Booking) -> String {
        let parts = [booking.customerStreetAddress, booking.customerCity].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? booking.appointmentAddressSummary : parts.joined(separator: ", ")
    }

    private func heroWords(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.hero)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroButton(title: String, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BeckonLedgePrimaryLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.primary) { isHeroActionPressed = $0 })
        .padding(.top, DesignTokens.Spacing.sm)
        .accessibilityIdentifier(identifier)
    }

    /// Keep the card's measured layout while the first schedule read is pending, with the original mask and sweep.
    var heroBars: some View {
        appointmentLayout(isLoading: true)
            .designSkeleton(label: "Loading your schedule")
            .accessibilityIdentifier("groomer.home.next-booking.loading")
    }

    private var heroBarsMain: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignSkeletonDisc()
                    .frame(width: DesignTokens.Metrics.petAvatar, height: DesignTokens.Metrics.petAvatar)
                VStack(alignment: .leading, spacing: 2) {
                    DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.label)
                    DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.hero)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                BeckonMetaChip(text: "Service", systemImage: "scissors")
                BeckonMetaChip(text: "Appointment time", systemImage: "calendar")
                BeckonMetaChip(text: "Service address", systemImage: "mappin")
            }
            .redacted(reason: .placeholder)
        }
    }

    private var heroBarsFooter: some View {
        BeckonLedgePrimaryLabel(title: "View booking", systemImage: "calendar")
            .hidden()
            .overlay { DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton) }
            .beckonLedge(.primary)
            .padding(.top, DesignTokens.Spacing.sm)
    }

    // MARK: Needs attention

    private var attention: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Needs attention", systemImage: "flag.fill")
            DesignReveal(isLoading: !isSettled) {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    if let blockedState {
                        GroomerHomeAvailabilityAlert(state: blockedState,
                            action: blockedState == .paused ? accountAction : availabilityAction)
                    }
                    tiles
                }
            } placeholder: {
                tileBars
            }
        }
    }

    /// The two states of availability that stop requests from coming in. Available says nothing here, and "not read" is the retry
    /// row's and the toast's.
    private var blockedState: GroomerHomeAvailabilityState? {
        switch home.availabilityState {
        case .paused, .needsSchedule: home.availabilityState
        case .available, .unavailable: nil
        }
    }

    private var tiles: some View {
        GroomerHomeTiles {
            GroomerHomeTile(title: "New matches", systemImage: "tray.full.fill", count: home.newMatchCount,
                hasMore: home.hasMoreMatches, isLoading: home.isLoading, identifier: "groomer.home.matches", action: requestsAction)
            GroomerHomeTile(title: "Pending offers", systemImage: "tag.fill", count: home.pendingOfferCount,
                hasMore: home.hasMoreOffers, isLoading: home.isLoading, identifier: "groomer.home.offers", action: offersAction)
            GroomerHomeTile(title: "Unread messages", systemImage: "bubble.left.fill", count: unreadMessageCount,
                hasMore: false, isLoading: false, identifier: "groomer.home.messages", action: messagesAction)
        }
    }

    private var tileBars: some View {
        GroomerHomeTiles {
            GroomerHomeTileSkeleton(title: "New matches", systemImage: "tray.full.fill")
            GroomerHomeTileSkeleton(title: "Pending offers", systemImage: "tag.fill")
            GroomerHomeTileSkeleton(title: "Unread messages", systemImage: "bubble.left.fill")
        }
        .accessibilityIdentifier("groomer.home.attention.loading")
    }

    // MARK: Coming up

    private static let comingUpLimit = 3

    /// The appointments after the one on the card, soonest first. With no card (nothing booked) there is nothing "after" it.
    private var upcoming: [Booking] {
        guard let next = home.nextBooking else { return [] }
        let now = Date()
        let rest = home.bookings.filter { booking in
            guard booking.id != next.id, booking.status == .confirmed,
                  let end = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd) else { return false }
            return end >= now
        }
        return Array(rest.sortedByScheduledStart(ascending: true).prefix(Self.comingUpLimit))
    }

    /// Home's first load and the bookings list have both answered: until then the module is bars, never an absence.
    private var comingUpIsReady: Bool { isSettled }

    /// Bars while it loads; afterwards the module is there only when there is something to say (the card above already says
    /// when nothing is booked).
    private var showsComingUp: Bool { !comingUpIsReady || !upcoming.isEmpty }

    private var comingUp: some View {
        DesignReveal(isLoading: !comingUpIsReady) {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                BeckonLedgeHeading(title: "Coming up", systemImage: "calendar")
                GroomerHomeComingUpCard(bookings: upcoming, openBooking: bookingAction, seeSchedule: scheduleAction)
            }
        } placeholder: {
            GroomerHomeComingUpSkeleton()
        }
    }
}


// MARK: Parts

/// Three tiles side by side; one under another at accessibility sizes, where a number and its label need the whole width.
private struct GroomerHomeTiles<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder let content: Content

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))) {
            content
        }
    }
}


/// What needs the groomer, as a number: the whole tile opens the list it counts.
struct GroomerHomeTile: View {
    let title: String
    let systemImage: String
    let count: Int?
    let hasMore: Bool
    let isLoading: Bool
    let identifier: String
    let action: () -> Void
    var showsPlaceholder = false

    private var countText: String {
        guard let count else { return isLoading ? "…" : "–" }
        return hasMore ? "\(count)+" : "\(count)"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                    DesignIconDisc(systemImage: systemImage, font: DesignTokens.Typography.Expressive.glyph)
                        .opacity(showsPlaceholder ? 0 : 1)
                        .overlay { if showsPlaceholder { DesignSkeletonDisc() } }
                    Spacer(minLength: 0)
                    Text(countText)
                        .font(DesignTokens.Typography.Expressive.display)
                        .lineLimit(1)
                        .hidden()
                        .overlay(alignment: .trailing) {
                            if showsPlaceholder {
                                DesignSkeletonLine(width: 1, font: DesignTokens.Typography.Expressive.display)
                            } else {
                                // Scaling a count must not shrink its line box and change the tile's height.
                                Text(countText)
                                    .font(DesignTokens.Typography.Expressive.display)
                                    .foregroundStyle((count ?? 0) > 0 ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(DesignTokens.Metrics.homeCountMinimumScale)
                            }
                        }
                }
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(showsPlaceholder ? 0 : 1)
                    .overlay(alignment: .leading) {
                        if showsPlaceholder {
                            Text(title).font(DesignTokens.Typography.Expressive.emphasis)
                                .redacted(reason: .placeholder)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.countTileHeight, alignment: .topLeading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(count.map { "\($0)\(hasMore ? " or more" : "")" } ?? "Not yet available")
        .accessibilityIdentifier(identifier)
    }
}


struct GroomerHomeTileSkeleton: View {
    var title = "Pending offers"
    var systemImage = "tag.fill"

    var body: some View {
        // Static labels are known before the read: reuse their wrapping, type and card surface.
        GroomerHomeTile(title: title, systemImage: systemImage, count: nil, hasMore: false,
            isLoading: true, identifier: "groomer.home.tile.loading", action: {}, showsPlaceholder: true)
            .designSkeleton(label: "Loading")
    }
}


/// Availability, when it is why no request can reach the groomer: a strip card in the family of the needs-you and error cards (the
/// kit's `BeckonStateStrip`), with the words and the way to fix it. A paused profile is switched back on in Profile
/// settings (Visibility), missing weekly hours in Availability. Nothing of it is drawn while availability is fine.
private struct GroomerHomeAvailabilityAlert: View {
    let state: GroomerHomeAvailabilityState
    let action: () -> Void

    private var isPaused: Bool { state == .paused }
    private var title: String { isPaused ? "Requests paused" : "Weekly hours needed" }
    private var detail: String {
        isPaused ? "Your profile is not accepting new requests." : "Add enabled hours before accepting requests."
    }
    private var symbol: String { isPaused ? "pause.circle.fill" : "calendar.badge.exclamationmark" }
    private var actionTitle: String { isPaused ? "Open Account" : "Add weekly hours" }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                BeckonStateStrip(title: title, systemImage: symbol, tone: .warning)
                Text(detail)
                    .designSupportingText()
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DesignRowDivider()
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Spacer(minLength: 0)
                    Text(actionTitle)
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityHint(actionTitle)
        .accessibilityIdentifier("groomer.home.availability")
    }
}


/// The appointments after the one on the card: when, who and what in a row, one tap to open it, and the way to the whole schedule.
private struct GroomerHomeComingUpCard: View {
    let bookings: [Booking]
    let openBooking: (Booking) -> Void
    let seeSchedule: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(bookings, id: \.id) { booking in
                GroomerHomeComingUpRow(booking: booking) { openBooking(booking) }
                DesignRowDivider()
                    .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            Button(action: seeSchedule) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("See schedule")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle(.row))
            .accessibilityIdentifier("groomer.home.coming-up.schedule")
        }
        .beckonLedge(.card)
        .accessibilityIdentifier("groomer.home.coming-up")
    }
}


/// One appointment, laid out as the Schedule's rows are: the day and the start in a column (the day above it, the AM or PM under
/// it), the pet's picture, its name and the service.
private struct GroomerHomeComingUpRow: View {
    let booking: Booking
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = DesignTokens.Metrics.timeColumnWidth

    private var petName: String { booking.requestPetSnapshot?.name ?? "Pet appointment" }

    private var when: BeckonWhen? {
        BeckonWhen(start: booking.scheduledStart, end: booking.scheduledEnd,
            zoneIdentifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier)
    }

    var body: some View {
        Button(action: action) {
            let stacks = typeSize.isAccessibilitySize
            let layout = stacks
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
            layout {
                whenColumn
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    GroomerPetAvatar(species: booking.requestPetSnapshot?.species ?? "Dog",
                        size: DesignTokens.Metrics.petAvatarSmall)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(petName)
                            .font(DesignTokens.Typography.Expressive.emphasis)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(booking.appointmentServiceTitle).designSupportingText()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !stacks {
                        Image(systemName: "chevron.right")
                            .font(DesignTokens.Typography.Expressive.label)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle(.row))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(petName), \(booking.appointmentServiceTitle), \(when?.full ?? booking.scheduledTimeSummary)")
        .accessibilityHint("Opens the booking")
        .accessibilityIdentifier("groomer.home.coming-up.\(booking.id.uuidString.lowercased())")
    }

    /// "Mon", "11:00", "AM": the day first, because here the rows are on different days. At accessibility sizes one line.
    @ViewBuilder
    private var whenColumn: some View {
        if typeSize.isAccessibilitySize {
            Text(when?.short ?? booking.scheduledTimeSummary)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let start = (when?.start ?? "").split(separator: " ").map(String.init)
            VStack(alignment: .leading, spacing: 0) {
                Text(when?.day ?? "")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(start.first ?? "")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                Text(start.dropFirst().first ?? "")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .frame(width: timeWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}


/// Coming up while the schedule is not known: the heading, three rows as bars and the foot, in the card's own size.
private struct GroomerHomeComingUpSkeleton: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth = DesignTokens.Metrics.timeColumnWidth

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            DesignSkeletonHeading()
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    row
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.md)
                    DesignRowDivider()
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                }
                DesignSkeletonLine(width: 0.3, font: DesignTokens.Typography.Expressive.emphasis)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget, alignment: .leading)
            }
            .designSkeleton(label: "Loading appointments")
            .beckonLedge(.card)
        }
    }

    private var row: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            if typeSize.isAccessibilitySize {
                DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.emphasis)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.chip)
                    DesignSkeletonLine(width: 1, font: DesignTokens.Typography.Expressive.emphasis)
                    DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.chip)
                }
                .frame(width: timeWidth)
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignSkeletonDisc()
                    .frame(width: DesignTokens.Metrics.petAvatarSmall, height: DesignTokens.Metrics.petAvatarSmall)
                VStack(alignment: .leading, spacing: 2) {
                    DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.emphasis)
                    DesignSkeletonLine(width: 0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right").font(DesignTokens.Typography.Expressive.label)
                        .hidden().overlay { DesignSkeletonBlock().frame(width: 6) }
                }
            }
        }
    }
}


// Compatibility initializer for existing local fixtures; the shipping shell injects shared Stores.
#if DEBUG
extension GroomerHomeView {
    init(groomerID: UUID, displayName: String, profileRepository: any GroomerProfileRepository,
         requestRepository: any GroomerRequestRepository, bookingRepository: any BookingRepository,
         unreadNotificationCount: Int, unreadMessageCount: Int, notificationStore: GroomerNotificationsStore?,
         debugRecorder: AppDebugEventRecorder? = nil, chatStore: ChatStore? = nil,
         requestsAction: @escaping () -> Void, offersAction: @escaping () -> Void,
         bookingAction: @escaping (Booking) -> Void, messagesAction: @escaping () -> Void,
         availabilityAction: @escaping () -> Void) {
        self.init(home: GroomerHomeStore(groomerID: groomerID, displayName: displayName,
            profileRepository: profileRepository, requestRepository: requestRepository, bookingRepository: bookingRepository,
            debugRecorder: debugRecorder), notifications: notificationStore,
            requests: GroomerRequestsStore(groomerID: groomerID, repository: requestRepository, profileRepository: profileRepository),
            offers: GroomerOffersStore(groomerID: groomerID, repository: requestRepository),
            bookings: BookingsStore(participantID: groomerID, role: .groomer, repository: bookingRepository,
                groomerProfileRepository: profileRepository), chat: chatStore, isActiveTab: true,
            unreadMessageCount: unreadMessageCount, requestsAction: requestsAction, offersAction: offersAction,
            bookingAction: bookingAction, messagesAction: messagesAction, availabilityAction: availabilityAction,
            scheduleAction: {}, accountAction: availabilityAction)
    }
}
#endif
