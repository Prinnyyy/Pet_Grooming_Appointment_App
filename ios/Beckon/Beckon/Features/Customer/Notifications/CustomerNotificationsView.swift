import SwiftUI

struct CustomerNotificationsView: View {
    @State private var store: CustomerNotificationsStore

    init(store: CustomerNotificationsStore) {
        _store = State(initialValue: store)
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
            markAllReadAction: store.markAllRead
        )
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
