import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class UIColorImplementationSnapshotTests: XCTestCase {
    func testAuthenticationLanding() async throws {
        for largeText in [false, true] {
            try await capture(AuthenticationView(store: AuthenticationStore(repository: AuthSessionRepositoryFake())),
                name: "authentication-landing", largeText: largeText, captureAllContent: true)
        }
    }

    func testGroomerAndSharedSurfaces() async throws {
        let groomer = GroomerUIFixture()
        for largeText in [false, true] {
            try await capture(NavigationStack {
                GroomerRequestsView(groomerID: groomer.owner, repository: groomer.requests,
                    profileRepository: groomer.profile, route: .constant(.matches))
            }.tint(DesignTokens.Colors.groomerDeep), name: "groomer-requests", largeText: largeText,
                captureAllContent: true)
            try await capture(NavigationStack {
                GroomerProfileManagementView(groomerID: groomer.owner, repository: groomer.profile, onSignOut: {})
            }.tint(DesignTokens.Colors.groomerDeep), name: "groomer-account", largeText: largeText,
                captureAllContent: true)
            for role in [UserRole.customer, .groomer] {
                let conversation = try groomer.chat.conversationsResult.get()[0]
                let participant = role == .customer ? conversation.customerID : conversation.groomerID
                groomer.chat.messagesResult = .success([
                    ChatMessage(id: UUID(), conversationID: conversation.id, senderID: conversation.customerID,
                        kind: .text, body: "Please use the side entrance. Mochi needs a quiet introduction.",
                        booking: nil, createdAt: conversation.createdAt),
                    ChatMessage(id: UUID(), conversationID: conversation.id, senderID: conversation.groomerID,
                        kind: .text, body: "Of course. I will message when I arrive.",
                        booking: nil, createdAt: conversation.createdAt),
                ])
                let store = ChatStore(participantID: participant, role: role, repository: groomer.chat)
                await store.loadMessages(for: conversation)
                XCTAssertEqual(store.messages(for: conversation.id).count, 2)
                try await capture(NavigationStack {
                    ChatThreadView(participantID: participant, role: role, conversation: conversation, store: store)
                }.tint(role == .customer ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.groomerDeep),
                    name: "\(role.rawValue)-messages", largeText: largeText)
                XCTAssertEqual(store.messages(for: conversation.id).count, 2)
                store.stopAllMessageSubscriptions()
            }
        }
        XCTAssertEqual(groomer.profile.updateProfileCallCount, 0)
        XCTAssertEqual(groomer.chat.sendCallCount, 0)
    }

    func testSummaryAndActionGeometryAtDefaultAndAX3() async throws {
        let request = CustomerRequestsStoreTests.request(customerID: UUID(), petID: UUID(), status: .hasOffers)
        for size: DynamicTypeSize in [.large, .accessibility3] {
            let card = UIHostingController(rootView: GroomingCard(content: .request(.init(request: request, handoff: nil, loadedOfferCount: 3), reach: nil), style: .glance, onOpen: {})
                .environment(\.dynamicTypeSize, size))
            let measured = card.sizeThatFits(in: CGSize(width: 320, height: 10_000))
            XCTAssertLessThanOrEqual(measured.width, 320)
            XCTAssertGreaterThanOrEqual(measured.height, 44)
            let actions = [AnyView(Button("Manage availability") {}.buttonStyle(BeckonTertiaryButtonStyle(accent: .groomer))),
                AnyView(Button("Sign out") {}.buttonStyle(BeckonDestructiveButtonStyle()))]
            for action in actions {
                let host = UIHostingController(rootView: action.environment(\.dynamicTypeSize, size))
                let frame = host.sizeThatFits(in: CGSize(width: 320, height: 10_000))
                XCTAssertGreaterThanOrEqual(frame.height, 44)
                XCTAssertLessThanOrEqual(frame.width, 320)
            }
        }
    }

    func testCustomerRequestStates() async throws {
        let fixture = try await CustomerBookingUIFixture(screen: "booking")
        var cards: [CustomerRequestActionCardItem] = []
        for status: GroomingRequestStatus in [.open, .hasOffers, .booked, .cancelled, .expired, .unknown] {
            var request = CustomerRequestsStoreTests.request(customerID: fixture.request.customerID,
                petID: UUID(), status: status, preferredStart: fixture.request.preferredStart,
                preferredEnd: fixture.request.preferredEnd)
            request.preferenceTimeZoneIdentifier = "America/Los_Angeles"
            cards.append(.init(request: request, handoff: nil))
            if status == .hasOffers { cards.append(.init(request: request, handoff: nil, loadedOfferCount: 3)) }
        }
        cards.append(.init(request: fixture.request, handoff: .init(request: fixture.request, booking: fixture.booking)))
        for largeText in [false, true] {
            try await capture(ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        GroomingCard(content: .entry(card.handoff.map { .booking($0.booking, handoff: $0, avatar: nil) } ?? .request(card)), style: .glance, onOpen: {})
                    }
                }.beckonPageInsets()
            }.background(DesignTokens.Colors.appBackground), name: "customer-request-states",
                largeText: largeText, captureAllContent: true)
            try await capture(CustomerTabView(customerID: UUID(), customerDisplayName: "Alexandra",
                petRepository: CustomerRequestPetRepositoryFake(), requestRepository: CustomerRequestRepositoryFake(),
                notificationRepository: CustomerNotificationRepositoryFake(), bookingRepository: BookingRepositoryFake()),
                name: "customer-home-empty", largeText: largeText, captureAllContent: true)
        }
    }

    func testRoleStatusScreens() async throws {
        let customer = try await CustomerBookingUIFixture(screen: "offers")
        let groomer = GroomerUIFixture()
        for role in [UserRole.customer, .groomer] {
            try await capture(NavigationStack {
                BookingDetailView(bookingID: customer.booking.id, role: role, store: customer.bookings)
            }.tint(role == .customer ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.groomerDeep),
                name: "\(role.rawValue)-booking-status", largeText: false)
        }
        try await capture(NavigationStack {
            CustomerRequestOffersView(requestID: customer.request.id, store: customer.requests)
        }.tint(DesignTokens.Colors.customerDeep), name: "customer-offers-status", largeText: false)
        try await capture(NavigationStack {
            GroomingDetailView(target: .request(customer.request.id), requestStore: customer.requests, bookingsStore: customer.bookings)
        }.tint(DesignTokens.Colors.customerDeep), name: "customer-request-status", largeText: false)
        try await capture(NavigationStack {
            GroomerRequestsView(groomerID: groomer.owner, repository: groomer.requests,
                profileRepository: groomer.profile, route: .constant(.offers))
        }.tint(DesignTokens.Colors.groomerDeep), name: "groomer-offers-status", largeText: false)
        try await capture(NavigationStack {
            GroomerRequestsView(groomerID: groomer.owner, repository: groomer.requests,
                profileRepository: groomer.profile, route: .constant(.matches))
        }.tint(DesignTokens.Colors.groomerDeep), name: "groomer-requests-status", largeText: false)
    }

    func testColorCatalog() async throws {
        for largeText in [false, true] {
            try await capture(
                ScrollView { BeckonColorActionCatalog().beckonPageInsets() }
                    .background(DesignTokens.Colors.appBackground),
                name: "color-catalog", largeText: largeText, captureAllContent: true
            )
        }
    }

    func testWizardActions() async throws {
        let owner = UUID()
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([CustomerRequestsStoreTests.pet(customerID: owner)])),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        for largeText in [false, true] {
            try await capture(NavigationStack { CustomerRequestWizardView(store: store) },
                name: "wizard-actions", largeText: largeText)
        }
    }

    func testRoleHomes() async throws {
        let customer = try await CustomerBookingUIFixture(screen: "booking")
        let pet = CustomerRequestsStoreTests.pet(customerID: customer.request.customerID)
        for largeText in [false, true] {
            try await capture(CustomerTabView(
                customerID: customer.request.customerID,
                customerDisplayName: "Alexandra",
                petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
                requestRepository: customer.requestRepository,
                notificationRepository: CustomerNotificationRepositoryFake(),
                bookingRepository: customer.bookingRepository
            ), name: "customer-home", largeText: largeText, captureAllContent: true)
            let groomer = GroomerUIFixture()
            try await capture(GroomerTabView(
                groomerID: groomer.owner, groomerDisplayName: "Alexandra Wellington",
                profileRepository: groomer.profile, requestRepository: groomer.requests,
                notificationRepository: groomer.notifications, bookingRepository: groomer.bookings,
                chatRepository: groomer.chat, onSignOut: {}
            ), name: "groomer-home", largeText: largeText, captureAllContent: true)
            XCTAssertEqual(groomer.requests.createOfferCallCount, 0)
            XCTAssertEqual(groomer.profile.saveAvailabilityCallCount, 0)
        }
    }

    private func capture<Content: View>(
        _ content: Content, name: String, largeText: Bool, captureAllContent: Bool = false
    ) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let visible = scene.windows.filter { !$0.isHidden }
        visible.forEach { $0.isHidden = true }
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView: content
            .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            visible.forEach { $0.isHidden = false }
            previous?.makeKey()
        }
        try await Task.sleep(for: .milliseconds(600))
        window.layoutIfNeeded()
        XCTAssertGreaterThan(window.bounds.width, 300)
        func attach(_ suffix: String) {
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "UI-color-\(name)-\(largeText ? "AX3" : "default")\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        attach("")
        if captureAllContent {
            func scrolls(_ view: UIView) -> [UIScrollView] {
                (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrolls)
            }
            if let scroll = scrolls(window).first(where: { $0.contentSize.height > $0.bounds.height }) {
                let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
                var page = 1
                while scroll.contentOffset.y < bottom - 1 {
                    scroll.setContentOffset(CGPoint(x: 0, y: min(bottom, scroll.contentOffset.y + scroll.bounds.height * 0.8)), animated: false)
                    try await Task.sleep(for: .milliseconds(100))
                    attach("-page\(page)")
                    page += 1
                }
            }
        }
    }
}
