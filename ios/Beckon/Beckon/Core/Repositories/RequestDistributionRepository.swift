import Foundation

@MainActor
protocol RequestDistributionRepository: AnyObject {
    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool,
                 groomerIDs: [UUID]) async throws -> RequestDistributionReceipt
    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID,
                groomerIDs: [UUID]) async throws -> RequestDistributionReceipt
    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID,
                 enabled: Bool) async throws -> RequestDistributionReceipt
    func withdrawInvitation(operationID: UUID, requestID: UUID,
                            groomerID: UUID) async throws -> RequestDistributionReceipt
    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress]
}
