import Foundation
import Testing
@testable import Beckon

@MainActor
struct RequestPublicationCoordinatorTests {
#if DEBUG && targetEnvironment(simulator)
    @Test func browseFaultRequiresAnExplicitRunCustomerAndExactDraftMarker() throws {
        let run = "TESTOPS-T399-BROWSE-SCOPE"
        let fixture = try PublicationFixture(serviceNotes: "TESTOPS:\(run)")
        defer { fixture.clean() }
        let args = ["--beckon-testops-run-id", run, "--beckon-testops-discovery-fail-read",
            "--beckon-testops-discovery-customer", fixture.customerID.uuidString]
        func enabled(_ arguments: [String], customer: UUID?) -> Bool {
            DebugDiscoveryBrowseFault.failsReadAfterInitialPage(draft: fixture.intent.draft,
                customerID: customer, arguments: arguments)
        }
        #expect(enabled(args, customer: fixture.customerID))
        #expect(!enabled(args, customer: nil))
        #expect(!enabled(args, customer: UUID()))
        #expect(!enabled(args.filter { $0 != "--beckon-testops-discovery-fail-read" }, customer: fixture.customerID))
        #expect(!enabled(args.map { $0 == run ? "TESTOPS-T392-OTHER" : $0 }, customer: fixture.customerID))
        let unrelated = try PublicationFixture()
        defer { unrelated.clean() }
        #expect(!DebugDiscoveryBrowseFault.failsReadAfterInitialPage(draft: unrelated.intent.draft,
            customerID: fixture.customerID, arguments: args))
    }

    @Test func receiptFaultRequiresAnExplicitRunCustomerAndExactDraftMarker() throws {
        let run = "TESTOPS-T399-FAULT-SCOPE"
        let fixture = try PublicationFixture(serviceNotes: "TESTOPS:\(run)")
        defer { fixture.clean() }
        let args = ["--beckon-testops-run-id", run, "--beckon-testops-discovery-drop-receipt",
            "--beckon-testops-discovery-customer", fixture.customerID.uuidString]
        #expect(DebugDiscoveryPublicationFault.dropsReceipt(for: fixture.intent, arguments: args))
        #expect(!DebugDiscoveryPublicationFault.dropsReceipt(for: fixture.intent,
            arguments: args.filter { $0 != "--beckon-testops-discovery-drop-receipt" }))
        #expect(!DebugDiscoveryPublicationFault.dropsReceipt(for: fixture.intent,
            arguments: args.map { $0 == fixture.customerID.uuidString ? UUID().uuidString : $0 }))
        #expect(!DebugDiscoveryPublicationFault.dropsReceipt(for: fixture.intent,
            arguments: args.map { $0 == run ? "TESTOPS-T392-NOT-THIS-RUN" : $0 }))
        let unrelated = try PublicationFixture()
        defer { unrelated.clean() }
        #expect(!DebugDiscoveryPublicationFault.dropsReceipt(for: unrelated.intent,
            arguments: args.map { $0 == fixture.customerID.uuidString ? unrelated.customerID.uuidString : $0 }))
    }
#endif
    @Test func discardAcceptedPhotosReleasesOnlyTheConfirmedRequest() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let coordinator = fixture.coordinator()
        try coordinator.begin(fixture.intent)
        #expect(throws: RequestDiscoveryError.operationIntentChanged) {
            try coordinator.discardAcceptedPhotos(requestID: fixture.distribution.receipt.requestID)
        }
        _ = try await coordinator.resume()
        #expect(throws: RequestDiscoveryError.operationIntentChanged) {
            try coordinator.discardAcceptedPhotos(requestID: UUID())
        }
        try coordinator.discardAcceptedPhotos(requestID: fixture.distribution.receipt.requestID)
        #expect(fixture.coordinator().pending == nil)
        #expect(fixture.distribution.operations.count == 1)
    }

    @Test func lostResponseReplaysTheSameIntentAfterRestartAndPreviewExpiry() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let initial = fixture.coordinator()
        try initial.begin(fixture.intent)
        fixture.distribution.failure = .networkUnavailable
        await #expect(throws: RequestDiscoveryError.networkUnavailable) { try await initial.resume() }
        let restarted = fixture.coordinator()
        #expect(restarted.pending?.session?.expiresAt ?? .distantFuture < Date())
        fixture.distribution.failure = nil
        let accepted = try await restarted.resume()
        #expect(accepted.acknowledgement?.requestID == fixture.distribution.receipt.requestID)
        #expect(fixture.distribution.operations == [fixture.intent.draft.publishOperationID, fixture.intent.draft.publishOperationID])
        #expect(fixture.legacy.createCallCount == 0)
    }

    @Test func confirmedRequestAndPhotosSurviveHandoffFailureWithoutRepublishing() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let first = fixture.coordinator()
        try first.begin(fixture.intent)
        let accepted = try await first.resume()
        let id = try #require(accepted.acknowledgement?.requestID)
        let restarted = fixture.coordinator()
        #expect(try await restarted.resume() == accepted)
        #expect(fixture.distribution.operations.count == 1)
        #expect(throws: RequestDiscoveryError.operationIntentChanged) { try restarted.finishHandoff(requestID: id) }
        try restarted.acknowledgePhoto(fixture.intent.photos[0].id, requestID: id)
        try restarted.finishHandoff(requestID: id)
        #expect(fixture.coordinator().pending == nil)
    }

    @Test func futureVersionIsPreservedAndCannotBeOverwritten() throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let bytes = Data("{\"schemaVersion\":99}".utf8)
        try bytes.write(to: fixture.file)
        let coordinator = fixture.coordinator()
        #expect(coordinator.recoveryError == .clientUpdateRequired)
        #expect(throws: RequestDiscoveryError.clientUpdateRequired) { try coordinator.begin(fixture.intent) }
        #expect(try Data(contentsOf: fixture.file) == bytes)
    }

    @Test func legacyUnversionedIntentUsesOnlyTheOriginalProtocol() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        struct Legacy: Codable {
            let customerID: UUID
            let draft: GroomingRequestDraft
            let photos: [PendingGroomingRequestPhoto]
        }
        try JSONEncoder().encode(Legacy(customerID: fixture.customerID, draft: fixture.intent.draft,
            photos: [])).write(to: fixture.file)
        fixture.legacy.createResult = .success(.init(requestID: UUID(), matchCount: 2))
        let coordinator = fixture.coordinator()
        let accepted = try await coordinator.resume()
        guard case .legacy = accepted.acknowledgement else { Issue.record("Legacy receipt changed protocol"); return }
        #expect(fixture.legacy.receivedDrafts == [fixture.intent.draft])
        #expect(fixture.distribution.operations.isEmpty)
    }

    @Test func secondClickCannotReplaceAnUncertainIntent() throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let coordinator = fixture.coordinator()
        try coordinator.begin(fixture.intent)
        let replacement = PendingRequestPublication(customerID: fixture.customerID, draft: fixture.intent.draft,
            photos: [], session: fixture.intent.session, poolEnabled: true, groomerIDs: [])
        #expect(throws: RequestDiscoveryError.operationIntentChanged) { try coordinator.begin(replacement) }
        #expect(fixture.coordinator().pending == fixture.intent)
    }

    @Test func rejectedLegacyWriteReleasesOnlyAnUnacceptedIntent() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let legacy = PendingRequestPublication(customerID: fixture.customerID, draft: fixture.intent.draft, photos: [])
        try JSONEncoder().encode(legacy).write(to: fixture.file)
        fixture.legacy.createResult = .failure(.clientUpdateRequired)
        let coordinator = fixture.coordinator()
        await #expect(throws: CustomerRequestRepositoryError.clientUpdateRequired) { try await coordinator.resume() }
        #expect(coordinator.pending == nil)
        #expect(fixture.coordinator().pending == nil)
        #expect(fixture.distribution.operations.isEmpty)
    }

    @Test func lateAcknowledgementIsSavedOnlyForItsOwnerAndNeverPresentedToAnotherSession() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let coordinator = fixture.coordinator()
        var current = true
        coordinator.setSessionValidation { current }
        fixture.distribution.onPublish = { current = false }
        try coordinator.begin(fixture.intent)
        await #expect(throws: RequestDiscoveryError.cancelled) { try await coordinator.resume() }
        #expect(fixture.coordinator().pending?.acknowledgement?.requestID == fixture.distribution.receipt.requestID)
        let other = CustomerRequestPublicationCoordinator(customerID: UUID(), requestRepository: fixture.legacy,
            distributionRepository: fixture.distribution, storageDirectory: fixture.directory)
        #expect(other.pending == nil)
    }

    @Test func authoritativeRejectionReleasesTheIntentButNetworkFailureDoesNot() async throws {
        let fixture = try PublicationFixture()
        defer { fixture.clean() }
        let coordinator = fixture.coordinator()
        try coordinator.begin(fixture.intent)
        fixture.distribution.failure = .requestLimitExceeded
        await #expect(throws: RequestDiscoveryError.requestLimitExceeded) { try await coordinator.resume() }
        #expect(fixture.coordinator().pending == nil)
    }
}

@MainActor
private final class PublicationFixture {
    let customerID = UUID()
    let directory: URL
    let legacy = CustomerRequestRepositoryFake()
    let distribution = PublicationDistributionFake()
    let intent: PendingRequestPublication
    var file: URL { directory.appendingPathComponent("\(customerID.uuidString).json") }

    init(serviceNotes: String = "Calm handling") throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let draft = GroomingRequestDraft(petID: UUID(), serviceType: .fullGroom, serviceNotes: serviceNotes,
            preferredStart: Date().addingTimeInterval(7200), preferredEnd: Date().addingTimeInterval(14400),
            locationMode: .groomerComesToCustomer, streetAddress: "123 Main St", city: "Seattle", stateCode: .washington,
            zipCode: "98101", travelRadiusMiles: nil)
        intent = .init(customerID: customerID, draft: draft, photos: [.init(data: Data([1]), contentType: .png)],
            session: .init(id: UUID(), inputDigest: "immutable", expiresAt: Date().addingTimeInterval(-1)),
            groomerIDs: [UUID()])
    }
    func coordinator() -> CustomerRequestPublicationCoordinator {
        .init(customerID: customerID, requestRepository: legacy, distributionRepository: distribution, storageDirectory: directory)
    }
    func clean() { try? FileManager.default.removeItem(at: directory) }
}

@MainActor
final class PublicationDistributionFake: RequestDistributionRepository {
    let receipt = RequestDistributionReceipt(requestID: UUID(), termsRevision: UUID(), distributionRevision: UUID(),
        poolEnabled: false, invitedGroomerIDs: [])
    var operations: [UUID] = []
    var failure: RequestDiscoveryError?
    var onPublish: (() -> Void)?
    func publish(operationID: UUID, session: DiscoverySession, poolEnabled: Bool,
                 groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        operations.append(operationID)
        onPublish?()
        if let failure { throw failure }
        return receipt
    }
    func invite(operationID: UUID, requestID: UUID, expectedTermsRevision: UUID, groomerIDs: [UUID]) async throws -> RequestDistributionReceipt {
        throw RequestDiscoveryError.unavailable
    }
    func setPool(operationID: UUID, requestID: UUID, expectedRevision: UUID, enabled: Bool) async throws -> RequestDistributionReceipt {
        throw RequestDiscoveryError.unavailable
    }
    func withdrawInvitation(operationID: UUID, requestID: UUID, groomerID: UUID) async throws -> RequestDistributionReceipt {
        throw RequestDiscoveryError.unavailable
    }
    func progress(requestIDs: [UUID]) async throws -> [CustomerRequestProgress] { throw RequestDiscoveryError.unavailable }
}
