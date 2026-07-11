import SwiftUI

struct CustomerNotificationsView: View {
    @State private var store: CustomerNotificationsStore

    init(store: CustomerNotificationsStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Notifications")
        .task {
            await store.load()
        }
        .onDisappear {
            Task {
                await store.markAllRead()
            }
        }
        .foregroundRefreshable {
            await store.load()
        }
        .accessibilityIdentifier("customer.notifications")
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.notifications.isEmpty {
            ScrollView {
                BeckonLoadingView(
                    title: "Loading Notifications...",
                    message: "Checking your latest Beckon updates.",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    BeckonSectionHeader(
                        "System Updates",
                        subtitle: "Request, offer, booking, and message activity appears here."
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
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
                            .disabled(store.isLoading)
                        }
                        .accessibilityIdentifier("customer.notifications.error")
                    }

                    if store.notifications.isEmpty, store.errorMessage == nil {
                        BeckonEmptyState(
                            title: "No Notifications",
                            message: "System updates about requests and bookings will appear here.",
                            systemImage: "bell",
                            accent: .customer
                        )
                        .accessibilityIdentifier("customer.notifications.empty")
                    } else {
                        ForEach(store.notifications) { notification in
                            CustomerNotificationRow(
                                notification: notification
                            )
                        }
                    }

                    if store.canLoadMore || store.isLoadingMore {
                        BeckonLoadMoreButton(
                            isLoading: store.isLoadingMore,
                            accent: .customer,
                            accessibilityIdentifier: "customer.notifications.load-more"
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

}

private struct CustomerNotificationRow: View {
    let notification: CustomerNotification

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    if !notification.isRead {
                        Circle()
                            .fill(DesignTokens.Colors.notificationUnread)
                            .frame(width: 9, height: 9)
                            .alignmentGuide(.firstTextBaseline) { dimensions in
                                dimensions[VerticalAlignment.center]
                            }
                            .accessibilityHidden(true)
                    }

                    Text(notification.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(notification.createdAtSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(notification.body)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
