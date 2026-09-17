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

    var body: some View {
        BeckonSystemNotificationsView(
            presentation: .customer,
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
                if let requestStore { CustomerRequestDetailView(requestID: id, store: requestStore) }
            case let .offer(requestID, offerID):
                if let requestStore, let request = requestStore.request(withID: requestID) {
                    CustomerOfferDetailView(request: request, offerID: offerID, store: requestStore)
                }
            case let .booking(id):
                if let bookingStore { BookingDetailView(bookingID: id, role: .customer, store: bookingStore) }
            case let .message(conversation):
                if let chatStore { ChatThreadView(participantID: conversation.customerID, role: .customer, conversation: conversation, store: chatStore) }
            }
        }
    }
}

private extension CustomerNotification {
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
