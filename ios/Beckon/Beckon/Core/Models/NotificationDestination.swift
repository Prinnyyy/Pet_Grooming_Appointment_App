import Foundation

enum NotificationDestination: Hashable {
    case request(UUID)
    case offer(requestID: UUID, offerID: UUID)
    case booking(UUID)
    case message(ChatConversation)
}
