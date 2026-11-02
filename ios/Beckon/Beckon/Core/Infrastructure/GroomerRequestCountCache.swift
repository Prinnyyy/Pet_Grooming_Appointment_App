import Foundation

/// Two display-only numbers per account. A cached count never makes a list loaded or authorizes an action.
@MainActor final class GroomerRequestCountCache {
    enum Kind: String, CaseIterable { case matches, offers }
    static let shared = GroomerRequestCountCache()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func count(groomerID: UUID, kind: Kind) -> Int? {
        guard let value = defaults.object(forKey: key(groomerID, kind)) as? Int, value >= 0 else { return nil }
        return value
    }

    func save(_ count: Int, groomerID: UUID, kind: Kind) {
        let value = max(0, count)
        guard self.count(groomerID: groomerID, kind: kind) != value else { return }
        defaults.set(value, forKey: key(groomerID, kind))
    }

    func remove(groomerID: UUID) {
        for kind in Kind.allCases { defaults.removeObject(forKey: key(groomerID, kind)) }
    }

    private func key(_ id: UUID, _ kind: Kind) -> String {
        "beckon.groomer.request-counts.\(id.uuidString.lowercased()).\(kind.rawValue)"
    }
}
