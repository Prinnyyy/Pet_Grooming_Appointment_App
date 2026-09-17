import Foundation

@MainActor
final class MatchSortPreferenceStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func groomerSort(accountID: UUID) -> GroomerMatchSort {
        GroomerMatchSort(rawValue: defaults.string(forKey: key(accountID, "groomer.matches")) ?? "") ?? .fit
    }

    func customerSort(accountID: UUID) -> CustomerOfferSort {
        CustomerOfferSort(rawValue: defaults.string(forKey: key(accountID, "customer.offers")) ?? "") ?? .balanced
    }

    func setGroomerSort(_ sort: GroomerMatchSort, accountID: UUID) {
        defaults.set(sort.rawValue, forKey: key(accountID, "groomer.matches"))
    }

    func setCustomerSort(_ sort: CustomerOfferSort, accountID: UUID) {
        defaults.set(sort.rawValue, forKey: key(accountID, "customer.offers"))
    }

    func reset(accountID: UUID) {
        defaults.removeObject(forKey: key(accountID, "groomer.matches"))
        defaults.removeObject(forKey: key(accountID, "customer.offers"))
    }

    private func key(_ accountID: UUID, _ scope: String) -> String {
        "beckon.match-sort.v1.\(accountID.uuidString.lowercased()).\(scope)"
    }
}
