nonisolated enum GroomerTab: CaseIterable, Identifiable, Equatable {
    case requests
    case offers
    case bookings
    case messages
    case notifications
    case account

    static let visibleCases: [Self] = [
        .requests,
        .offers,
        .bookings,
        .messages,
        .notifications,
        .account,
    ]

    var id: Self { self }

    var title: String {
        switch self {
        case .requests: "Board"
        case .offers: "Offers"
        case .bookings: "Schedule"
        case .messages: "Messages"
        case .notifications: "Alerts"
        case .account: "Account"
        }
    }

    var systemImage: String {
        switch self {
        case .requests: "tray.full"
        case .offers: "tag"
        case .bookings: "calendar"
        case .messages: "message"
        case .notifications: "bell"
        case .account: "person.crop.circle"
        }
    }

    func badgeCount(
        unreadNotificationCount: Int,
        unreadMessageCount: Int
    ) -> Int {
        switch self {
        case .messages:
            unreadMessageCount
        case .notifications:
            unreadNotificationCount
        case .requests, .offers, .bookings, .account:
            0
        }
    }
}
