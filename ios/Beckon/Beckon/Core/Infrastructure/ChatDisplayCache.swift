import Foundation

/// Bounded display snapshots only. Never creates booking action Stores or grants send permission.
@MainActor
final class FileChatDisplayCache {
    static let shared = FileChatDisplayCache()
    private(set) var generation = 0
    private let directory: URL
    private let queue = DispatchQueue(label: "beckon.chat-display-cache", qos: .utility)

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeckonChatDisplay", isDirectory: true)
    }

    func snapshot(participantID: UUID, role: UserRole, now: Date = Date())
        -> (conversations: [ChatConversation], messages: [UUID: [ChatMessage]], bookingConversations: [UUID: UUID])? {
        let file = url(participantID, role)
        guard let data = queue.sync(execute: { try? Data(contentsOf: file) }), data.count <= 8 * 1024 * 1024,
              let archive = try? JSONDecoder().decode(ChatDisplayArchive.self, from: data), archive.version == 1,
              archive.participantID == participantID, archive.role == role.rawValue,
              now.timeIntervalSince(archive.savedAt) < 30 * 86400,
              archive.savedAt.timeIntervalSince(now) < 86400 else { return nil }
        let conversations = archive.conversations.filter {
            (role == .customer ? $0.customerID : $0.groomerID) == participantID
        }
        guard conversations.count == archive.conversations.count, conversations.count <= 20,
              Set(conversations.map(\.id)).count == conversations.count else { return nil }
        var messages: [UUID: [ChatMessage]] = [:]
        for conversation in conversations {
            guard let rows = archive.messages[conversation.id] else { continue }
            guard rows.count <= 50, rows.allSatisfy({ row in
                row.conversationID == conversation.id && [conversation.customerID, conversation.groomerID].contains(row.senderID)
                    && (row.booking.map { $0.customerID == conversation.customerID && $0.groomerID == conversation.groomerID } ?? true)
            }) else { return nil }
            messages[conversation.id] = rows.map(\.value)
        }
        let ids = Set(conversations.map(\.id))
        let mappings = archive.bookingConversations.filter { ids.contains($0.value) }
        return (conversations, messages, mappings)
    }

    func save(participantID: UUID, role: UserRole, conversations: [ChatConversation], messages: [UUID: [ChatMessage]],
        generation token: Int, bookingConversations: [UUID: UUID] = [:]) {
        guard generation == token else { return }
        let recent = Array(conversations.filter { (role == .customer ? $0.customerID : $0.groomerID) == participantID }
            .sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
        let rows = recent.reduce(into: [UUID: [CachedChatMessage]]()) { result, conversation in
            if let values = messages[conversation.id] {
                result[conversation.id] = values.suffix(50).map(CachedChatMessage.init)
            }
        }
        let ids = Set(recent.map(\.id))
        let mappings = Dictionary(uniqueKeysWithValues: bookingConversations.filter { ids.contains($0.value) }.prefix(100).map { ($0.key, $0.value) })
        let archive = ChatDisplayArchive(participantID: participantID, role: role.rawValue,
            savedAt: Date(), conversations: recent, messages: rows, bookingConversations: mappings)
        let file = url(participantID, role), directory = directory
        queue.async {
            guard let data = try? JSONEncoder().encode(archive), data.count <= 8 * 1024 * 1024 else { return }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { /* Display cache failure never blocks the live conversation. */ }
        }
    }

    func remove(participantID: UUID) {
        generation += 1 // Reject late Store writes before draining/removing queued disk work.
        let files = [url(participantID, .customer), url(participantID, .groomer)]
        queue.sync { for file in files { try? FileManager.default.removeItem(at: file) } }
    }

    private func url(_ id: UUID, _ role: UserRole) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased())-\(role.rawValue).json")
    }
}

private nonisolated struct ChatDisplayArchive: Codable, Sendable {
    var version = 1
    let participantID: UUID
    let role: String
    let savedAt: Date
    let conversations: [ChatConversation]
    let messages: [UUID: [CachedChatMessage]]
    let bookingConversations: [UUID: UUID]
    var recentHistoryOnly = true
}

private nonisolated struct CachedChatMessage: Codable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let kind: ChatMessageKind
    let body: String?
    let createdAt: String
    let booking: CachedChatBooking?
    init(_ message: ChatMessage) {
        id = message.id; conversationID = message.conversationID; senderID = message.senderID
        kind = message.kind; body = message.body; createdAt = message.createdAt
        booking = message.booking.map(CachedChatBooking.init)
    }
    var value: ChatMessage {
        ChatMessage(id: id, conversationID: conversationID, senderID: senderID,
            kind: kind, body: body, booking: booking?.value, createdAt: createdAt)
    }
}

/// Only the existing ticket's visible facts. Never restores fulfillment, editable data or action eligibility.
private nonisolated struct CachedChatBooking: Codable, Sendable {
    let id: UUID, requestID: UUID, offerID: UUID, customerID: UUID, groomerID: UUID
    let start: String, end: String, createdAt: String, updatedAt: String
    let price: Double
    let status: BookingStatus
    let zone: String?
    let service: GroomingServiceType?
    let location: GroomingLocationMode?
    let petID: UUID?
    let petName: String?, species: String?, breed: String?
    init(_ booking: Booking) {
        id = booking.id; requestID = booking.requestID; offerID = booking.offerID
        customerID = booking.customerID; groomerID = booking.groomerID
        start = booking.scheduledStart; end = booking.scheduledEnd; price = booking.priceEstimate; status = booking.status
        createdAt = booking.createdAt; updatedAt = booking.updatedAt
        zone = booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier
        service = booking.serviceType; location = booking.locationMode
        let pet = booking.agreementSnapshot?.petSnapshot ?? booking.requestPetSnapshot
        petID = pet?.id; petName = pet?.name; species = pet?.species; breed = pet?.breed
    }
    var value: Booking {
        let pet = petID.flatMap { id -> GroomingRequestPetSnapshot? in
            guard let petName, let species else { return nil }
            return GroomingRequestPetSnapshot(id: id, name: petName, species: species, breed: breed,
                coatType: nil, size: nil, weightLbs: nil, birthday: nil, temperament: nil,
                medicalNotes: nil, groomingNotes: nil, snapshotAt: nil)
        }
        return Booking(id: id, requestID: requestID, offerID: offerID, customerID: customerID, groomerID: groomerID,
            scheduledStart: start, scheduledEnd: end, priceEstimate: price, status: status,
            cancelledBy: nil, cancelledAt: nil, completedAt: nil, completedBy: nil, createdAt: createdAt,
            updatedAt: updatedAt, review: nil, serviceType: service, requestPetSnapshot: pet,
            locationMode: location, serviceTimeZoneIdentifier: zone)
    }
}
