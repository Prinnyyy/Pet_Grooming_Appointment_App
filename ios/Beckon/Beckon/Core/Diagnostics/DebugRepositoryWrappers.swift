import Foundation

extension UserRole {
    var appDebugScopePrefix: String {
        switch self {
        case .customer:
            "customer"
        case .groomer:
            "groomer"
        }
    }

    var appDebugName: String {
        switch self {
        case .customer:
            "customer"
        case .groomer:
            "groomer"
        }
    }
}

@MainActor
private func debugRepositoryCall<T>(
    recorder: AppDebugEventRecorder?,
    source: String,
    scope: String,
    operation: String,
    metadata: [String: String] = [:],
    body: () async throws -> T
) async throws -> T {
    let startedAt = Date()
    do {
        return try await body()
    } catch {
        let isCancellation = AppDebugErrorClassifier.isCancellation(error)
            || AppDebugRepositoryCancellation.isCancelled(error)
        var eventMetadata = metadata
        eventMetadata["operation"] = operation
        recorder?.record(
            level: isCancellation ? .info : .error,
            category: .repository,
            source: source,
            scope: scope,
            message: isCancellation ? "cancelled" : "repository failure",
            underlyingError: error,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            metadata: eventMetadata
        )
        throw error
    }
}

private enum AppDebugRepositoryCancellation {
    static func isCancelled(_ error: any Error) -> Bool {
        switch error {
        case BookingRepositoryError.cancelled,
             CustomerRequestRepositoryError.cancelled,
             CustomerNotificationRepositoryError.cancelled,
             CustomerPushNotificationRepositoryError.cancelled,
             CustomerProfileRepositoryError.cancelled,
             CustomerPetRepositoryError.cancelled,
             ChatRepositoryError.cancelled,
             GroomerProfileRepositoryError.cancelled,
             GroomerNotificationRepositoryError.cancelled,
             GroomerRequestRepositoryError.cancelled:
            true
        default:
            false
        }
    }
}

@MainActor
final class DebugBookingRepository: BookingRepository {
    private let base: any BookingRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any BookingRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        try await bookings(participantID: participantID, role: role, page: .first).items
    }

    func bookings(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<Booking> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.bookings",
            scope: "\(role.appDebugScopePrefix).bookings",
            operation: "bookings",
            metadata: [
                "participantID": participantID.uuidString,
                "role": role.appDebugName,
                "table": "bookings",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.bookings(participantID: participantID, role: role, page: page)
        }
    }

    func offerAcceptance(offerID: UUID) async throws -> AcceptGroomerOfferResult? {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.offerAcceptance",
            scope: "customer.requests",
            operation: "offerAcceptance",
            metadata: ["offerID": offerID.uuidString, "rpc": "get_offer_acceptance"]
        ) {
            try await base.offerAcceptance(offerID: offerID)
        }
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.acceptOffer",
            scope: "customer.requests",
            operation: "acceptOffer",
            metadata: ["offerID": offerID.uuidString, "rpc": "accept_groomer_offer"]
        ) {
            try await base.acceptOffer(offerID: offerID)
        }
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.cancelBooking",
            scope: "booking.operation",
            operation: "cancelBooking",
            metadata: ["bookingID": bookingID.uuidString, "rpc": "cancel_booking"]
        ) {
            try await base.cancelBooking(bookingID: bookingID)
        }
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.completeBooking",
            scope: "groomer.bookings",
            operation: "completeBooking",
            metadata: ["bookingID": bookingID.uuidString, "rpc": "complete_booking"]
        ) {
            try await base.completeBooking(bookingID: bookingID)
        }
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "BookingRepository.createReview",
            scope: "customer.bookings",
            operation: "createReview",
            metadata: ["bookingID": bookingID.uuidString, "rpc": "create_review"]
        ) {
            try await base.createReview(bookingID: bookingID, draft: draft)
        }
    }
}

@MainActor
final class DebugCustomerRequestRepository: CustomerRequestRepository {
    private let base: any CustomerRequestRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any CustomerRequestRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        try await requests(customerID: customerID, page: .first).items
    }

    func requests(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerGroomingRequest> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.requests",
            scope: "customer.requests",
            operation: "requests",
            metadata: [
                "customerID": customerID.uuidString,
                "table": "grooming_requests",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.requests(customerID: customerID, page: page)
        }
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        try await offers(customerID: customerID, requestID: requestID, page: .first).items
    }

    func offers(
        customerID: UUID,
        requestID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerOfferReview> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.offers",
            scope: "customer.requests",
            operation: "offers",
            metadata: [
                "customerID": customerID.uuidString,
                "requestID": requestID.uuidString,
                "table": "groomer_offers",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.offers(customerID: customerID, requestID: requestID, page: page)
        }
    }

    func requestPhotos(
        customerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.requestPhotos",
            scope: "customer.requests",
            operation: "requestPhotos",
            metadata: [
                "customerID": customerID.uuidString,
                "requestCount": "\(requestIDs.count)",
                "table": "request_photos",
            ]
        ) {
            try await base.requestPhotos(customerID: customerID, requestIDs: requestIDs)
        }
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.requestPhotoData",
            scope: "customer.requests",
            operation: "requestPhotoData",
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "request-photos",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.requestPhotoData(photo)
        }
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.createRequest",
            scope: "customer.requests",
            operation: "createRequest",
            metadata: ["customerID": customerID.uuidString, "rpc": "create_grooming_request_v3"]
        ) {
            try await base.createRequest(customerID: customerID, draft: draft)
        }
    }

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.uploadRequestPhoto",
            scope: "customer.requests",
            operation: "uploadRequestPhoto",
            metadata: [
                "customerID": customerID.uuidString,
                "requestID": requestID.uuidString,
                "bucket": "request-photos",
                "contentType": contentType.rawValue,
            ]
        ) {
            try await base.uploadRequestPhoto(
                customerID: customerID,
                requestID: requestID,
                data: data,
                contentType: contentType,
                caption: caption
            )
        }
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.cancelRequest",
            scope: "customer.requests",
            operation: "cancelRequest",
            metadata: ["requestID": requestID.uuidString, "rpc": "cancel_grooming_request"]
        ) {
            try await base.cancelRequest(requestID: requestID)
        }
    }

    func acknowledgedBookingHandoffRequestIDs(
        customerID: UUID
    ) async throws -> Set<UUID> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.acknowledgedBookingHandoffRequestIDs",
            scope: "customer.requests",
            operation: "acknowledgedBookingHandoffRequestIDs",
            metadata: [
                "customerID": customerID.uuidString,
                "rpc": "get_acknowledged_booking_handoff_request_ids",
            ]
        ) {
            try await base.acknowledgedBookingHandoffRequestIDs(customerID: customerID)
        }
    }

    func acknowledgeBookingHandoff(
        customerID: UUID,
        requestID: UUID,
        bookingID: UUID
    ) async throws {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerRequestRepository.acknowledgeBookingHandoff",
            scope: "customer.requests",
            operation: "acknowledgeBookingHandoff",
            metadata: [
                "customerID": customerID.uuidString,
                "requestID": requestID.uuidString,
                "bookingID": bookingID.uuidString,
                "rpc": "acknowledge_booking_handoff",
            ]
        ) {
            try await base.acknowledgeBookingHandoff(
                customerID: customerID,
                requestID: requestID,
                bookingID: bookingID
            )
        }
    }
}

@MainActor
final class DebugCustomerPushNotificationRepository:
    CustomerPushNotificationRepository
{
    private let base: any CustomerPushNotificationRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any CustomerPushNotificationRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func registerDeviceToken(
        customerID: UUID,
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID,
        environment: CustomerPushNotificationEnvironment
    ) async throws {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPushNotificationRepository.registerDeviceToken",
            scope: "customer.push",
            operation: "registerDeviceToken",
            metadata: [
                "customerID": customerID.uuidString,
                "installationID": installationID.uuidString,
                "environment": environment.rawValue,
                "rpc": "register_customer_push_token",
            ]
        ) {
            try await base.registerDeviceToken(
                customerID: customerID,
                token: token,
                installationID: installationID,
                environment: environment
            )
        }
    }

    func unregisterDeviceToken(
        token: CustomerPushNotificationDeviceToken,
        installationID: UUID
    ) async throws {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPushNotificationRepository.unregisterDeviceToken",
            scope: "customer.push",
            operation: "unregisterDeviceToken",
            metadata: [
                "installationID": installationID.uuidString,
                "rpc": "unregister_customer_push_token",
            ]
        ) {
            try await base.unregisterDeviceToken(
                token: token,
                installationID: installationID
            )
        }
    }
}

@MainActor
final class DebugCustomerNotificationRepository: CustomerNotificationRepository {
    private let base: any CustomerNotificationRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any CustomerNotificationRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func notifications(customerID: UUID) async throws -> [CustomerNotification] {
        try await notifications(customerID: customerID, page: .first).items
    }

    func notifications(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerNotification> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerNotificationRepository.notifications",
            scope: "customer.notifications",
            operation: "notifications",
            metadata: [
                "customerID": customerID.uuidString,
                "table": "customer_notifications",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.notifications(customerID: customerID, page: page)
        }
    }

    func markRead(
        notificationID: UUID
    ) async throws -> CustomerNotification {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerNotificationRepository.markRead",
            scope: "customer.notifications",
            operation: "markRead",
            metadata: [
                "notificationID": notificationID.uuidString,
                "rpc": "mark_customer_notification_read",
            ]
        ) {
            try await base.markRead(notificationID: notificationID)
        }
    }

    func markAllRead(customerID: UUID) async throws -> [CustomerNotification] {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerNotificationRepository.markAllRead",
            scope: "customer.notifications",
            operation: "markAllRead",
            metadata: [
                "customerID": customerID.uuidString,
                "rpc": "mark_all_customer_notifications_read",
            ]
        ) {
            try await base.markAllRead(customerID: customerID)
        }
    }
}

@MainActor
final class DebugGroomerNotificationRepository: GroomerNotificationRepository {
    private let base: any GroomerNotificationRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any GroomerNotificationRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func notifications(groomerID: UUID) async throws -> [GroomerNotification] {
        try await notifications(groomerID: groomerID, page: .first).items
    }

    func notifications(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerNotification> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "GroomerNotificationRepository.notifications",
            scope: "groomer.notifications",
            operation: "notifications",
            metadata: [
                "groomerID": groomerID.uuidString,
                "table": "groomer_notifications",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.notifications(groomerID: groomerID, page: page)
        }
    }

    func markRead(
        notificationID: UUID
    ) async throws -> GroomerNotification {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "GroomerNotificationRepository.markRead",
            scope: "groomer.notifications",
            operation: "markRead",
            metadata: [
                "notificationID": notificationID.uuidString,
                "rpc": "mark_groomer_notification_read",
            ]
        ) {
            try await base.markRead(notificationID: notificationID)
        }
    }

    func markAllRead(groomerID: UUID) async throws -> [GroomerNotification] {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "GroomerNotificationRepository.markAllRead",
            scope: "groomer.notifications",
            operation: "markAllRead",
            metadata: [
                "groomerID": groomerID.uuidString,
                "rpc": "mark_all_groomer_notifications_read",
            ]
        ) {
            try await base.markAllRead(groomerID: groomerID)
        }
    }
}

@MainActor
final class DebugCustomerProfileRepository: CustomerProfileRepository {
    private let base: any CustomerProfileRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any CustomerProfileRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func profile(customerID: UUID) async throws -> CustomerProfileDetails {
        try await profileCall(
            "profile",
            customerID: customerID,
            table: "customer_profiles"
        ) {
            try await base.profile(customerID: customerID)
        }
    }

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft
    ) async throws -> CustomerProfileDetails {
        try await profileCall(
            "updateProfile",
            customerID: customerID,
            table: "customer_profiles"
        ) {
            try await base.updateProfile(customerID: customerID, draft: draft)
        }
    }

    func updateProfile(
        customerID: UUID,
        draft: CustomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> CustomerProfileDetails {
        try await profileCall(
            "updateProfileWithAddress",
            customerID: customerID,
            table: "customer_profiles",
            metadata: [
                "rpc": "save_customer_profile_address_v2",
                "hasConfirmedAddress": "\(confirmedAddress != nil)",
            ]
        ) {
            try await base.updateProfile(
                customerID: customerID,
                draft: draft,
                confirmedAddress: confirmedAddress
            )
        }
    }

    func uploadAvatarPhoto(
        customerID: UUID,
        data: Data,
        contentType: CustomerAvatarPhotoContentType
    ) async throws -> String {
        try await profileCall(
            "uploadAvatarPhoto",
            customerID: customerID,
            table: "profiles",
            metadata: [
                "bucket": "customer-avatars",
                "contentType": contentType.rawValue,
            ]
        ) {
            try await base.uploadAvatarPhoto(
                customerID: customerID,
                data: data,
                contentType: contentType
            )
        }
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        try await profileCall(
            "avatarPhotoData",
            customerID: nil,
            metadata: [
                "bucket": "customer-avatars",
                "storagePath": storagePath,
            ]
        ) {
            try await base.avatarPhotoData(storagePath: storagePath)
        }
    }

    func latestAvatarPhotoPath(customerID: UUID) async throws -> String? {
        try await profileCall(
            "latestAvatarPhotoPath",
            customerID: customerID,
            metadata: ["bucket": "customer-avatars"]
        ) {
            try await base.latestAvatarPhotoPath(customerID: customerID)
        }
    }

    private func profileCall<T>(
        _ operation: String,
        customerID: UUID?,
        table: String? = nil,
        metadata: [String: String] = [:],
        body: () async throws -> T
    ) async throws -> T {
        var eventMetadata = metadata
        if let customerID {
            eventMetadata["customerID"] = customerID.uuidString
        }
        if let table {
            eventMetadata["table"] = table
        }

        return try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerProfileRepository.\(operation)",
            scope: "customer.profile",
            operation: operation,
            metadata: eventMetadata,
            body: body
        )
    }
}

@MainActor
final class DebugCustomerPetRepository: CustomerPetRepository {
    private let base: any CustomerPetRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any CustomerPetRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.pets",
            scope: "customer.pets",
            operation: "pets",
            metadata: ["customerID": customerID.uuidString, "table": "pets"]
        ) {
            try await base.pets(customerID: customerID)
        }
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.photos",
            scope: "customer.pets",
            operation: "photos",
            metadata: ["customerID": customerID.uuidString, "table": "pet_photos"]
        ) {
            try await base.photos(customerID: customerID)
        }
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.createPet",
            scope: "customer.pets",
            operation: "createPet",
            metadata: ["customerID": customerID.uuidString, "table": "pets"]
        ) {
            try await base.createPet(customerID: customerID, draft: draft)
        }
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.updatePet",
            scope: "customer.pets",
            operation: "updatePet",
            metadata: ["petID": pet.id.uuidString, "table": "pets"]
        ) {
            try await base.updatePet(pet: pet, draft: draft)
        }
    }

    func softDeletePet(_ pet: CustomerPet) async throws {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.softDeletePet",
            scope: "customer.pets",
            operation: "softDeletePet",
            metadata: ["petID": pet.id.uuidString, "table": "pets"]
        ) {
            try await base.softDeletePet(pet)
        }
    }

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.uploadPhoto",
            scope: "customer.pets",
            operation: "uploadPhoto",
            metadata: [
                "customerID": customerID.uuidString,
                "petID": petID.uuidString,
                "bucket": "pet-photos",
                "contentType": contentType.rawValue,
            ]
        ) {
            try await base.uploadPhoto(
                customerID: customerID,
                petID: petID,
                data: data,
                contentType: contentType,
                caption: caption
            )
        }
    }

    func photoData(_ photo: CustomerPetPhoto) async throws -> Data {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.photoData",
            scope: "customer.pets",
            operation: "photoData",
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "pet-photos",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.photoData(photo)
        }
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "CustomerPetRepository.deletePhoto",
            scope: "customer.pets",
            operation: "deletePhoto",
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "pet-photos",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.deletePhoto(photo)
        }
    }
}

@MainActor
final class DebugChatRepository: ChatRepository {
    private let base: any ChatRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any ChatRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        try await conversations(participantID: participantID, role: role, page: .first).items
    }

    func conversations(
        participantID: UUID,
        role: UserRole,
        page: ListPageRequest
    ) async throws -> ListPage<ChatConversation> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "ChatRepository.conversations",
            scope: "\(role.appDebugScopePrefix).messages",
            operation: "conversations",
            metadata: [
                "participantID": participantID.uuidString,
                "role": role.appDebugName,
                "table": "conversations",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.conversations(participantID: participantID, role: role, page: page)
        }
    }

    func messages(
        conversationID: UUID
    ) async throws -> [ChatMessage] {
        try await messages(conversationID: conversationID, page: .first).items
    }

    func messages(
        conversationID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<ChatMessage> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "ChatRepository.messages",
            scope: "messages.thread",
            operation: "messages",
            metadata: [
                "conversationID": conversationID.uuidString,
                "table": "messages",
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.messages(conversationID: conversationID, page: page)
        }
    }

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "ChatRepository.sendMessage",
            scope: "messages.thread",
            operation: "sendMessage",
            metadata: [
                "conversationID": conversationID.uuidString,
                "senderID": senderID.uuidString,
                "table": "messages",
            ]
        ) {
            try await base.sendMessage(
                conversationID: conversationID,
                senderID: senderID,
                body: body
            )
        }
    }

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage> {
        try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "ChatRepository.messageEvents",
            scope: "messages.thread",
            operation: "messageEvents",
            metadata: [
                "conversationID": conversationID.uuidString,
                "table": "messages",
                "event": "insert",
            ]
        ) {
            try await base.messageEvents(conversationID: conversationID)
        }
    }
}

@MainActor
final class DebugGroomerProfileRepository: GroomerProfileRepository {
    private let base: any GroomerProfileRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any GroomerProfileRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        try await groomerCall("profile", groomerID: groomerID, table: "profiles") {
            try await base.profile(groomerID: groomerID)
        }
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        try await groomerCall("services", groomerID: groomerID, table: "groomer_services") {
            try await base.services(groomerID: groomerID)
        }
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        try await groomerCall("portfolioPhotos", groomerID: groomerID, table: "groomer_portfolio_photos") {
            try await base.portfolioPhotos(groomerID: groomerID)
        }
    }

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        try await groomerCall("portfolioFitTags", groomerID: groomerID, table: "groomer_portfolio_fit_tags") {
            try await base.portfolioFitTags(groomerID: groomerID)
        }
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        try await groomerCall("availabilityWindows", groomerID: groomerID, table: "groomer_availability_windows") {
            try await base.availabilityWindows(groomerID: groomerID)
        }
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        try await groomerCall("bookingPreferences", groomerID: groomerID, table: "groomer_booking_preferences") {
            try await base.bookingPreferences(groomerID: groomerID)
        }
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        try await groomerCall("timeOffWindows", groomerID: groomerID, table: "groomer_time_off_windows") {
            try await base.timeOffWindows(groomerID: groomerID)
        }
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        try await groomerCall("fitClaims", groomerID: groomerID, table: "groomer_fit_claims") {
            try await base.fitClaims(groomerID: groomerID)
        }
    }

    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] {
        try await groomerCall("petFitEvidenceSummary", groomerID: groomerID, rpc: "get_my_groomer_pet_fit_evidence_summary") {
            try await base.petFitEvidenceSummary(groomerID: groomerID)
        }
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        try await groomerCall("updateProfile", groomerID: groomerID, table: "profiles") {
            try await base.updateProfile(groomerID: groomerID, draft: draft)
        }
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft,
        confirmedAddress: BeckonConfirmedAddress?
    ) async throws -> GroomerProfile {
        try await groomerCall(
            "updateProfileWithAddress",
            groomerID: groomerID,
            table: "groomer_profiles",
            metadata: [
                "rpc": "save_groomer_profile_address_v2",
                "hasConfirmedAddress": "\(confirmedAddress != nil)",
            ]
        ) {
            try await base.updateProfile(
                groomerID: groomerID,
                draft: draft,
                confirmedAddress: confirmedAddress
            )
        }
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        try await groomerCall("createService", groomerID: groomerID, table: "groomer_services") {
            try await base.createService(groomerID: groomerID, draft: draft)
        }
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        try await groomerCall(
            "updateService",
            groomerID: service.groomerID,
            table: "groomer_services",
            metadata: ["serviceID": service.id.uuidString]
        ) {
            try await base.updateService(service: service, draft: draft)
        }
    }

    func deleteService(_ service: GroomerService) async throws {
        try await groomerCall(
            "deleteService",
            groomerID: service.groomerID,
            table: "groomer_services",
            metadata: ["serviceID": service.id.uuidString]
        ) {
            try await base.deleteService(service)
        }
    }

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        try await groomerCall(
            "uploadPortfolioPhoto",
            groomerID: groomerID,
            table: "groomer_portfolio_photos",
            metadata: ["bucket": "groomer-portfolio", "contentType": contentType.rawValue]
        ) {
            try await base.uploadPortfolioPhoto(
                groomerID: groomerID,
                data: data,
                contentType: contentType,
                caption: caption
            )
        }
    }

    func portfolioPhotoData(_ photo: GroomerPortfolioPhoto) async throws -> Data {
        try await groomerCall(
            "portfolioPhotoData",
            groomerID: photo.groomerID,
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "groomer-portfolio",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.portfolioPhotoData(photo)
        }
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        try await groomerCall(
            "deletePortfolioPhoto",
            groomerID: photo.groomerID,
            table: "groomer_portfolio_photos",
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "groomer-portfolio",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.deletePortfolioPhoto(photo)
        }
    }

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        try await groomerCall(
            "uploadAvatarPhoto",
            groomerID: groomerID,
            metadata: ["bucket": "groomer-avatars", "contentType": contentType.rawValue]
        ) {
            try await base.uploadAvatarPhoto(
                groomerID: groomerID,
                data: data,
                contentType: contentType
            )
        }
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        try await groomerCall(
            "avatarPhotoData",
            groomerID: nil,
            metadata: ["bucket": "groomer-avatars", "storagePath": storagePath]
        ) {
            try await base.avatarPhotoData(storagePath: storagePath)
        }
    }

    func latestAvatarPhotoPath(groomerID: UUID) async throws -> String? {
        try await groomerCall("latestAvatarPhotoPath", groomerID: groomerID, metadata: ["bucket": "groomer-avatars"]) {
            try await base.latestAvatarPhotoPath(groomerID: groomerID)
        }
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        try await groomerCall("replaceAvailability", groomerID: groomerID, table: "groomer_availability_windows") {
            try await base.replaceAvailability(groomerID: groomerID, drafts: drafts)
        }
    }

    func availabilitySnapshot(groomerID: UUID) async throws -> GroomerAvailabilitySnapshot {
        try await groomerCall("availabilitySnapshot", groomerID: groomerID) {
            try await base.availabilitySnapshot(groomerID: groomerID)
        }
    }

    func saveAvailability(
        groomerID: UUID,
        expectedRevision: String,
        windows: [GroomerAvailabilityDraft],
        preferences: GroomerBookingPreferencesDraft,
        timeOff: [GroomerTimeOffWindow]
    ) async throws -> GroomerAvailabilitySnapshot {
        try await groomerCall("saveAvailability", groomerID: groomerID) {
            try await base.saveAvailability(groomerID: groomerID, expectedRevision: expectedRevision,
                windows: windows, preferences: preferences, timeOff: timeOff)
        }
    }

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences {
        try await groomerCall("updateBookingPreferences", groomerID: groomerID, table: "groomer_booking_preferences") {
            try await base.updateBookingPreferences(groomerID: groomerID, draft: draft)
        }
    }

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim] {
        try await groomerCall("replaceFitClaims", groomerID: groomerID, table: "groomer_fit_claims") {
            try await base.replaceFitClaims(groomerID: groomerID, drafts: drafts)
        }
    }

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag] {
        try await groomerCall(
            "replacePortfolioFitTags",
            groomerID: groomerID,
            table: "groomer_portfolio_fit_tags",
            metadata: ["photoID": photoID.uuidString]
        ) {
            try await base.replacePortfolioFitTags(
                groomerID: groomerID,
                photoID: photoID,
                drafts: drafts
            )
        }
    }

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow {
        try await groomerCall("createTimeOff", groomerID: groomerID, table: "groomer_time_off_windows") {
            try await base.createTimeOff(groomerID: groomerID, draft: draft)
        }
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws {
        try await groomerCall(
            "deleteTimeOff",
            groomerID: window.groomerID,
            table: "groomer_time_off_windows",
            metadata: ["timeOffID": window.id.uuidString]
        ) {
            try await base.deleteTimeOff(window)
        }
    }

    private func groomerCall<T>(
        _ operation: String,
        groomerID: UUID?,
        table: String? = nil,
        rpc: String? = nil,
        metadata: [String: String] = [:],
        body: () async throws -> T
    ) async throws -> T {
        var eventMetadata = metadata
        if let groomerID {
            eventMetadata["groomerID"] = groomerID.uuidString
        }
        if let table {
            eventMetadata["table"] = table
        }
        if let rpc {
            eventMetadata["rpc"] = rpc
        }

        return try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "GroomerProfileRepository.\(operation)",
            scope: "groomer.profile",
            operation: operation,
            metadata: eventMetadata,
            body: body
        )
    }
}

@MainActor
final class DebugGroomerRequestRepository: GroomerRequestRepository {
    private let base: any GroomerRequestRepository
    private let debugRecorder: AppDebugEventRecorder?

    init(
        base: any GroomerRequestRepository,
        debugRecorder: AppDebugEventRecorder?
    ) {
        self.base = base
        self.debugRecorder = debugRecorder
    }

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        try await matchedRequests(groomerID: groomerID, page: .first).items
    }

    func matchedRequests(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerMatchedRequest> {
        try await requestCall(
            "matchedRequests",
            groomerID: groomerID,
            table: "request_matches",
            metadata: [
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.matchedRequests(groomerID: groomerID, page: page)
        }
    }

    func offers(groomerID: UUID) async throws -> [GroomerOfferListItem] {
        try await offers(groomerID: groomerID, page: .first).items
    }

    func offers(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerOfferListItem> {
        try await requestCall(
            "offers",
            groomerID: groomerID,
            table: "groomer_offers",
            metadata: [
                "limit": "\(page.limit)",
                "offset": "\(page.offset)",
            ]
        ) {
            try await base.offers(groomerID: groomerID, page: page)
        }
    }

    func requestPhotos(
        groomerID: UUID,
        requestIDs: [UUID]
    ) async throws -> [GroomingRequestPhoto] {
        try await requestCall(
            "requestPhotos",
            groomerID: groomerID,
            table: "request_photos",
            metadata: ["requestCount": "\(requestIDs.count)"]
        ) {
            try await base.requestPhotos(groomerID: groomerID, requestIDs: requestIDs)
        }
    }

    func requestPhotoData(_ photo: GroomingRequestPhoto) async throws -> Data {
        try await requestCall(
            "requestPhotoData",
            groomerID: nil,
            metadata: [
                "photoID": photo.id.uuidString,
                "bucket": "request-photos",
                "storagePath": photo.storagePath,
            ]
        ) {
            try await base.requestPhotoData(photo)
        }
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        try await requestCall(
            "dismiss",
            groomerID: nil,
            rpc: "dismiss_request_match",
            metadata: ["matchID": matchID.uuidString]
        ) {
            try await base.dismiss(matchID: matchID, reason: reason)
        }
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        try await requestCall(
            "createOffer",
            groomerID: nil,
            rpc: "create_groomer_offer",
            metadata: ["requestID": draft.requestID.uuidString]
        ) {
            try await base.createOffer(draft: draft)
        }
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        try await requestCall(
            "withdrawOffer",
            groomerID: nil,
            rpc: "withdraw_groomer_offer",
            metadata: ["offerID": offerID.uuidString]
        ) {
            try await base.withdrawOffer(offerID: offerID)
        }
    }

    private func requestCall<T>(
        _ operation: String,
        groomerID: UUID?,
        table: String? = nil,
        rpc: String? = nil,
        metadata: [String: String] = [:],
        body: () async throws -> T
    ) async throws -> T {
        var eventMetadata = metadata
        if let groomerID {
            eventMetadata["groomerID"] = groomerID.uuidString
        }
        if let table {
            eventMetadata["table"] = table
        }
        if let rpc {
            eventMetadata["rpc"] = rpc
        }
        return try await debugRepositoryCall(
            recorder: debugRecorder,
            source: "GroomerRequestRepository.\(operation)",
            scope: "groomer.requests",
            operation: operation,
            metadata: eventMetadata,
            body: body
        )
    }
}
