import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class ChatViewportTests: XCTestCase {
    func testColdHistoryAndCachedReentryStartAtLatestWithoutAVisibleScroll() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let navigation = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let customer = UUID(), groomer = UUID()
        let conversation = ChatConversation(id: UUID(), customerID: customer, groomerID: groomer,
            createdAt: "2026-11-03T12:00:00Z", updatedAt: "2026-11-03T12:00:00Z")
        let messages = (0..<80).map { index in
            ChatMessage(id: UUID(), conversationID: conversation.id, senderID: customer, kind: .text,
                body: "Message \(index): Please use the side entrance for Mochi's appointment.", booking: nil,
                createdAt: String(format: "2026-11-03T12:%02d:%02dZ", index / 60, index % 60))
        }
        let repository = ChatRepositoryFake(conversationsResult: .success([conversation]), messagesResult: .success(messages))
        var release: CheckedContinuation<Void, Never>?
        repository.beforeMessageRead = { await withCheckedContinuation { release = $0 } }
        let store = ChatStore(participantID: groomer, role: .groomer, repository: repository)
        defer { release?.resume(); store.stopAllMessageSubscriptions() }
        await store.startMessageSubscription(for: conversation)
        let host = UIHostingController(rootView: ChatThreadView(participantID: groomer, role: .groomer,
            conversation: conversation, store: store, initialMessagesPrepared: true).environment(\.scenePhase, .active))
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.pushViewController(host, animated: false)
        let read = Task { await store.loadMessages(for: conversation) }
        for _ in 0..<200 where release == nil { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertNotNil(release)
        repository.beforeMessageRead = nil
        release?.resume(); release = nil
        await read.value
        try await assertLatestFromFirstContentFrame(host, phase: "cold")
        XCTAssertEqual(store.messages(for: conversation.id).count, messages.count)

        // A genuine departure/reentry with the same cached Store and a fresh navigation destination.
        let scroll = try XCTUnwrap(messageScroll(in: host.view))
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
        navigation.popViewController(animated: false)
        try await Task.sleep(for: .milliseconds(30))
        let reopened = UIHostingController(rootView: ChatConversationDestination(
            route: .conversation(conversation.id), role: .groomer, participantID: groomer,
            store: store).environment(\.scenePhase, .active))
        await store.loadConversations()
        navigation.pushViewController(reopened, animated: true)
        try await assertLatestFromFirstContentFrame(reopened, phase: "cached detail-route reopen")
        try await Task.sleep(for: .milliseconds(400))
        try await assertLatestFromFirstContentFrame(reopened, phase: "completed navigation")
    }

    func testUpdatingKeepsTheSameViewportAsActiveChat() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for (role, cached) in [(UserRole.customer, false), (.customer, true), (.groomer, false), (.groomer, true)] {
            let conversation = ChatConversation(id: UUID(), customerID: UUID(), groomerID: UUID(),
                createdAt: "2026-11-03T12:00:00Z", updatedAt: "2026-11-03T12:00:00Z")
            var messages = (0..<40).map { index in
                ChatMessage(id: UUID(), conversationID: conversation.id,
                    senderID: index % 3 == 0 ? conversation.customerID : conversation.groomerID, kind: .text,
                    body: index == 39 ? "OK" : String(repeating: "Message \(index): please use the side entrance. ", count: index % 4 + 1),
                    booking: nil, createdAt: String(format: "2026-11-03T12:00:%02dZ", index))
            }
            let booking = BookingsStoreTests.booking(customerID: conversation.customerID, groomerID: conversation.groomerID)
            messages.insert(ChatMessage(id: UUID(), conversationID: conversation.id, senderID: conversation.customerID,
                kind: .bookingCard, body: nil, booking: booking, createdAt: "2026-11-03T12:00:20.500Z"), at: 21)
            let participant = role == .customer ? conversation.customerID : conversation.groomerID
            let repository = ChatRepositoryFake(messagesResult: .success(messages))
            let store = ChatStore(participantID: participant, role: role, repository: repository,
                readStateCache: ChatReadStateCacheFake())
            if cached { await store.loadMessages(for: conversation) }
            var release: CheckedContinuation<Void, Never>?
            repository.beforeMessageEvents = { await withCheckedContinuation { release = $0 } }
            let host = UIHostingController(rootView: ChatThreadView(participantID: participant, role: role,
                conversation: conversation, store: store).environment(\.scenePhase, .active))
            let navigation = UINavigationController(rootViewController: host)
            navigation.setNavigationBarHidden(true, animated: false)
            window.rootViewController = navigation
            window.makeKeyAndVisible()
            for _ in 0..<100 where release == nil || !store.hasLoadedMessages(for: conversation.id) {
                try await Task.sleep(for: .milliseconds(5))
            }
            XCTAssertNotNil(release)
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded(); host.view.layoutIfNeeded()
            let scroll = try XCTUnwrap(messageScroll(in: host.view))
            let during = scroll.convert(scroll.bounds, to: window)
            print("UPDATING role=\(role) cached=\(cached) viewport=\(during) content=\(scroll.contentSize) offset=\(scroll.contentOffset) insets=\(scroll.adjustedContentInset)")
            let end = max(-scroll.adjustedContentInset.top,
                scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height)
            XCTAssertEqual(scroll.contentOffset.y, end, accuracy: 2, "Mixed-height history must already show its newest message")
            XCTAssertTrue(store.isLoadingMessages(for: conversation.id))
            XCTAssertEqual(scroll.contentOffset.x + scroll.adjustedContentInset.left, 0, accuracy: 1, "Updating must not shift a vertical conversation sideways")
            XCTAssertEqual(scroll.contentSize.width, scroll.bounds.width, accuracy: 1,
                "Mixed booking cards and text must use the viewport width")
            repository.beforeMessageEvents = nil
            release?.resume(); release = nil
            for _ in 0..<100 where store.isLoadingMessages(for: conversation.id) {
                try await Task.sleep(for: .milliseconds(5))
            }
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded(); host.view.layoutIfNeeded()
            let after = scroll.convert(scroll.bounds, to: window)
            print("ACTIVE role=\(role) cached=\(cached) viewport=\(after) content=\(scroll.contentSize) offset=\(scroll.contentOffset) insets=\(scroll.adjustedContentInset)")
            XCTAssertEqual(scroll.contentOffset.x + scroll.adjustedContentInset.left, 0, accuracy: 1, "Active chat must keep the same horizontal origin")
            XCTAssertEqual(during.minY, after.minY, accuracy: 1)
            XCTAssertEqual(during.height, after.height, accuracy: 1)
            XCTAssertGreaterThan(during.height, window.bounds.height * 0.5)
            XCTAssertGreaterThanOrEqual(during.minY, window.safeAreaInsets.top)
            XCTAssertLessThanOrEqual(during.maxY, window.bounds.height - window.safeAreaInsets.bottom)
            // A keyboard/safe-area change must not leave the latest row above or below
            // the viewport. Exercise the same layout resize without system keyboard timing.
            for bottomInset in [CGFloat(260), CGFloat(0)] {
                host.additionalSafeAreaInsets.bottom = bottomInset
                try await Task.sleep(for: .milliseconds(100))
                window.layoutIfNeeded(); host.view.layoutIfNeeded()
                let resizedEnd = max(-scroll.adjustedContentInset.top,
                    scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height)
                XCTAssertEqual(scroll.contentOffset.y, resizedEnd, accuracy: 2)
                XCTAssertEqual(scroll.contentOffset.x + scroll.adjustedContentInset.left, 0, accuracy: 1)
                XCTAssertEqual(scroll.contentSize.width, scroll.bounds.width, accuracy: 1)
            }
            store.stopAllMessageSubscriptions()
            window.rootViewController = nil
        }
    }

    private func assertLatestFromFirstContentFrame(_ host: UIViewController, phase: String) async throws {
        var foundContent = false
        for _ in 0..<120 {
            try await Task.sleep(for: .milliseconds(16))
            host.view.window?.layoutIfNeeded()
            host.parent?.view.layoutIfNeeded()
            host.view.layoutIfNeeded()
            guard let scroll = messageScroll(in: host.view), scroll.contentSize.height > scroll.bounds.height else { continue }
            let end = max(-scroll.adjustedContentInset.top,
                scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height)
            XCTAssertEqual(scroll.contentOffset.x + scroll.adjustedContentInset.left, 0, accuracy: 1, phase)
            XCTAssertEqual(scroll.contentSize.width, scroll.bounds.width, accuracy: 1, phase)
            XCTAssertEqual(scroll.contentOffset.y, end, accuracy: 2,
                "\(phase) must already be at latest; content=\(scroll.contentSize.height), viewport=\(scroll.bounds.height), insets=\(scroll.adjustedContentInset)")
            foundContent = true
            break
        }
        XCTAssertTrue(foundContent, "Expected a scrollable real chat thread")
    }

    private func messageScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.bounds.height > 150 { return scroll }
        return view.subviews.lazy.compactMap { self.messageScroll(in: $0) }.first
    }
}
