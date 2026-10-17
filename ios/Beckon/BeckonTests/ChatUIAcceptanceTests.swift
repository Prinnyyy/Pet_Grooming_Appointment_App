import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class ChatUIAcceptanceTests: XCTestCase {
    func testLocalChatJourney() async throws {
        guard ProcessInfo.processInfo.environment["TEST_RUNNER_BECKON_CHAT_AUDIT"] == "1"
                || ProcessInfo.processInfo.environment["BECKON_CHAT_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in local chat/notification audit")
        }
        let session = AuditSession()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let visible = scene.windows.filter { !$0.isHidden }
        visible.forEach { $0.isHidden = true }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: AuditHost(session: session))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            visible.forEach { $0.isHidden = false }
            previous?.makeKey()
        }
        for _ in 0..<2400 where !session.finished { try await Task.sleep(for: .milliseconds(500)) }
        XCTAssertTrue(session.finished, "Finish the local audit before timeout")
    }

    @Observable @MainActor final class AuditSession { var finished = false }

    struct AuditHost: View {
        let session: AuditSession
        @State private var role: UserRole = .customer
        @State private var screen = "Messages"
        @State private var largeText = false
        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Menu("Audit Controls") {
                        Picker("Role", selection: $role) {
                            Text("Customer").tag(UserRole.customer)
                            Text("Groomer").tag(UserRole.groomer)
                        }
                        Picker("Screen", selection: $screen) {
                            ForEach(["Messages", "Notifications", "Booking", "Load Failure", "Live Failure", "Cancelled Send", "Failed Send", "Slow Send"], id: \.self) { Text($0) }
                        }
                        Toggle("Large Text", isOn: $largeText)
                    }
                    Spacer()
                    Button("Finish Audit") { session.finished = true }
                }
                .font(.caption).padding(8).dynamicTypeSize(.large)
                Journey(role: role, screen: screen)
                    .id("\(role.rawValue)-\(screen)")
                    .environment(\.scenePhase, .active)
                    .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large)
            }
        }
    }

    struct Journey: View {
        let role: UserRole
        let screen: String
        @State private var fixture: Fixture?
        @State private var focusedBookingID: UUID?
        @State private var showMessages = false
        @State private var feedback = BeckonFeedbackCenter()

        var body: some View {
            VStack(spacing: 0) {
                if let fixture {
                    if screen == "Load Failure" || screen == "Live Failure" || screen == "Failed Send" {
                        Button("Restore Local Connection") { fixture.restore() }.font(.caption)
                    }
                    NavigationStack {
                        Group {
                            if screen == "Notifications", role == .customer {
                                CustomerNotificationsView(store: fixture.customerNotifications, bookingStore: fixture.bookings, chatStore: fixture.chat)
                            } else if screen == "Notifications" {
                                GroomerNotificationsView(store: fixture.groomerNotifications, bookingStore: fixture.bookings, chatStore: fixture.chat)
                            } else if screen == "Booking", !showMessages {
                                BookingDetailView(bookingID: fixture.booking.id, role: role, store: fixture.bookings)
                            } else {
                                ChatConversationsView(participantID: fixture.owner, role: role, repository: fixture.repository,
                                    bookingRepository: fixture.bookingRepository, store: fixture.chat, focusedBookingID: $focusedBookingID)
                            }
                        }
                    }
                    .environment(\.openBookingChat, { booking in focusedBookingID = booking.id; showMessages = true })
                    .environment(\.beckonFeedbackCenter, feedback)
                    .overlay(alignment: .bottom) { BeckonGlobalFeedbackOverlay(center: feedback) }
                } else { ProgressView() }
            }
            .task { fixture = try? Fixture(role: role, screen: screen) }
        }
    }

    @MainActor final class Fixture {
        let owner: UUID
        let booking: Booking
        let repository = ChatRepositoryFake()
        let bookingRepository: BookingRepositoryFake
        let chat: ChatStore
        let bookings: BookingsStore
        let customerNotifications: CustomerNotificationsStore
        let groomerNotifications: GroomerNotificationsStore
        let conversation: ChatConversation
        let initialMessages: [ChatMessage]

        init(role: UserRole, screen: String) throws {
            booking = try BookingRescheduleTests.booking()
            owner = role == .customer ? booking.customerID : booking.groomerID
            let date = "2026-10-04T12:00:00Z"
            conversation = ChatConversation(id: UUID(), customerID: booking.customerID, groomerID: booking.groomerID,
                latestBookingID: booking.id, bookingStatus: .confirmed,
                groomerBusinessName: "Willow & Wash Gentle Mobile Grooming Studio",
                latestMessageSenderID: role == .customer ? booking.groomerID : booking.customerID,
                latestMessageCreatedAt: date, latestMessageBody: "Please use the side entrance. The gate will be open.",
                createdAt: date, updatedAt: date)
            initialMessages = [ChatMessage(id: UUID(), conversationID: conversation.id, senderID: owner,
                kind: .bookingCard, body: nil, booking: booking, createdAt: "2026-10-04T11:59:00Z"),
                ChatMessage(id: UUID(), conversationID: conversation.id, senderID: conversation.latestMessageSenderID!,
                    kind: .text, body: conversation.latestMessageBody, booking: nil, createdAt: date)]
            bookingRepository = BookingRepositoryFake(bookingsResult: .success([booking]))
            chat = ChatStore(participantID: owner, role: role, repository: repository,
                bookingRepository: bookingRepository, readStateCache: ChatReadStateCacheFake())
            bookings = BookingsStore(participantID: owner, role: role, repository: bookingRepository,
                initialBookings: [booking], appointmentReminderScheduler: AppointmentReminderSchedulerFake())
            let notice = CustomerNotification(id: UUID(), customerID: booking.customerID, kind: .newMessage,
                title: "New message", body: "Your groomer sent you arrival details.", isRead: false, createdAt: date,
                readAt: nil, relatedRequestID: nil, relatedBookingID: nil, relatedOfferID: nil, relatedConversationID: conversation.id)
            let stale = CustomerNotification(id: UUID(), customerID: booking.customerID, kind: .newMessage,
                title: "Unavailable conversation", body: "An older message notification.", isRead: false, createdAt: date,
                readAt: nil, relatedRequestID: nil, relatedBookingID: nil, relatedOfferID: nil, relatedConversationID: UUID())
            let customerNotices = CustomerNotificationRepositoryFake(notificationsResult: .success([notice, stale]),
                markReadResult: .success(notice.replacingReadState(isRead: true, readAt: date)))
            customerNotices.persistsReadUpdates = true
            customerNotifications = CustomerNotificationsStore(customerID: booking.customerID, repository: customerNotices)
            let groomerNotice = GroomerNotification(id: UUID(), groomerID: booking.groomerID, kind: .newMessage,
                title: "New message", body: "Your customer sent you arrival details.", isRead: false, createdAt: date,
                readAt: nil, relatedRequestID: nil, relatedBookingID: nil, relatedOfferID: nil, relatedConversationID: conversation.id)
            let groomerStale = GroomerNotification(id: UUID(), groomerID: booking.groomerID, kind: .newMessage,
                title: "Unavailable conversation", body: "An older message notification.", isRead: false, createdAt: date,
                readAt: nil, relatedRequestID: nil, relatedBookingID: nil, relatedOfferID: nil, relatedConversationID: UUID())
            let groomerNotices = GroomerNotificationRepositoryFake(notificationsResult: .success([groomerNotice, groomerStale]),
                markReadResult: .success(groomerNotice.replacingReadState(isRead: true, readAt: date)))
            groomerNotices.persistsReadUpdates = true
            groomerNotifications = GroomerNotificationsStore(groomerID: booking.groomerID, repository: groomerNotices)
            repository.conversationsResult = .success([conversation])
            repository.exactConversationResult = .success(conversation)
            let target = conversation
            repository.exactConversationRead = { id in
                guard id == target.id else { throw ChatRepositoryError.conversationNotFound }
                return target
            }
            restore()
            if screen == "Load Failure" { repository.messagesResult = .failure(.networkUnavailable) }
            if screen == "Live Failure" { repository.messageEventsResult = .failure(.networkUnavailable) }
            if screen == "Cancelled Send" {
                repository.beforeSend = nil
                repository.sendResult = .failure(.cancelled)
            }
            if screen == "Failed Send" {
                repository.beforeSend = nil
                repository.sendResult = .failure(.networkUnavailable)
            }
            if screen == "Slow Send" {
                let send = repository.beforeSend
                repository.beforeSend = { try? await Task.sleep(for: .seconds(8)); await send?() }
            }
        }

        func restore() {
            repository.messagesResult = .success(initialMessages)
            repository.messageEventsResult = .success(())
            repository.beforeSend = { [weak self] in
                guard let self else { return }
                self.repository.sendResult = .success(ChatMessage(id: UUID(), conversationID: self.conversation.id,
                    senderID: self.owner, kind: .text, body: self.repository.lastBody, booking: nil,
                    createdAt: GroomingRequestDateFormatting.serverString(from: Date())))
            }
        }
    }
}
