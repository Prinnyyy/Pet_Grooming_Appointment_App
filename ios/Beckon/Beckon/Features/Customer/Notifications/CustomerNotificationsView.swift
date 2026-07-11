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
            await refreshAndMarkRead()
        }
        .foregroundRefreshable {
            await refreshAndMarkRead()
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

    private func refreshAndMarkRead() async {
        await store.load()
        await store.markAllRead()
    }
}

private struct CustomerNotificationRow: View {
    let notification: CustomerNotification

    var body: some View {
        BeckonCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(notification.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notification.body)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
                    if !notification.isRead {
                        Circle()
                            .fill(DesignTokens.Colors.customerPrimaryDark)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }

                    Text(notification.createdAtSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
