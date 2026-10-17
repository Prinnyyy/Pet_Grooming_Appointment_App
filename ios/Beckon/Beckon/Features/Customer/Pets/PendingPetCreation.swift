import Foundation
import Observation

struct PendingPetCreation: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let customerID: UUID
    let operationID: UUID
    let draft: CustomerPetDraft

    init(customerID: UUID, operationID: UUID = UUID(), draft: CustomerPetDraft) {
        schemaVersion = 1
        self.customerID = customerID
        self.operationID = operationID
        self.draft = draft
    }
}

@MainActor
@Observable
final class PendingPetCreationStorage {
    let customerID: UUID
    let url: URL
    private(set) var pending: PendingPetCreation?
    private(set) var recoveryError: CustomerPetRepositoryError?

    init(customerID: UUID, directory: URL? = nil) {
        self.customerID = customerID
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("Beckon/PendingPetCreations", isDirectory: true)
        url = directory.appendingPathComponent("\(customerID.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let restored = try JSONDecoder().decode(PendingPetCreation.self, from: Data(contentsOf: url))
            guard restored.schemaVersion == 1 else { throw CustomerPetRepositoryError.clientUpdateRequired }
            guard restored.customerID == customerID else { throw CustomerPetRepositoryError.notAllowed }
            pending = restored
        } catch {
            recoveryError = (error as? CustomerPetRepositoryError) ?? .unavailable
        }
    }

    func begin(_ value: PendingPetCreation) throws {
        if let recoveryError { throw recoveryError }
        guard value.customerID == customerID else { throw CustomerPetRepositoryError.notAllowed }
        if let pending {
            guard pending == value else { throw CustomerPetRepositoryError.operationIntentChanged }
            return
        }
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try directory.setResourceValues(resources)
        try JSONEncoder().encode(value).write(to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        pending = value
    }

    func finish(operationID: UUID) throws {
        if let recoveryError { throw recoveryError }
        guard pending?.operationID == operationID else { throw CustomerPetRepositoryError.operationIntentChanged }
        try FileManager.default.removeItem(at: url)
        pending = nil
    }
}
