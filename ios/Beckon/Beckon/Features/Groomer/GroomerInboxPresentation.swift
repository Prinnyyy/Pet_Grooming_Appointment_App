import Foundation

nonisolated struct GroomerConversationListPresentation: Equatable, Sendable {
    let title = "Conversations"
    let subtitle: String
    let showsGroupedSurface: Bool

    init(conversationCount: Int, unreadConversationCount: Int) {
        showsGroupedSurface = conversationCount > 0
        subtitle = Self.unreadSummary(for: unreadConversationCount)
    }

    private static func unreadSummary(for count: Int) -> String {
        switch count {
        case 0:
            "All conversations are read."
        case 1:
            "1 unread conversation."
        default:
            "\(count) unread conversations."
        }
    }
}

nonisolated struct GroomerNotificationsListPresentation: Equatable, Sendable {
    let title = "Updates"
    let subtitle: String
    let canMarkAllRead: Bool

    init(unreadCount: Int) {
        canMarkAllRead = unreadCount > 0
        subtitle = Self.unreadSummary(for: unreadCount)
    }

    private static func unreadSummary(for count: Int) -> String {
        switch count {
        case 0:
            "All notifications are read."
        case 1:
            "1 unread notification."
        default:
            "\(count) unread notifications."
        }
    }
}
