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
