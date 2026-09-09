import SwiftUI

nonisolated struct BeckonNotificationBellPresentation: Equatable, Sendable {
    let showsUnreadDot: Bool
    let accessibilityValue: String

    init(unreadCount: Int) {
        let safeCount = max(0, unreadCount)
        showsUnreadDot = safeCount > 0
        accessibilityValue = "\(safeCount) unread"
    }
}

nonisolated struct BeckonSystemNotificationsPresentation: Equatable, Sendable {
    enum Audience: Equatable, Sendable {
        case customer
        case groomer
    }

    enum PageStyle: Equatable, Sendable {
        case standard
    }

    enum RowStyle: Equatable, Sendable {
        case cardWithLeadingUnreadDot
    }

    enum BellStyle: Equatable, Sendable {
        case circularUnreadDot
    }

    let sectionTitle = "System Updates"
    let sectionSubtitle: String
    let emptyMessage: String
    let accessibilityPrefix: String
    let audience: Audience
    let pageStyle: PageStyle = .standard
    let rowStyle: RowStyle = .cardWithLeadingUnreadDot
    let bellStyle: BellStyle = .circularUnreadDot

    static let customer = Self(
        sectionSubtitle: "Request, offer, booking, and message activity appears here.",
        emptyMessage: "System updates about requests and bookings will appear here.",
        accessibilityPrefix: "customer.notifications",
        audience: .customer
    )

    static let groomer = Self(
        sectionSubtitle: "Match, offer, booking, and message activity appears here.",
        emptyMessage: "System updates about matches, bookings, and messages will appear here.",
        accessibilityPrefix: "groomer.notifications",
        audience: .groomer
    )
}

nonisolated struct BeckonSystemNotificationItem: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let isRead: Bool
    let createdAtSummary: String
}

struct BeckonNotificationBellButton: View {
    let unreadCount: Int
    let accessibilityIdentifier: String
    let action: () -> Void

    private var presentation: BeckonNotificationBellPresentation {
        BeckonNotificationBellPresentation(unreadCount: unreadCount)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(DesignTokens.Typography.cardTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(DesignTokens.Colors.surface)
                    .clipShape(DesignTokens.Shapes.circular)
                    .overlay {
                        Circle()
                            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                    }
                    .beckonShadow(DesignTokens.Shadows.smallCard)

                if presentation.showsUnreadDot {
                    Circle()
                        .fill(DesignTokens.Colors.notificationUnread)
                        .frame(width: 10, height: 10)
                        .padding(.top, DesignTokens.Spacing.sm)
                        .padding(.trailing, DesignTokens.Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Notifications")
        .accessibilityValue(presentation.accessibilityValue)
    }
}

struct BeckonSystemNotificationsView: View {
    let presentation: BeckonSystemNotificationsPresentation
    let notifications: [BeckonSystemNotificationItem]
    let isLoading: Bool
    let isLoadingMore: Bool
    let canLoadMore: Bool
    let errorMessage: String?
    let loadAction: () async -> Void
    let loadNextPageAction: () async -> Void
    let markAllReadAction: () async -> Void
    var selectAction: ((UUID) -> Void)? = nil

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Notifications")
        .task {
            await loadAction()
        }
        .onDisappear {
            Task {
                await markAllReadAction()
            }
        }
        .foregroundRefreshable {
            await loadAction()
        }
        .accessibilityIdentifier(presentation.accessibilityPrefix)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, notifications.isEmpty {
            ScrollView {
                BeckonLoadingView(
                    title: "Loading Notifications...",
                    message: "Checking your latest Beckon updates.",
                    accent: loadingAccent
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    BeckonSectionHeader(
                        presentation.sectionTitle,
                        subtitle: presentation.sectionSubtitle
                    )

                    if let errorMessage {
                        BeckonErrorBanner(
                            title: "Notifications Unavailable",
                            message: errorMessage
                        ) {
                            Button {
                                Task {
                                    await loadAction()
                                }
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonSecondaryButtonStyle(accent: actionAccent))
                            .disabled(isLoading)
                        }
                        .accessibilityIdentifier("\(presentation.accessibilityPrefix).error")
                    }

                    if notifications.isEmpty, errorMessage == nil {
                        BeckonEmptyState(
                            title: "No Notifications",
                            message: presentation.emptyMessage,
                            systemImage: "bell",
                            accent: emptyStateAccent
                        )
                        .accessibilityIdentifier("\(presentation.accessibilityPrefix).empty")
                    } else {
                        ForEach(notifications) { notification in
                            notificationRow(notification)
                        }
                    }

                    if canLoadMore || isLoadingMore {
                        BeckonLoadMoreButton(
                            isLoading: isLoadingMore,
                            accent: actionAccent,
                            accessibilityIdentifier: "\(presentation.accessibilityPrefix).load-more"
                        ) {
                            await loadNextPageAction()
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func notificationRow(_ notification: BeckonSystemNotificationItem) -> some View {
        if let selectAction {
            Button {
                selectAction(notification.id)
            } label: {
                BeckonSystemNotificationRow(notification: notification)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(presentation.accessibilityPrefix).open")
        } else {
            BeckonSystemNotificationRow(notification: notification)
        }
    }

    private var loadingAccent: BeckonLoadingView.Accent {
        presentation.audience == .groomer ? .groomer : .customer
    }

    private var emptyStateAccent: BeckonEmptyState<EmptyView>.Accent {
        presentation.audience == .groomer ? .groomer : .customer
    }

    private var actionAccent: BeckonSecondaryButtonStyle.Accent {
        presentation.audience == .groomer ? .groomer : .customer
    }
}

private struct BeckonSystemNotificationRow: View {
    let notification: BeckonSystemNotificationItem

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                        title.fixedSize()
                        Spacer(minLength: DesignTokens.Spacing.md)
                        timestamp.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        title.fixedSize(horizontal: false, vertical: true)
                        timestamp.fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(notification.body)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay(alignment: .leading) {
            if !notification.isRead {
                Circle()
                    .fill(DesignTokens.Colors.notificationUnread)
                    .frame(width: 9, height: 9)
                    .offset(x: -14)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text(notification.title)
            .font(DesignTokens.Typography.headline)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    private var timestamp: some View {
        Text(notification.createdAtSummary)
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
    }
}
