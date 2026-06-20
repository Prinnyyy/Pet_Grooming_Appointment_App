import Testing
@testable import PetGroomerMarketplace

struct AppEntryModelsTests {
    @Test
    func userRolesHaveExactOrderAndRoutes() {
        #expect(UserRole.allCases == [.customer, .groomer])
        #expect(UserRole.customer.entryRoute == .customer)
        #expect(UserRole.groomer.entryRoute == .groomer)
        #expect(UserRole.customer.id == .customer)
        #expect(UserRole.groomer.id == .groomer)
    }

    @Test
    func appEntryRoutesHaveExactOrderAndProductionDefault() {
        #expect(
            AppEntryRoute.allCases == [
                .authentication,
                .roleOnboarding,
                .customer,
                .groomer,
            ]
        )
        #expect(AppEntryRoute.productionDefault == .authentication)
        #expect(AppEntryRoute.authentication.id == .authentication)
    }
}

struct TabModelsTests {
    @Test
    func customerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(CustomerTab.allCases == [.home, .requests, .bookings, .messages, .account])
        #expect(CustomerTab.allCases.map(\.title) == ["Home", "Requests", "Bookings", "Messages", "Account"])
        #expect(CustomerTab.allCases.map(\.systemImage) == ["house", "list.bullet.clipboard", "calendar", "message", "person.crop.circle"])
        #expect(CustomerTab.allCases.allSatisfy { $0.id == $0 })
    }

    @Test
    func groomerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(GroomerTab.allCases == [.requests, .offers, .bookings, .messages, .account])
        #expect(GroomerTab.allCases.map(\.title) == ["Requests", "Offers", "Bookings", "Messages", "Account"])
        #expect(GroomerTab.allCases.map(\.systemImage) == ["tray.full", "tag", "calendar", "message", "person.crop.circle"])
        #expect(GroomerTab.allCases.allSatisfy { $0.id == $0 })
    }
}
