import Testing
@testable import Beckon

struct SystemNotificationsPresentationTests {
    @Test
    func customerAndGroomerShareNotificationPageAndBellStyles() {
        let customer = BeckonSystemNotificationsPresentation.customer
        let groomer = BeckonSystemNotificationsPresentation.groomer

        #expect(customer.sectionTitle == "System Updates")
        #expect(groomer.sectionTitle == customer.sectionTitle)
        #expect(groomer.pageStyle == customer.pageStyle)
        #expect(groomer.rowStyle == customer.rowStyle)
        #expect(groomer.bellStyle == customer.bellStyle)
        #expect(customer.accessibilityPrefix == "customer.notifications")
        #expect(groomer.accessibilityPrefix == "groomer.notifications")
        #expect(customer.audience == .customer)
        #expect(groomer.audience == .groomer)
    }

    @Test
    func sharedBellUsesUnreadDotInsteadOfRoleSpecificCountBadge() {
        #expect(BeckonNotificationBellPresentation(unreadCount: 0).showsUnreadDot == false)
        #expect(BeckonNotificationBellPresentation(unreadCount: 3).showsUnreadDot)
        #expect(BeckonNotificationBellPresentation(unreadCount: -1).showsUnreadDot == false)
        #expect(BeckonNotificationBellPresentation(unreadCount: 3).accessibilityValue == "3 unread")
    }
}
