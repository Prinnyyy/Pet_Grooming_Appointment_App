import SwiftUI

struct CustomerNotificationsView: View {
    @State private var store: CustomerNotificationsStore
    private let requestStore: CustomerRequestsStore?
    private let bookingStore: BookingsStore?
    private let chatStore: ChatStore?
    @State private var selectedID: UUID?
    @State private var destination: NotificationDestination?

    init(store: CustomerNotificationsStore, requestStore: CustomerRequestsStore? = nil,
         bookingStore: BookingsStore? = nil, chatStore: ChatStore? = nil) {
        _store = State(initialValue: store)
        self.requestStore = requestStore
        self.bookingStore = bookingStore
        self.chatStore = chatStore
    }

    private var unread: [CustomerNotification] { store.notifications.filter { !$0.isRead } }
    private var earlier: [CustomerNotification] { store.notifications.filter(\.isRead) }

    var body: some View {
        DesignPage(rhythm: .list, cascades: false) {
            if store.isLoading && store.notifications.isEmpty {
                BeckonLoadingView(title: "Loading notifications...", message: "Checking your latest Beckon updates.",
                    accent: .customer)
            } else if store.notifications.isEmpty, let message = store.errorMessage {
                loadError(message)
            } else if store.notifications.isEmpty {
                BeckonLedgeNote(systemImage: "bell", text: "No updates yet. News about your grooming lands here.")
                    .accessibilityIdentifier("customer.notifications.empty")
            } else {
                summary.beckonEntrance(0)
                if !unread.isEmpty { group("New", systemImage: "bell.fill", items: unread, order: 1) }
                if !earlier.isEmpty { group("Earlier", systemImage: "clock.fill", items: earlier, order: 1 + (unread.isEmpty ? 0 : min(unread.count, 4))) }
                if let message = store.errorMessage {
                    loadError(message)
                }
                if store.canLoadMore || store.isLoadingMore {
                    Button { Task { await store.loadNextPage() } } label: {
                        DesignQuietAction(title: store.isLoadingMore ? "Loading…" : "Load more", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .disabled(store.isLoadingMore)
                    .accessibilityIdentifier("customer.notifications.load-more")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundRefreshable { await store.load() }
        .task { await store.load() }
        .accessibilityIdentifier("customer.notifications")
        .overlay { if selectedID != nil { ProgressView().accessibilityLabel("Opening notification") } }
        .task(id: selectedID) {
            guard let id = selectedID, let notification = store.notifications.first(where: { $0.id == id }) else { return }
            let target = await store.resolveDestination(notification, requests: requestStore, bookings: bookingStore, chat: chatStore)
            guard !Task.isCancelled else { return }
            destination = target
            selectedID = nil
        }
        .navigationDestination(item: $destination) { target in
            switch target {
            case let .request(id):
                if let requestStore { GroomingDetailView(target: .request(id), requestStore: requestStore, bookingsStore: bookingStore) }
            case let .offer(requestID, offerID):
                if let requestStore, let request = requestStore.request(withID: requestID) {
                    CustomerOfferDetailView(request: request, offerID: offerID, store: requestStore)
                }
            case let .booking(id):
                if let bookingStore { GroomingDetailView(target: .booking(id), requestStore: requestStore, bookingsStore: bookingStore) }
            case let .message(conversation):
                if let chatStore { ChatThreadView(participantID: conversation.customerID, role: .customer, conversation: conversation, store: chatStore) }
            }
        }
    }

    private func loadError(_ message: String) -> some View {
        BeckonErrorBanner(title: "Notifications unavailable", message: message) {
            Button("Try again", systemImage: "arrow.clockwise") { Task { await store.load() } }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer, isFullWidth: false))
                .disabled(store.isLoading)
        }
        .accessibilityIdentifier("customer.notifications.error")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: unread.isEmpty ? "checkmark.circle.fill" : "bell.badge.fill")
                    .font(DesignTokens.Typography.Expressive.glyphLarge)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(width: 52, height: 52)
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
                .disabled(store.isMarkingAllRead || store.isLoading)
                .accessibilityIdentifier("customer.notifications.mark-all-read")
            }
        }
        .designBanner()
    }

    private func group(_ title: String, systemImage: String, items: [CustomerNotification], order: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: systemImage, count: items.count)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                CustomerNotificationCard(notification: item) { selectedID = item.id }
                    .beckonEntrance(order + min(index, 3))
            }
        }
    }
}

private struct CustomerNotificationCard: View {
    let notification: CustomerNotification
    let action: () -> Void

    private var glyph: String {
        switch notification.kind {
        case .requestPublished: "paperplane.fill"
        case .requestCancelled: "xmark.circle.fill"
        case .newOffer: "tag.fill"
        case .bookingConfirmed: "calendar.badge.checkmark"
        case .bookingCancelled: "calendar.badge.minus"
        case .newMessage: "bubble.left.fill"
        case .unknown: "bell.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: glyph)
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(notification.isRead ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.customerInk)
                    .frame(width: 44, height: 44)
                    .background(notification.isRead ? DesignTokens.Colors.customerTint : DesignTokens.Colors.customerFill,
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Text(notification.title)
                            .font(notification.isRead ? DesignTokens.Typography.Expressive.emphasis : DesignTokens.Typography.Expressive.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if !notification.isRead {
                            Circle().fill(DesignTokens.Colors.customerDeep).frame(width: 10, height: 10)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(notification.body)
                        .designSupportingText()
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
        .accessibilityIdentifier("customer.notifications.open")
    }
}
