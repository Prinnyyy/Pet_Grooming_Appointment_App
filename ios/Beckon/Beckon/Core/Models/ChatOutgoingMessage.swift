import Foundation

/// A local attempt, never a confirmed server message. The identity survives safe retries.
nonisolated struct ChatOutgoingMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let queuedAt: Date
    var failureMessage: String?

    var message: ChatMessage {
        ChatMessage(id: id, conversationID: conversationID, senderID: senderID, kind: .text,
            body: body, booking: nil, createdAt: GroomingRequestDateFormatting.serverString(from: queuedAt))
    }
    func matches(_ message: ChatMessage) -> Bool {
        message.id == id && message.conversationID == conversationID && message.senderID == senderID
            && message.kind == .text && message.body == body && message.bookingID == nil
    }
}
