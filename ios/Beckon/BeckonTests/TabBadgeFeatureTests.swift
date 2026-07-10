import Testing
@testable import Beckon

struct TabBadgeFeatureTests {
    @Test
    func customerTabsExposeNotificationAndMessageBadges() {
        #expect(
            CustomerTab.home.badgeCount(
                unreadNotificationCount: 3,
                unreadMessageCount: 2
            ) == 3
        )
        #expect(
            CustomerTab.messages.badgeCount(
                unreadNotificationCount: 3,
                unreadMessageCount: 2
            ) == 2
        )
        #expect(
            CustomerTab.requests.badgeCount(
                unreadNotificationCount: 3,
                unreadMessageCount: 2
            ) == 0
        )
    }

    @Test
    func groomerTabsExposeNotificationAndMessageBadges() {
        #expect(
            GroomerTab.notifications.badgeCount(
                unreadNotificationCount: 4,
                unreadMessageCount: 5
            ) == 4
        )
        #expect(
            GroomerTab.messages.badgeCount(
                unreadNotificationCount: 4,
                unreadMessageCount: 5
            ) == 5
        )
        #expect(
            GroomerTab.requests.badgeCount(
                unreadNotificationCount: 4,
                unreadMessageCount: 5
            ) == 0
        )
    }
}
