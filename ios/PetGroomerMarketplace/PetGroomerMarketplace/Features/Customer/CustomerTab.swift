nonisolated enum CustomerTab: CaseIterable, Identifiable, Equatable {
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
}
