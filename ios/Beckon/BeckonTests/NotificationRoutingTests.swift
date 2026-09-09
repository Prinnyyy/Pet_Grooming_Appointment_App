import Foundation
import Testing
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class NotificationRoutingRenderingTests: XCTestCase {
    func testNotificationActionsRenderForBothRolesAtAccessibleSize() async throws {
        let owner = UUID()
        let date = "2026-09-08T12:00:00Z"
        let customerNotice = CustomerNotification(id: UUID(), customerID: owner, kind: .bookingCancelled,
            title: "Booking cancelled", body: "Your groomer cancelled this appointment.", isRead: false,
            createdAt: date, readAt: nil, relatedRequestID: nil, relatedBookingID: UUID(), relatedOfferID: nil)
        let customerStore = CustomerNotificationsStore(customerID: owner,
            repository: CustomerNotificationRepositoryFake(notificationsResult: .success([customerNotice])))
        let groomerNotice = GroomerNotification(id: UUID(), groomerID: owner, kind: .newMatch,
            title: "New request match", body: "A new grooming request is available.", isRead: false,
            createdAt: date, readAt: nil, relatedRequestID: UUID(), relatedBookingID: nil, relatedOfferID: nil)
        let groomerStore = GroomerNotificationsStore(groomerID: owner,
            repository: GroomerNotificationRepositoryFake(notificationsResult: .success([groomerNotice])))
        await customerStore.load()
        await groomerStore.load()
        let screens = [AnyView(CustomerNotificationsView(store: customerStore)), AnyView(GroomerNotificationsView(store: groomerStore))]
        for (index, screen) in screens.enumerated() {
            let host = UIHostingController(rootView: NavigationStack { screen.environment(\.dynamicTypeSize, .accessibility2) })
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(300))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "T-381 notification actions role \(index) accessibility2"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertEqual(image.size, window.bounds.size)
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
    }
}

struct NotificationRoutingTests {
    @Test(arguments: CustomerNotificationKind.allCases) @MainActor
    func customerKindsResolveExactCurrentTargetsWithoutAcknowledging(kind: CustomerNotificationKind) async throws {
        let owner = UUID()
        let request = CustomerRequestsStoreTests.request(customerID: owner, petID: UUID(), status: .cancelled)
        let offer = CustomerRequestsStoreTests.offerReview(customerID: owner, requestID: request.id, status: .withdrawnByGroomer)
        let booking = CustomerRequestsStoreTests.booking(requestID: request.id, customerID: owner, status: .cancelledByGroomer)
        let requests = CustomerRequestRepositoryFake()
        requests.exactRequestResult = .success(request)
        requests.exactOfferResult = .success(offer)
        let bookingRepository = BookingRepositoryFake(bookingsResult: .success([booking]))
        let requestStore = CustomerRequestsStore(customerID: owner, petRepository: CustomerRequestPetRepositoryFake(),
            requestRepository: DebugCustomerRequestRepository(base: requests, debugRecorder: nil), bookingRepository: bookingRepository)
        let bookings = BookingsStore(participantID: owner, role: .customer, repository: bookingRepository)
        let conversation = ChatConversation(id: UUID(), customerID: owner, groomerID: booking.groomerID,
            createdAt: booking.createdAt, updatedAt: booking.updatedAt)
        let chatRepository = ChatRepositoryFake()
        chatRepository.exactConversationResult = .success(conversation)
        let chat = ChatStore(participantID: owner, role: .customer, repository: chatRepository, bookingRepository: bookingRepository)
        let notification = CustomerNotification(id: UUID(), customerID: owner, kind: kind, title: "Notice", body: "Current target",
            isRead: false, createdAt: booking.createdAt, readAt: nil, relatedRequestID: request.id,
            relatedBookingID: booking.id, relatedOfferID: offer.id)
        let repository = CustomerNotificationRepositoryFake(notificationsResult: .success([notification]),
            markReadResult: .success(notification.replacingReadState(isRead: true, readAt: booking.updatedAt)))
        let store = CustomerNotificationsStore(customerID: owner, repository: repository)
        await store.load()
        let target = await store.resolveDestination(notification, requests: requestStore, bookings: bookings, chat: chat)
        switch kind {
        case .requestPublished, .requestCancelled: #expect(target == .request(request.id))
        case .newOffer: #expect(target == .offer(requestID: request.id, offerID: offer.id))
        case .bookingConfirmed, .bookingCancelled:
            #expect(target == .booking(booking.id))
            #expect(bookings.booking(withID: booking.id)?.status == .cancelledByGroomer)
        case .newMessage: #expect(target == .message(conversation))
        case .unknown: #expect(target == nil)
        }
        #expect(repository.markReadCallCount == (kind == .unknown ? 0 : 1))
        #expect(requests.acknowledgeBookingHandoffCallCount == 0)
        #expect(chatRepository.conversationsCallCount == 0)
        if kind != .unknown {
            requests.exactRequestResult = .failure(.requestNotFound)
            bookingRepository.bookingsResult = .success([])
            chatRepository.exactConversationResult = .failure(.conversationNotFound)
            #expect(await store.resolveDestination(notification, requests: requestStore, bookings: bookings, chat: chat) == nil)
            #expect(repository.markReadCallCount == 1)
        }
    }

    @Test(arguments: GroomerNotificationKind.allCases) @MainActor
    func groomerKindsResolveOutsidePagesAndFailClosed(kind: GroomerNotificationKind) async {
        let customer = UUID()
        let booking = CustomerRequestsStoreTests.booking(requestID: UUID(), customerID: customer, status: .cancelledByCustomer)
        let owner = booking.groomerID
        let item = GroomerRequestsStoreTests.matchedRequest(groomerID: owner)
        let requestRepository = GroomerRequestRepositoryFake()
        requestRepository.exactMatchResult = .success(item)
        let requests = GroomerRequestsStore(groomerID: owner,
            repository: DebugGroomerRequestRepository(base: requestRepository, debugRecorder: nil))
        let bookingRepository = BookingRepositoryFake(bookingsResult: .success([booking]))
        let bookings = BookingsStore(participantID: owner, role: .groomer, repository: bookingRepository)
        let conversation = ChatConversation(id: UUID(), customerID: customer, groomerID: owner,
            createdAt: booking.createdAt, updatedAt: booking.updatedAt)
        let chatRepository = ChatRepositoryFake()
        chatRepository.exactConversationResult = .success(conversation)
        let chat = ChatStore(participantID: owner, role: .groomer, repository: chatRepository, bookingRepository: bookingRepository)
        let notification = GroomerNotification(id: UUID(), groomerID: owner, kind: kind, title: "Notice", body: "Target",
            isRead: false, createdAt: booking.createdAt, readAt: nil, relatedRequestID: item.request.id,
            relatedBookingID: booking.id, relatedOfferID: nil)
        let repository = GroomerNotificationRepositoryFake(notificationsResult: .success([notification]),
            markReadResult: .success(notification.replacingReadState(isRead: true, readAt: booking.updatedAt)))
        let store = GroomerNotificationsStore(groomerID: owner, repository: repository)
        await store.load()
        let target = await store.resolveDestination(notification, requests: requests, bookings: bookings, chat: chat)
        switch kind {
        case .newMatch: #expect(target == .request(item.id))
        case .offerAccepted, .bookingCancelledByCustomer: #expect(target == .booking(booking.id))
        case .newMessage: #expect(target == .message(conversation))
        case .unknown: #expect(target == nil)
        }
        #expect(repository.markReadCallCount == (kind == .unknown ? 0 : 1))
        #expect(requestRepository.matchedRequestsCallCount == 0)
        let foreignStore = GroomerNotificationsStore(groomerID: UUID(), repository: repository)
        #expect(await foreignStore.resolveDestination(notification, requests: requests, bookings: bookings, chat: chat) == nil)
        #expect(repository.markReadCallCount == (kind == .unknown ? 0 : 1))
    }
}
