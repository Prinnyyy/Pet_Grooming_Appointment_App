import Foundation
import Observation

@MainActor
@Observable
final class CustomerRequestDistributionStore {
    private(set) var progressByRequestID: [UUID: CustomerRequestProgress] = [:]
    private(set) var receipts: [UUID: RequestDistributionReceipt] = [:]
    private(set) var mutatingIDs: Set<UUID> = []
    private(set) var isPublishing = false
    private(set) var isRefreshing = false
    private(set) var error: RequestDiscoveryError?
    private(set) var uncertainRequestIDs: Set<UUID> = []
    private let repository: any RequestDistributionRepository
    private let publication: CustomerRequestPublicationCoordinator
    private let sessionIsCurrent: () -> Bool
    private var generation: UInt64 = 0
    private var readGeneration: UInt64 = 0
    private var requestEpochs: [UUID: UInt64] = [:]
    private var epoch: UInt64 = 0
    private var pendingMutations: [UUID: Mutation] = [:]
    private var confirmedInvitations: [UUID: [UUID: RequestInvitationState]] = [:]

    private struct Mutation {
        enum Kind { case invite(UUID, [UUID]), pool(UUID, Bool), withdraw(UUID) }
        let operationID = UUID()
        let kind: Kind
    }

    init(repository: any RequestDistributionRepository, publication: CustomerRequestPublicationCoordinator,
         sessionIsCurrent: @escaping () -> Bool = { true }) {
        self.repository = repository
        self.publication = publication
        self.sessionIsCurrent = sessionIsCurrent
    }

    func state(requestID: UUID?, groomerID: UUID, seed: RequestInvitationState) -> RequestInvitationState {
        guard let requestID else { return seed }
        if let progress = progressByRequestID[requestID] {
            if !progress.status.isOpenForOffers || progress.expiresAt <= Date() { return .closed }
            if let invitation = progress.invitations.first(where: { $0.groomerID == groomerID }) {
                if invitation.state == .awaitingResponse && invitation.replyBy <= Date() { return .expired }
            }
        }
        return confirmedInvitations[requestID]?[groomerID] ?? seed
    }

    func publish(_ intent: PendingRequestPublication) async -> RequestDistributionReceipt? {
        guard sessionIsCurrent(), !isPublishing else { return nil }
        let current = generation
        isPublishing = true; error = nil
        defer { if current == generation { isPublishing = false } }
        do {
            if publication.pending == nil { try publication.begin(intent) }
            else if publication.pending?.draft.publishOperationID != intent.draft.publishOperationID {
                throw RequestDiscoveryError.operationIntentChanged
            }
            let accepted = try await publication.resume()
            guard current == generation, sessionIsCurrent(), !Task.isCancelled else { return nil }
            guard case let .discovery(receipt) = accepted.acknowledgement else {
                throw RequestDiscoveryError.clientUpdateRequired
            }
            accept(receipt)
            await refresh(requestIDs: [receipt.requestID])
            return receipt
        } catch {
            guard current == generation, sessionIsCurrent() else { return nil }
            self.error = normalized(error)
            return nil
        }
    }

    func invite(requestID: UUID, termsRevision: UUID, groomerIDs: [UUID]) async -> Bool {
        await mutate(requestID: requestID, kind: .invite(termsRevision, groomerIDs))
    }

    func setPool(requestID: UUID, enabled: Bool) async -> Bool {
        guard let revision = progressByRequestID[requestID]?.distributionRevision ?? receipts[requestID]?.distributionRevision else {
            error = .distributionChanged; return false
        }
        return await mutate(requestID: requestID, kind: .pool(revision, enabled))
    }

    func withdraw(requestID: UUID, groomerID: UUID) async -> Bool {
        await mutate(requestID: requestID, kind: .withdraw(groomerID))
    }

    func retry(requestID: UUID) async -> Bool {
        guard let pending = pendingMutations[requestID] else { return false }
        return await perform(pending, requestID: requestID)
    }

    private func mutate(requestID: UUID, kind: Mutation.Kind) async -> Bool {
        guard pendingMutations[requestID] == nil else { error = .operationIntentChanged; return false }
        return await perform(Mutation(kind: kind), requestID: requestID)
    }

    private func perform(_ mutation: Mutation, requestID: UUID) async -> Bool {
        guard sessionIsCurrent(), !mutatingIDs.contains(requestID) else { return false }
        let current = generation
        pendingMutations[requestID] = mutation
        mutatingIDs.insert(requestID); error = nil
        epoch &+= 1; requestEpochs[requestID] = epoch
        defer { if current == generation { mutatingIDs.remove(requestID) } }
        do {
            let receipt: RequestDistributionReceipt
            switch mutation.kind {
            case let .invite(revision, ids):
                receipt = try await repository.invite(operationID: mutation.operationID, requestID: requestID,
                    expectedTermsRevision: revision, groomerIDs: ids)
            case let .pool(revision, enabled):
                receipt = try await repository.setPool(operationID: mutation.operationID, requestID: requestID,
                    expectedRevision: revision, enabled: enabled)
            case let .withdraw(groomerID):
                receipt = try await repository.withdrawInvitation(operationID: mutation.operationID,
                    requestID: requestID, groomerID: groomerID)
            }
            guard current == generation, sessionIsCurrent(), !Task.isCancelled else { return false }
            guard receipt.requestID == requestID else { throw RequestDiscoveryError.notAllowed }
            accept(receipt)
            if case let .withdraw(groomerID) = mutation.kind {
                confirmedInvitations[requestID, default: [:]][groomerID] = .withdrawn
            }
            pendingMutations[requestID] = nil; uncertainRequestIDs.remove(requestID)
            await refresh(requestIDs: [requestID])
            return true
        } catch {
            guard current == generation, sessionIsCurrent() else { return false }
            let failure = normalized(error)
            self.error = failure
            switch failure {
            case .networkUnavailable, .unavailable, .cancelled, .notAllowed:
                uncertainRequestIDs.insert(requestID)
            default:
                pendingMutations[requestID] = nil; uncertainRequestIDs.remove(requestID)
                await refresh(requestIDs: [requestID])
                self.error = failure
            }
            return false
        }
    }

    func refresh(requestIDs: [UUID]) async {
        guard sessionIsCurrent(), !requestIDs.isEmpty else { return }
        let session = generation, startEpoch = epoch
        readGeneration &+= 1
        let read = readGeneration
        isRefreshing = true
        defer { if read == readGeneration { isRefreshing = false } }
        let ids = Array(Set(requestIDs)).sorted { $0.uuidString < $1.uuidString }
        do {
            var result: [CustomerRequestProgress] = []
            for start in stride(from: 0, to: ids.count, by: 25) {
                let batch = Array(ids[start..<min(start + 25, ids.count)])
                let rows = try await repository.progress(requestIDs: batch)
                guard Set(rows.map(\.requestID)) == Set(batch), rows.count == batch.count else {
                    throw RequestDiscoveryError.unavailable
                }
                result += rows
            }
            guard session == generation, read == readGeneration, sessionIsCurrent(), !Task.isCancelled else { return }
            if uncertainRequestIDs.isEmpty { error = nil }
            for row in result where requestEpochs[row.requestID, default: 0] <= startEpoch {
                progressByRequestID[row.requestID] = row
                receipts[row.requestID] = .init(requestID: row.requestID, termsRevision: row.termsRevision,
                    distributionRevision: row.distributionRevision, poolEnabled: row.poolEnabled,
                    invitedGroomerIDs: row.invitations.map(\.groomerID))
                confirmedInvitations[row.requestID] = Dictionary(uniqueKeysWithValues: row.invitations.map { ($0.groomerID, $0.state) })
            }
        } catch {
            guard session == generation, read == readGeneration, sessionIsCurrent() else { return }
            self.error = normalized(error)
        }
    }

    func nextDeadline(requestIDs: [UUID], now: Date = Date()) -> Date? {
        requestIDs.compactMap { progressByRequestID[$0] }.filter { $0.status.isOpenForOffers }
            .flatMap { [$0.expiresAt] + $0.invitations.filter { $0.state == .awaitingResponse }.map(\.replyBy) }
            .filter { $0 > now }.min()
    }

    private func accept(_ receipt: RequestDistributionReceipt) {
        epoch &+= 1; requestEpochs[receipt.requestID] = epoch
        receipts[receipt.requestID] = receipt
        // Invalidate old pool/revision facts immediately, without guessing a new progress count.
        progressByRequestID[receipt.requestID] = nil
        for id in receipt.invitedGroomerIDs where confirmedInvitations[receipt.requestID]?[id] == nil {
            confirmedInvitations[receipt.requestID, default: [:]][id] = .awaitingResponse
        }
    }

    func clearSession() {
        generation &+= 1; readGeneration &+= 1
        progressByRequestID = [:]; receipts = [:]; confirmedInvitations = [:]
        pendingMutations = [:]; requestEpochs = [:]; uncertainRequestIDs = []; mutatingIDs = []
        isRefreshing = false; isPublishing = false; error = nil
    }

    private func normalized(_ error: any Error) -> RequestDiscoveryError {
        if error is CancellationError { return .cancelled }
        return (error as? RequestDiscoveryError) ?? .unavailable
    }
}
