nonisolated enum GroomerTab: CaseIterable, Identifiable, Equatable {
    case requests
    case offers
    case bookings
    case messages
    case account

    var id: Self { self }

    var title: String {
        switch self {
        case .requests: "Board"
        case .offers: "Offers"
        case .bookings: "Schedule"
        case .messages: "Messages"
        case .account: "Account"
        }
    }

    var systemImage: String {
        switch self {
        case .requests: "tray.full"
        case .offers: "tag"
        case .bookings: "calendar"
        case .messages: "message"
        case .account: "person.crop.circle"
        }
    }
}
