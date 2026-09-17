import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class SystemNotificationsLifecycleTests: XCTestCase {
    func testLeavingNotificationsDoesNotMarkUnopenedRowsRead() async throws {
        var readAllCount = 0
        var didAppear = false
        let appeared = expectation(description: "Notification page appeared")
        let page = BeckonSystemNotificationsView(
            presentation: .customer, notifications: [], isLoading: false,
            isLoadingMore: false, canLoadMore: false, errorMessage: nil,
            loadAction: {
                if !didAppear { didAppear = true; appeared.fulfill() }
            }, loadNextPageAction: {},
            markAllReadAction: { readAllCount += 1 }
        )
        let host = UIHostingController(rootView: AnyView(page))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        await fulfillment(of: [appeared], timeout: 3)
        host.rootView = AnyView(Text("Next page"))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(readAllCount, 0)
    }
}

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
