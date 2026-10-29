nonisolated enum CustomerTab: CaseIterable, Identifiable, Equatable {
    case home
    case requests
    // Retained for the frozen prototype and legacy adapters; not a customer tab.
    case bookings
    case messages
    case account

    static let allCases: [Self] = [.home, .requests, .messages, .account]

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .requests: "Grooming"
        case .bookings: "Bookings"
        case .messages: "Messages"
        case .account: "Account"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .requests: "list.bullet.clipboard"
        case .bookings: "calendar"
        case .messages: "message"
        case .account: "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: "customer.tab.home"
        case .requests: "customer.tab.requests"
        case .bookings: "customer.tab.bookings"
        case .messages: "customer.tab.messages"
        case .account: "customer.tab.account"
        }
    }

    func badgeCount(
        unreadNotificationCount: Int,
        unreadMessageCount: Int
    ) -> Int {
        switch self {
        case .home:
            unreadNotificationCount
        case .messages:
            unreadMessageCount
        case .requests, .bookings, .account:
            0
        }
    }
}
