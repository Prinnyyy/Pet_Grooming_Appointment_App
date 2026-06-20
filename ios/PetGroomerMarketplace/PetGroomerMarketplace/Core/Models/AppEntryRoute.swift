nonisolated enum AppEntryRoute: CaseIterable, Identifiable, Equatable {
    case authentication
    case roleOnboarding
    case customer
    case groomer

    static let productionDefault: Self = .authentication

    var id: Self { self }
}
