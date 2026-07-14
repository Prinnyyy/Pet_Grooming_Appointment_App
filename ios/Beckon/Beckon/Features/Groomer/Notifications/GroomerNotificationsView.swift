import SwiftUI

struct GroomerNotificationsView: View {
    @State private var store: GroomerNotificationsStore
    let routeAction: (GroomerNotificationRoute) -> Void

    init(
        store: GroomerNotificationsStore,
        routeAction: @escaping (GroomerNotificationRoute) -> Void = { _ in }
    ) {
        _store = State(initialValue: store)
        self.routeAction = routeAction
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
            selectAction: openNotification
        )
    }

    private func openNotification(id: UUID) {
        guard let notification = store.notifications.first(where: { $0.id == id }) else {
            return
        }
        routeAction(notification.route)
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
