// The groomer's notifications in the customer prototype's language (design): the bell on Home opens it. Same job as
// Features/Groomer/Notifications/GroomerNotificationsView.swift: the updates, new ones first, Mark all read, and a tap that goes to
// the thing the update is about (a request, a booking, a conversation). The store and its destination rules are the real ones.
import SwiftUI


struct GroomerNotificationsView: View {
    @State private var store: GroomerNotificationsStore
    private let requestStore: GroomerRequestsStore?
    private let offerStore: GroomerOffersStore?
    private let onOpenBooking: ((Booking) -> Void)?
    private let bookingStore: BookingsStore?
    private let chatStore: ChatStore?
    @State private var selectedID: UUID?
    @State private var destination: NotificationDestination?
    /// The last try to load more updates failed, from what the page's own call returned (the store's `errorMessage` is also set by
    /// an update that cannot be opened), design.
    @State private var moreFailed = false

    init(store: GroomerNotificationsStore, requestStore: GroomerRequestsStore? = nil, offerStore: GroomerOffersStore? = nil,
         bookingStore: BookingsStore? = nil, chatStore: ChatStore? = nil, onOpenBooking: ((Booking) -> Void)? = nil) {
        _store = State(initialValue: store)
        self.requestStore = requestStore
        self.offerStore = offerStore
        self.onOpenBooking = onOpenBooking
        self.bookingStore = bookingStore
        self.chatStore = chatStore
    }

    private var unread: [GroomerNotification] { store.notifications.filter { !$0.isRead } }
    private var earlier: [GroomerNotification] { store.notifications.filter(\.isRead) }

    var body: some View {
        DesignPage(rhythm: .list, cascades: false) {
            if store.isLoading && !store.hasLoadedOnce && store.notifications.isEmpty {
                BeckonLoadingView(title: "Loading updates…", message: "Checking for news about your requests and bookings.",
                    accent: .groomer)
            } else if store.notifications.isEmpty, let message = store.errorMessage {
                BeckonErrorBanner(title: "Updates didn't load", message: message) {
                    Button { Task { await store.load() } } label: {
                        DesignQuietAction(title: "Try again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                }
            } else if store.notifications.isEmpty {
                BeckonLedgeNote(systemImage: "bell", text: "No updates yet. News about your requests and bookings lands here.")
            } else {
                summary.beckonEntrance(0)
                if !unread.isEmpty { group("New", systemImage: "bell.fill", items: unread, order: 1) }
                if !earlier.isEmpty {
                    group("Earlier", systemImage: "clock.fill", items: earlier, order: 1 + (unread.isEmpty ? 0 : min(unread.count, 4)))
                }
                if store.canLoadMore || store.isLoadingMore {
                    BeckonLoadMoreButton(isLoading: store.isLoadingMore, accent: .groomer,
                        accessibilityIdentifier: "groomer.notifications.load-more", title: "Load more", failed: moreFailed) {
                        moreFailed = false
                        await store.loadNextPage()
                        moreFailed = store.loadMoreErrorMessage != nil
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            moreFailed = false
            await store.load()
        }
        .task { await store.load() }
        .background {
            BeckonGlobalFeedbackForwarder(error: store.actionErrorMessage.map {
                BeckonGlobalFeedbackError(scope: .page("groomer.notifications"), sourceKey: "groomer.notifications.action",
                    title: "Notification update failed", message: $0)
            })
        }
        .overlay { if selectedID != nil { ProgressView().accessibilityLabel("Opening notification") } }
        .task(id: selectedID) {
            guard let id = selectedID, let notification = store.notifications.first(where: { $0.id == id }) else { return }
            let target = await store.resolveDestination(notification, requests: requestStore, bookings: bookingStore, chat: chatStore)
            guard !Task.isCancelled else { return }
            destination = target
            selectedID = nil
        }
        .beckonResetsNavigation { destination = nil }
        .beckonNavigationDestination(item: $destination) { target in
            switch target {
            case let .request(id):
                if let requestStore, let offerStore {
                    GroomerRequestDetailView(target: .match(id), requests: requestStore, offers: offerStore, onOpenBooking: onOpenBooking)
                }
            case let .booking(id):
                if let bookingStore { BookingDetailView(bookingID: id, role: .groomer, store: bookingStore) }
            case let .message(conversation):
                if let chatStore {
                    ChatThreadView(participantID: conversation.groomerID, role: .groomer, conversation: conversation, store: chatStore)
                }
            case .offer:
                EmptyView()
            }
        }
    }

    /// How many are new, in the coral banner, with the one button that clears them.
    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: unread.isEmpty ? "checkmark.circle.fill" : "bell.badge.fill")
                    .font(DesignTokens.Typography.Expressive.glyphLarge)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
                    .background(DesignTokens.Colors.surface, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(unread.isEmpty ? "You're all caught up" : "\(unread.count) new update\(unread.count == 1 ? "" : "s")")
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.customerInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(unread.isEmpty ? "Nothing waiting for you." : "Tap one to jump straight to it.")
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.customerInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !unread.isEmpty {
                Button { Task { await store.markAllRead() } } label: {
                    Text("Mark all read")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerInk)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.primary))
                .disabled(store.isMarkingAllRead)
                .accessibilityIdentifier("groomer.notifications.mark-all-read")
            }
        }
        .designBanner()
    }

    private func group(_ title: String, systemImage: String, items: [GroomerNotification], order: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: systemImage, count: items.count)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                GroomerNotificationCard(notification: item) { selectedID = item.id }
                    .beckonEntrance(order + min(index, 3))
            }
        }
    }
}


private struct GroomerNotificationCard: View {
    let notification: GroomerNotification
    let action: () -> Void

    private var glyph: String {
        switch notification.kind {
        case .newMatch: "tray.full.fill"
        case .offerAccepted: "checkmark.seal.fill"
        case .bookingCancelledByCustomer: "calendar.badge.minus"
        case .newMessage: "bubble.left.fill"
        case .unknown: "bell.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) { button }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("groomer.notifications.row")
    }

    private var button: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: glyph, size: .touch, font: DesignTokens.Typography.Expressive.glyph,
                    tone: notification.isRead ? .customer : .solid)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Text(notification.title)
                            .font(notification.isRead ? DesignTokens.Typography.Expressive.emphasis
                                : DesignTokens.Typography.Expressive.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if !notification.isRead {
                            Circle().fill(DesignTokens.Colors.customerDeep)
                                .frame(width: DesignTokens.Spacing.md, height: DesignTokens.Spacing.md)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(notification.body).designSupportingText()
                    Text(notification.createdAtSummary)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignTokens.Spacing.lg)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? "Read" : "Unread")
        .accessibilityIdentifier("groomer.notifications.open")
    }
}
