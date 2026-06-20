nonisolated enum UserRole: CaseIterable, Identifiable, Equatable {
    case customer
    case groomer

    var id: Self { self }

    var entryRoute: AppEntryRoute {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }
}
