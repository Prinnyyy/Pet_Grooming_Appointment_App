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
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.unreadCount > 0 {
                    Button {
                        Task {
                            await store.markAllRead()
                        }
                    } label: {
                        Label("Mark All Read", systemImage: "checkmark.circle")
                    }
                    .disabled(store.isMarkingAllRead)
                    .accessibilityIdentifier("groomer.notifications.mark-all-read")
                }
            }
        }
        .foregroundRefreshable {
            await store.load()
        }
        .accessibilityIdentifier("groomer.notifications")
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.notifications.isEmpty {
            ScrollView {
                BeckonLoadingView(
                    title: "Loading Notifications...",
                    message: "Checking your latest Beckon updates.",
                    accent: .groomer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    BeckonSectionHeader(
                        "System Updates",
                        subtitle: unreadSummary
                    )

                    if let errorMessage = store.errorMessage {
                        BeckonErrorBanner(
                            title: "Notifications Unavailable",
                            message: errorMessage
                        ) {
                            Button {
                                Task {
                                    await store.load()
                                }
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                            .disabled(store.isLoading)
                        }
                        .accessibilityIdentifier("groomer.notifications.error")
                    }

                    if store.notifications.isEmpty, store.errorMessage == nil {
                        BeckonEmptyState(
                            title: "No Notifications",
                            message: "System updates about matches, bookings, and messages will appear here.",
                            systemImage: "bell",
                            accent: .groomer
                        )
                        .accessibilityIdentifier("groomer.notifications.empty")
                    } else {
                        ForEach(store.notifications) { notification in
                            GroomerNotificationRow(
                                notification: notification,
                                isMarkingRead: store.isMarkingRead(notification),
                                openAction: {
                                    routeAction(notification.route)
                                },
                                markReadAction: {
                                    Task {
                                        await store.markRead(notification)
                                    }
                                }
                            )
                        }
                    }

                    if store.canLoadMore || store.isLoadingMore {
                        BeckonLoadMoreButton(
                            isLoading: store.isLoadingMore,
                            accent: .groomer,
                            accessibilityIdentifier: "groomer.notifications.load-more"
                        ) {
                            await store.loadNextPage()
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
    }

    private var unreadSummary: String {
        switch store.unreadCount {
        case 0:
            "All notifications are read."
        case 1:
            "1 unread notification."
        default:
            "\(store.unreadCount) unread notifications."
        }
    }
}

private struct GroomerNotificationRow: View {
    let notification: GroomerNotification
    let isMarkingRead: Bool
    let openAction: () -> Void
    let markReadAction: () -> Void

    var body: some View {
        BeckonCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notification.kind.systemImage)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(
                            width: DesignTokens.Spacing.xl * 1.4,
                            height: DesignTokens.Spacing.xl * 1.4
                        )
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                        .clipShape(DesignTokens.Shapes.circular)

                    if !notification.isRead {
                        Circle()
                            .fill(DesignTokens.Colors.customerPrimary)
                            .frame(width: 9, height: 9)
                            .offset(x: -2, y: 2)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Button(action: openAction) {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                            Text(notification.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            if !notification.isRead {
                                Text("Unread")
                                    .font(DesignTokens.Typography.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("groomer.notifications.open")

                    Text(notification.body)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(notification.createdAtSummary, systemImage: "clock")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)

                        Spacer()

                        if !notification.isRead {
                            Button(action: markReadAction) {
                                Label("Mark Read", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                            .disabled(isMarkingRead)
                            .accessibilityIdentifier("groomer.notifications.mark-read")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
