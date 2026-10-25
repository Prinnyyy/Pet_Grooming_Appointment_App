#if DEBUG
import Foundation

@MainActor
final class CustomerSandboxAccount: AuthSessionRepository, ProfileRepository, CustomerProfileRepository, ProfileSnapshotCaching {
    let boundary: CustomerSandboxBoundary
    var session: AuthSessionSnapshot? = .init(userID: CustomerSandboxFixtures.customerID, email: "lian@example.test")
    var details: CustomerProfileDetails
    var snapshotValue: ProfileSnapshot?
    var avatar: Data?

    init(state: CustomerSandboxState, boundary: CustomerSandboxBoundary) {
        self.boundary = boundary
        details = .init(userID: CustomerSandboxFixtures.customerID,
            nickname: state == .longNames ? "Lian Alexandria Montgomery-Sutherland" : "Lian",
            avatarPath: state == .photos ? "sandbox/avatar" : nil, streetAddress: "123 Preview Street",
            city: "Los Angeles", stateCode: .california, zipCode: "90012",
            contactEmail: "lian@example.test", phoneNumber: "2025550148")
        if state == .photos { avatar = CustomerSandboxFixtures.imageData }
    }
    func currentSession() -> AuthSessionSnapshot? { session }
    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws -> AuthSessionSnapshot {
        try await boundary.check()
        let value = AuthSessionSnapshot(userID: CustomerSandboxFixtures.customerID, email: email)
        session = value; return value
    }
    func signUp(email: String, password: String, redirectTo: URL?) async throws -> AuthSignUpOutcome {
        try await boundary.check(); return .confirmationRequired(email: email)
    }
    func handleAuthCallback(_ url: URL) async throws -> AuthSessionSnapshot { try await signIn(email: "lian@example.test", password: "") }
    func signOut() async throws { try await boundary.check(); session = nil }
    func deleteAccount() async throws { try await signOut() }
    func requestPasswordRecovery(email: String, redirectTo: URL) async throws { try await boundary.check() }
    func recoverySession() -> AuthSessionSnapshot? { session }
    func handleRecoveryCallback(_ url: URL) async throws -> AuthSessionSnapshot { try await handleAuthCallback(url) }
    func updateRecoveredPassword(_ password: String, userID: UUID) async throws { try await boundary.check() }
    func endPasswordRecovery() async throws { try await boundary.check() }
    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        try await boundary.check(); return .init(userID: userID, role: .customer, displayName: details.nickname)
    }
    func createProfile(role: UserRole, displayName: String) async throws -> MarketplaceProfile {
        try await boundary.check(); details.nickname = displayName
        return .init(userID: CustomerSandboxFixtures.customerID, role: .customer, displayName: displayName)
    }
    func profile(customerID: UUID) async throws -> CustomerProfileDetails { try await boundary.check(); return details }
    func updateProfile(customerID: UUID, draft: CustomerProfileDraft) async throws -> CustomerProfileDetails {
        try await boundary.check()
        details.nickname = draft.nickname; details.streetAddress = draft.streetAddress; details.addressLine2 = draft.addressLine2
        details.city = draft.city; details.stateCode = draft.stateCode; details.zipCode = draft.zipCode
        details.contactEmail = draft.contactEmail; details.phoneNumber = draft.phoneNumber
        return details
    }
    func updateProfile(customerID: UUID, draft: CustomerProfileDraft, confirmedAddress: BeckonConfirmedAddress?) async throws -> CustomerProfileDetails {
        _ = try await updateProfile(customerID: customerID, draft: draft)
        details.confirmedAddress = confirmedAddress; return details
    }
    func uploadAvatarPhoto(customerID: UUID, data: Data, contentType: CustomerAvatarPhotoContentType) async throws -> String {
        try await boundary.check(); avatar = data; details.avatarPath = "sandbox/avatar"; return "sandbox/avatar"
    }
    func avatarPhotoData(storagePath: String) async throws -> Data { try await boundary.check(); return avatar ?? CustomerSandboxFixtures.imageData }
    func latestAvatarPhotoPath(customerID: UUID) async throws -> String? { try await boundary.check(); return details.avatarPath }
    func snapshot(userID: UUID) -> ProfileSnapshot? { snapshotValue }
    func save(_ snapshot: ProfileSnapshot) { snapshotValue = snapshot }
    func remove(userID: UUID) { snapshotValue = nil }
}

@MainActor
final class CustomerSandboxChat: ChatRepository {
    let boundary: CustomerSandboxBoundary
    let conversationFixture: ChatConversation
    var conversationItems: [ChatConversation]
    var messageItems: [ChatMessage]
    private var streams: [UUID: AsyncStream<ChatMessage>.Continuation] = [:]

    init(state: CustomerSandboxState, boundary: CustomerSandboxBoundary, booking: Booking) {
        self.boundary = boundary
        let now = Date().ISO8601Format()
        conversationFixture = .init(id: CustomerSandboxFixtures.conversationID, customerID: booking.customerID,
            groomerID: booking.groomerID, latestBookingID: booking.id, latestRequestID: booking.requestID,
            scheduledStart: booking.scheduledStart, scheduledEnd: booking.scheduledEnd, priceEstimate: booking.priceEstimate,
            bookingStatus: booking.status, completedAt: booking.completedAt, groomerBusinessName: booking.groomerBusinessName,
            counterpartAvatarPhotoData: state == .photos ? CustomerSandboxFixtures.imageData : nil,
            latestMessageSenderID: booking.groomerID, latestMessageCreatedAt: now,
            latestMessageBody: "Would Mochi prefer a quiet morning appointment?", createdAt: now, updatedAt: now,
            serviceTimeZoneIdentifier: CustomerSandboxFixtures.zone)
        conversationItems = state == .empty ? [] : [conversationFixture]
        messageItems = state == .empty ? [] : [
            .init(id: CustomerSandboxFixtures.id(41), conversationID: conversationFixture.id,
                senderID: booking.customerID, kind: .text, body: "Please take extra care around the paws.", booking: nil, createdAt: now),
            .init(id: CustomerSandboxFixtures.id(42), conversationID: conversationFixture.id,
                senderID: booking.groomerID, kind: .text, body: "Of course. We can take breaks and keep the dryer low.", booking: nil, createdAt: now),
            .init(id: CustomerSandboxFixtures.id(43), conversationID: conversationFixture.id,
                senderID: booking.groomerID, kind: .bookingCard, body: nil, booking: booking, createdAt: now),
        ]
    }
    func conversations(participantID: UUID, role: UserRole) async throws -> [ChatConversation] {
        try await boundary.check(); return conversationItems
    }
    func conversation(id: UUID, participantID: UUID, role: UserRole) async throws -> ChatConversation {
        try await boundary.check(); return conversationFixture
    }
    func conversation(customerID: UUID, groomerID: UUID, role: UserRole) async throws -> ChatConversation {
        try await boundary.check(); return conversationFixture
    }
    func messages(conversationID: UUID) async throws -> [ChatMessage] { try await boundary.check(); return messageItems }
    func sendMessage(conversationID: UUID, senderID: UUID, body: String) async throws -> ChatMessage {
        try await boundary.check()
        let message = ChatMessage(id: UUID(), conversationID: conversationID, senderID: senderID,
            kind: .text, body: body, booking: nil, createdAt: Date().ISO8601Format())
        messageItems.append(message)
        streams.values.forEach { $0.yield(message) }
        return message
    }
    func messageEvents(conversationID: UUID) async throws -> AsyncStream<ChatMessage> {
        try await boundary.check()
        let token = UUID()
        return AsyncStream { continuation in
            streams[token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.streams[token] = nil }
            }
        }
    }
    func stop() { streams.values.forEach { $0.finish() }; streams = [:] }
}

@MainActor
final class CustomerSandboxNotifications: CustomerNotificationRepository {
    let boundary: CustomerSandboxBoundary
    var items: [CustomerNotification]
    init(state: CustomerSandboxState, boundary: CustomerSandboxBoundary) {
        self.boundary = boundary
        items = state == .empty ? [] : [
            .init(id: CustomerSandboxFixtures.id(300), customerID: CustomerSandboxFixtures.customerID,
                kind: .requestPublished, title: "Your grooming request is live",
                body: "View groomers and compare offers for \(state == .longNames ? CustomerSandboxFixtures.longName : "Mochi").",
                isRead: state == .allRead, createdAt: Date().ISO8601Format(), readAt: nil,
                relatedRequestID: CustomerSandboxFixtures.requestID, relatedBookingID: nil, relatedOfferID: nil),
            .init(id: CustomerSandboxFixtures.id(301), customerID: CustomerSandboxFixtures.customerID,
                kind: .bookingConfirmed, title: "Your appointment is confirmed", body: "View the details of your next appointment.",
                isRead: state == .allRead, createdAt: Date().ISO8601Format(), readAt: nil,
                relatedRequestID: CustomerSandboxFixtures.id(21), relatedBookingID: CustomerSandboxFixtures.bookingID, relatedOfferID: nil),
        ]
    }
    func notifications(customerID: UUID) async throws -> [CustomerNotification] { try await boundary.check(); return items }
    func markRead(notificationID: UUID) async throws -> CustomerNotification {
        try await boundary.check()
        guard let index = items.firstIndex(where: { $0.id == notificationID }) else { throw CustomerNotificationRepositoryError.notificationNotFound }
        items[index] = items[index].replacingReadState(isRead: true, readAt: Date().ISO8601Format()); return items[index]
    }
    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        try await boundary.check(); items = items.map { $0.replacingReadState(isRead: true, readAt: Date().ISO8601Format()) }; return items
    }
}

#endif
