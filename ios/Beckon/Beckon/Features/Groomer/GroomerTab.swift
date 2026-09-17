nonisolated enum GroomerTab: CaseIterable, Identifiable, Equatable {
    case home
    case requests
    case bookings
    case messages
    case account

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .requests: "Requests"
        case .bookings: "Schedule"
        case .messages: "Messages"
        case .account: "Account"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .requests: "person.2"
        case .bookings: "calendar"
        case .messages: "message"
        case .account: "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: "groomer.tab.home"
        case .requests: "groomer.tab.requests"
        case .bookings: "groomer.tab.bookings"
        case .messages: "groomer.tab.messages"
        case .account: "groomer.tab.account"
        }
    }

    func badgeCount(
        unreadNotificationCount: Int,
        unreadMessageCount: Int
    ) -> Int {
        switch self {
        case .messages:
            unreadMessageCount
        case .home, .requests, .bookings, .account:
            0
        }
    }
}
