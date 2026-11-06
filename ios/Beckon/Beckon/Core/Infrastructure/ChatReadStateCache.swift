import Foundation

protocol ChatReadStateCaching: AnyObject {
    func timestamps(participantID: UUID, role: UserRole) -> [UUID: String]
    func save(_ timestamps: [UUID: String], participantID: UUID, role: UserRole)
}

final class UserDefaultsChatReadStateCache: ChatReadStateCaching {
    static let shared = UserDefaultsChatReadStateCache()

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func timestamps(participantID: UUID, role: UserRole) -> [UUID: String] {
        guard let stored = userDefaults.dictionary(forKey: key(participantID, role))
            as? [String: String] else { return [:] }

        return stored.reduce(into: [:]) { result, item in
            guard let id = UUID(uuidString: item.key) else { return }
            result[id] = item.value
        }
    }

    func save(_ timestamps: [UUID: String], participantID: UUID, role: UserRole) {
        userDefaults.set(
            Dictionary(uniqueKeysWithValues: timestamps.map {
                ($0.key.uuidString.lowercased(), $0.value)
            }),
            forKey: key(participantID, role)
        )
    }

    private func key(_ participantID: UUID, _ role: UserRole) -> String {
        "beckon.chat.read.\(role.rawValue).\(participantID.uuidString.lowercased())"
    }
}

/// Bounded non-content receipts for Grooming updates. Account/role scoped like chat read state.
@MainActor
final class GroomingReadStateCache {
    static let shared = GroomingReadStateCache()
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ id: UUID) -> String { "beckon.grooming.read.groomer.\(id.uuidString.lowercased())" }
    func keys(accountID: UUID) -> Set<String> { Set(defaults.stringArray(forKey: key(accountID)) ?? []) }
    func record(_ values: [String], accountID: UUID) {
        let old = defaults.stringArray(forKey: key(accountID)) ?? []
        let merged = old.filter { !values.contains($0) } + values
        defaults.set(Array(merged.suffix(500)), forKey: key(accountID))
    }
    func remove(accountID: UUID) { defaults.removeObject(forKey: key(accountID)) }
}
