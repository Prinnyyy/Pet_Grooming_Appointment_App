import SwiftUI

private struct BookingChatActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Booking) -> Void)? = nil
}

extension EnvironmentValues {
    // Role shells own navigation, including details opened from offers or notifications.
    var openBookingChat: (@MainActor (Booking) -> Void)? {
        get { self[BookingChatActionKey.self] }
        set { self[BookingChatActionKey.self] = newValue }
    }
}

/// Reuses the role shell's chat store; opening a request contact never switches tabs.
@MainActor
struct RequestChatContext {
    let participantID: UUID
    let role: UserRole
    let repository: any ChatRepository
    let store: ChatStore
    let isCurrent: @MainActor () -> Bool
}
extension EnvironmentValues {
    @Entry var requestChatContext: RequestChatContext? = nil
    @Entry var openRequestChat: (@MainActor (UUID) -> Void)? = nil
}
