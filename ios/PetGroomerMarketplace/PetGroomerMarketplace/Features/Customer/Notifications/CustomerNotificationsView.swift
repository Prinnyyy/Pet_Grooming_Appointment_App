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
                    .accessibilityIdentifier("customer.notifications.mark-all-read")
                }
            }
        }
        .task {
            await store.load()
        }
        .accessibilityIdentifier("customer.notifications")
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.notifications.isEmpty {
            ScrollView {
                GroomlyLoadingView(
                    title: "Loading Notifications...",
                    message: "Checking your latest Groomly updates.",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomlySectionHeader(
                        "System Updates",
                        subtitle: unreadSummary
                    )

                    if let errorMessage = store.errorMessage {
                        GroomlyErrorBanner(
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
                            .buttonStyle(GroomlySecondaryButtonStyle(accent: .customer))
                            .disabled(store.isLoading)
                        }
                        .accessibilityIdentifier("customer.notifications.error")
                    }

                    if store.notifications.isEmpty, store.errorMessage == nil {
                        GroomlyEmptyState(
                            title: "No Notifications",
                            message: "System updates about requests and bookings will appear here.",
                            systemImage: "bell",
                            accent: .customer
                        )
                        .accessibilityIdentifier("customer.notifications.empty")
                    } else {
                        ForEach(store.notifications) { notification in
                            CustomerNotificationRow(
                                notification: notification,
                                isMarkingRead: store.isMarkingRead(notification)
                            ) {
                                Task {
                                    await store.markRead(notification)
                                }
                            }
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

private struct CustomerNotificationRow: View {
    let notification: CustomerNotification
    let isMarkingRead: Bool
    let markReadAction: () -> Void

    var body: some View {
        GroomlyCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: notification.kind.systemImage)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                        .frame(
                            width: DesignTokens.Spacing.xl * 1.4,
                            height: DesignTokens.Spacing.xl * 1.4
                        )
                        .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                        .clipShape(DesignTokens.Shapes.circular)

                    if !notification.isRead {
                        Circle()
                            .fill(DesignTokens.Colors.groomerAccent)
                            .frame(width: 9, height: 9)
                            .offset(x: -2, y: 2)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Text(notification.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !notification.isRead {
                            Text("Unread")
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        }
                    }

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
                            .buttonStyle(GroomlySecondaryButtonStyle(accent: .customer))
                            .disabled(isMarkingRead)
                            .accessibilityIdentifier("customer.notifications.mark-read")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
