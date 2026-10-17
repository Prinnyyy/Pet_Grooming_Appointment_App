import Foundation
import Observation

@MainActor
@Observable
final class CustomerRequestPublicationCoordinator {
    let customerID: UUID
    private(set) var pending: PendingRequestPublication?
    private(set) var recoveryError: RequestDiscoveryError?
    private(set) var isSending = false
    private let requestRepository: any CustomerRequestRepository
    private let distributionRepository: (any RequestDistributionRepository)?
    private let storageURL: URL
    private var sessionIsCurrent: () -> Bool
#if DEBUG && targetEnvironment(simulator)
    private var testOpsReceiptFaultUsed = false
#endif

    init(customerID: UUID, requestRepository: any CustomerRequestRepository,
         distributionRepository: (any RequestDistributionRepository)? = nil,
         storageDirectory: URL? = nil, sessionIsCurrent: @escaping () -> Bool = { true }) {
        self.customerID = customerID
        self.requestRepository = requestRepository
        self.distributionRepository = distributionRepository
        self.sessionIsCurrent = sessionIsCurrent
        let directory = storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("Beckon/PendingPublications", isDirectory: true)
        storageURL = directory.appendingPathComponent("\(customerID.uuidString).json")
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let restored = try JSONDecoder().decode(PendingRequestPublication.self, from: Data(contentsOf: storageURL))
                guard restored.customerID == customerID else { throw RequestDiscoveryError.notAllowed }
                pending = restored
            } catch {
                recoveryError = (error as? RequestDiscoveryError) ?? .unavailable
            }
        }
    }

    func setSessionValidation(_ validation: @escaping () -> Bool) { sessionIsCurrent = validation }

    func begin(_ intent: PendingRequestPublication) throws {
        try requireSession()
        if let recoveryError { throw recoveryError }
        guard intent.customerID == customerID else { throw RequestDiscoveryError.notAllowed }
        guard intent.protocolVersion == .discoveryV1 || distributionRepository == nil else {
            throw RequestDiscoveryError.clientUpdateRequired
        }
        if let pending {
            guard pending == intent else { throw RequestDiscoveryError.operationIntentChanged }
            return
        }
        guard !isSending else { throw RequestDiscoveryError.operationIntentChanged }
        try save(intent)
    }

    func resume() async throws -> PendingRequestPublication {
        try requireSession()
        if let recoveryError { throw recoveryError }
        guard var intent = pending, !isSending else { throw RequestDiscoveryError.operationIntentChanged }
        if intent.acknowledgement != nil { return intent }
        isSending = true
        defer { isSending = false }
        do {
            switch intent.protocolVersion {
            case .legacyV4:
                intent.acknowledgement = .legacy(try await requestRepository.createRequest(
                    customerID: customerID, draft: intent.draft))
            case .discoveryV1:
                guard let distributionRepository, let session = intent.session else {
                    throw RequestDiscoveryError.clientUpdateRequired
                }
                let receipt: RequestDistributionReceipt
                do {
                    receipt = try await distributionRepository.publish(operationID: intent.draft.publishOperationID,
                        session: session, poolEnabled: intent.poolEnabled, groomerIDs: intent.groomerIDs)
                } catch RequestDiscoveryError.alreadyPublished(let id) {
                    let progress = try await distributionRepository.progress(requestIDs: [id])
                    guard let current = progress.first, progress.count == 1, current.requestID == id else {
                        throw RequestDiscoveryError.unavailable
                    }
                    receipt = .init(requestID: id, termsRevision: current.termsRevision,
                        distributionRevision: current.distributionRevision, poolEnabled: current.poolEnabled,
                        invitedGroomerIDs: current.invitations.map(\.groomerID))
                }
#if DEBUG && targetEnvironment(simulator)
                if !testOpsReceiptFaultUsed && DebugDiscoveryPublicationFault.dropsReceipt(
                    for: intent, arguments: ProcessInfo.processInfo.arguments) {
                    testOpsReceiptFaultUsed = true
                    throw RequestDiscoveryError.networkUnavailable
                }
#endif
                intent.acknowledgement = .discovery(receipt)
            }
            // Persist acceptance before any photo/network handoff can fail or the account changes.
            try save(intent)
            try requireSession()
            return intent
        } catch {
            if isAuthoritativeRejection(error), pending?.acknowledgement == nil { try save(nil) }
            throw error
        }
    }

    func acknowledgePhoto(_ id: UUID, requestID: UUID) throws {
        try requireSession()
        guard var intent = pending, intent.acknowledgement?.requestID == requestID else {
            throw RequestDiscoveryError.operationIntentChanged
        }
        intent.photos.removeAll { $0.id == id }
        try save(intent)
    }

    func finishHandoff(requestID: UUID) throws {
        try requireSession()
        guard let pending, pending.acknowledgement?.requestID == requestID, pending.photos.isEmpty else {
            throw RequestDiscoveryError.operationIntentChanged
        }
        try save(nil)
    }

    func discardAcceptedPhotos(requestID: UUID) throws {
        try requireSession()
        guard pending?.acknowledgement?.requestID == requestID else {
            throw RequestDiscoveryError.operationIntentChanged
        }
        try save(nil)
    }

    private func requireSession() throws {
        guard sessionIsCurrent(), !Task.isCancelled else { throw RequestDiscoveryError.cancelled }
    }

    private func save(_ value: PendingRequestPublication?) throws {
        // A malformed/future file is never replaced by a new intent.
        if let recoveryError { throw recoveryError }
        if let value {
            var directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var resources = URLResourceValues()
            resources.isExcludedFromBackup = true
            try directory.setResourceValues(resources)
            try JSONEncoder().encode(value).write(to: storageURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }
        pending = value
    }

    private func isAuthoritativeRejection(_ error: any Error) -> Bool {
        if let failure = error as? CustomerRequestRepositoryError {
            switch failure {
            case .requestLimitExceeded, .requestNotFound, .requestNotCancellable, .petNotFound, .invalidInput,
                 .clientUpdateRequired: return true
            default: return false
            }
        }
        guard let failure = error as? RequestDiscoveryError else { return false }
        switch failure {
        case .discoveryExpired, .discoveryChanged, .requestChanged, .groomerUnavailable,
             .invitationLimitReached, .requestLimitExceeded, .invalidInput: return true
        default: return false
        }
    }
}
