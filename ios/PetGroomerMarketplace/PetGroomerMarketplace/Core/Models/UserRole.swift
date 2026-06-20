nonisolated enum UserRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case customer
    case groomer

    var id: Self { self }

    var title: String {
        switch self {
        case .customer:
            "Customer"
        case .groomer:
            "Groomer"
        }
    }

    var entryRoute: AppEntryRoute {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }
}
