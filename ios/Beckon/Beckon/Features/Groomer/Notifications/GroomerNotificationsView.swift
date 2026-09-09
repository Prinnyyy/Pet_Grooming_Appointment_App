import SwiftUI

struct GroomerNotificationsView: View {
    @State private var store: GroomerNotificationsStore
    private let requestStore: GroomerRequestsStore?
    private let bookingStore: BookingsStore?
    private let chatStore: ChatStore?
    @State private var selectedID: UUID?
    @State private var destination: NotificationDestination?

    init(
        store: GroomerNotificationsStore,
        requestStore: GroomerRequestsStore? = nil,
        bookingStore: BookingsStore? = nil,
        chatStore: ChatStore? = nil
    ) {
        _store = State(initialValue: store)
        self.requestStore = requestStore
        self.bookingStore = bookingStore
        self.chatStore = chatStore
    }

    var body: some View {
        BeckonSystemNotificationsView(
            presentation: .groomer,
            notifications: store.notifications.map(\.systemNotificationItem),
            isLoading: store.isLoading,
            isLoadingMore: store.isLoadingMore,
            canLoadMore: store.canLoadMore,
            errorMessage: store.errorMessage,
            loadAction: store.load,
            loadNextPageAction: store.loadNextPage,
            markAllReadAction: store.markAllRead,
            selectAction: { selectedID = $0 }
        )
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
                if let requestStore { GroomerRequestDetailView(matchID: id, store: requestStore) }
            case let .booking(id):
                if let bookingStore { BookingDetailView(bookingID: id, role: .groomer, store: bookingStore) }
            case let .message(conversation):
                if let chatStore { ChatThreadView(participantID: conversation.groomerID, role: .groomer, conversation: conversation, store: chatStore) }
            case .offer: EmptyView()
            }
        }
    }
}

private extension GroomerNotification {
    var systemNotificationItem: BeckonSystemNotificationItem {
        BeckonSystemNotificationItem(
            id: id,
            title: title,
            body: body,
            isRead: isRead,
            createdAtSummary: createdAtSummary
        )
    }
}
