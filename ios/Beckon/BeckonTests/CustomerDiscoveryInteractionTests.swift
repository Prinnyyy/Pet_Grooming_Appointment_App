import SwiftUI
import UIKit
import XCTest
@testable import Beckon

// Opt-in, local-only host for semantic Simulator interaction with production views.
// The marker lives in the simulator app's Documents directory, never in a release route.
@MainActor
final class CustomerDiscoveryInteractionTests: XCTestCase {
    func testLocalInteraction() async throws {
        let marker = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("t401-interaction.json")
        let environment = ProcessInfo.processInfo.environment
        if environment["BECKON_LOCAL_INTERACTION"] == "1" || environment["TEST_RUNNER_BECKON_LOCAL_INTERACTION"] == "1" {
            try Data(#"{"wizard":false,"largeText":false,"count":8,"measureMotion":true}"#.utf8).write(to: marker)
        }
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw XCTSkip("Opt-in Simulator interaction fixture not configured")
        }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: marker))
        defer { try? FileManager.default.removeItem(at: marker) }
        let customerID = UUID()
        let discovery = DiscoveryRepositoryFake()
        let items: [DiscoveredGroomer] = (1...8).map { index in
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
            let name = index == 1 ? "Willow & Wash Mobile Grooming" : "Local Groomer \(index)"
            let bio: String? = index == 1 ? String(repeating: "Patient, one-on-one grooming. Please share your pet's coat and comfort needs. ", count: 6) : nil
            let profile = MarketplaceGroomerSummary(id: id, businessName: name, bio: bio)
            let eligibility = MatchEligibilityEvaluation(state: "estimated_fit", reason: nil, serviceStart: nil, serviceEnd: nil)
            return DiscoveredGroomer(profile: profile, eligibility: eligibility,
                matchingEvidence: nil, distanceMiles: Double(index), referencePrice: nil,
                favoriteState: .init(isFavorite: false, revision: nil), invitationState: .notSent)
        }
        let page = RankedPage(items: Array(items.prefix(config.count ?? 8)), rankingRevision: "local", scoreAsOf: Date(),
            validUntil: .distantFuture, algorithmVersion: "matching-v1", requestedMode: "fit", effectiveMode: "fit",
            pendingCount: 0, assessmentCount: 0, nextCursor: nil)
        discovery.pages = Array(repeating: .success(page), count: 12)
        let distribution = PublicationDistributionFake()
        let favorites = FavoritesRepositoryFake()
        let repository = CustomerRequestRepositoryFake()
        let marketplace = CustomerMarketplaceSession(customerID: customerID, requestRepository: repository,
            services: .init(discovery: discovery, distribution: distribution, favorites: favorites, images: DiscoveryImageFake()),
            sessionIsCurrent: { true })
        let pets: [CustomerPet] = (1...4).map { index in
            let id = UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", index))!
            let name = index == 1 ? "Sir Bartholomew Wellington the Third" : "Mochi \(index)"
            let breed: String? = index == 1 ? "Australian Shepherd / Standard Poodle Mix" : nil
            return CustomerPet(id: id,
                customerID: customerID, name: name,
                species: "Dog", breed: breed,
                coatType: nil, size: "L", weightLbs: index == 1 ? 72.5 : nil, birthday: nil,
                temperament: nil, medicalNotes: nil, groomingNotes: nil, isActive: true)
        }
        let store = CustomerRequestsStore(customerID: customerID,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success(pets)),
            requestRepository: repository, bookingRepository: CustomerRequestBookingRepositoryFake(), marketplace: marketplace)
        await store.load()
        store.wizardInitialStep = CustomerRequestWizardStep(rawValue: config.step ?? 0) ?? .pet
        let flow = CustomerRequestDiscoveryFlow(store: .init(scope: .preview(sessionID: UUID(), inputDigest: "local"), repository: discovery))
        await flow.store.load()
        let session = InteractionSession(config: config)
        let host = UIHostingController(rootView: InteractionHost(session: session,
            store: store, flow: flow, marketplace: marketplace))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = InteractionWindow(windowScene: scene)
        window.session = session
        host.view.accessibilityViewIsModal = true
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for _ in 0..<1200 where !session.finished {
            try await Task.sleep(for: .milliseconds(500))
            if let data = try? Data(contentsOf: marker),
               let updated = try? JSONDecoder().decode(Configuration.self, from: data), updated != session.config {
                store.wizardInitialStep = CustomerRequestWizardStep(rawValue: updated.step ?? 0) ?? .pet
                session.lastRelease = nil
                session.config = updated
            }
        }
        XCTAssertTrue(session.finished, "Finish the semantic Simulator interaction before timeout")
        XCTAssertEqual(distribution.operations.count, 0, "Browsing/cancelling must not publish")
        XCTAssertEqual(repository.createCallCount, 0)
        XCTAssertFalse(flow.poolEnabled)
        if !session.settleDurations.isEmpty {
            XCTAssertLessThanOrEqual(session.settleDurations.max() ?? 0, 0.5)
            print("T401 animation completions: \(session.settleDurations.count), max seconds: \(session.settleDurations.max() ?? 0)")
        }
        let metrics = marker.deletingLastPathComponent().appendingPathComponent("t401-motion-metrics.json")
        try JSONEncoder().encode(session.settleDurations).write(to: metrics)
    }

    struct Configuration: Decodable, Equatable {
        let wizard: Bool
        let largeText: Bool
        let count: Int?
        let step: Int?
        let measureMotion: Bool?
    }

    @Observable final class InteractionSession {
        var finished = false
        var config: Configuration
        var lastRelease: TimeInterval?
        var settleDurations: [TimeInterval] = []
        init(config: Configuration) { self.config = config }
    }

    final class InteractionWindow: UIWindow {
        var session: InteractionSession?
        override func sendEvent(_ event: UIEvent) {
            if event.allTouches?.contains(where: { $0.phase == .ended }) == true {
                session?.lastRelease = ProcessInfo.processInfo.systemUptime
            }
            super.sendEvent(event)
        }
    }

    struct InteractionHost: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let session: InteractionSession
        let store: CustomerRequestsStore
        let flow: CustomerRequestDiscoveryFlow
        let marketplace: CustomerMarketplaceSession
        var body: some View {
            VStack(spacing: 0) {
                Button("Finish Local Check") { session.finished = true }
                    .accessibilityIdentifier("local.finish")
                    .accessibilityValue(reduceMotion ? "reduced motion" : "normal motion")
                    .font(.caption).dynamicTypeSize(.large).frame(height: 32)
                if session.config.wizard {
                    CustomerRequestWizardView(store: store)
                        .id(session.config.step)
                } else {
                    NavigationStack { CustomerGroomerDiscoveryView(flow: flow, requests: store, marketplace: marketplace) }
                }
            }
            .environment(\.dynamicTypeSize, session.config.largeText ? .accessibility5 : .large)
            .onChange(of: flow.store.deckSelection) { _, _ in
                if session.config.measureMotion == true, let released = session.lastRelease {
                    let elapsed = ProcessInfo.processInfo.systemUptime - released
                    session.settleDurations.append(elapsed)
                    session.lastRelease = nil
                }
            }
        }
    }
}
