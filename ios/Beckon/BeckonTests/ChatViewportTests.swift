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
        let reopened = UIHostingController(rootView: ChatThreadView(participantID: groomer, role: .groomer,
            conversation: conversation, store: store, initialMessagesPrepared: true).environment(\.scenePhase, .active))
        navigation.pushViewController(reopened, animated: false)
        try await assertLatestFromFirstContentFrame(reopened, phase: "cached reopen")
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
