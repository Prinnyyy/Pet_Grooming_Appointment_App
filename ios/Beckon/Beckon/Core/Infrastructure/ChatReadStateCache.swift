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
