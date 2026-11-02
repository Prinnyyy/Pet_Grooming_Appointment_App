import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class LaunchRoleHandoffTests: XCTestCase {
    func testSignedInProfileReadDoesNotReleaseTheLaunchUntilItsRouteIsKnown() async throws {
        let customer = CustomerSandboxSession(screen: .onboarding)
        defer { customer.invalidate() }
        customer.authentication.rootState = .signedIn(customer.authSession)
        let groomer = GroomerSandboxSession(state: .empty)
        let repository = WaitingRoleProfileRepository()
        let readiness = RoleReadinessObservation()
        let entry = AuthenticatedEntryView(session: customer.authSession, authenticationStore: customer.authentication,
            profileRepository: repository, customerProfileRepository: customer.accountRepository,
            customerPetRepository: customer.pets.repository, customerRequestRepository: customer.marketplaceRepository,
            customerNotificationRepository: customer.notificationRepository, bookingRepository: customer.bookingRepository,
            chatRepository: customer.chatRepository, groomerProfileRepository: groomer.profileRepository,
            groomerRequestRepository: groomer.requestRepository, groomerNotificationRepository: groomer.notificationRepository)
        let root = UIHostingController(rootView: RoleReadinessProbe(entry: entry, observation: readiness)
            .environment(\.scenePhase, .active))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root; window.makeKeyAndVisible()
        defer { repository.boundary.release(); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(6))
        while !repository.readStarted, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(repository.readStarted)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(readiness.ready, "The account-loading placeholder must not dismiss the launch artwork")
        repository.boundary.release()
        let released = ContinuousClock.now.advanced(by: .seconds(2))
        while !readiness.ready, ContinuousClock.now < released { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertTrue(readiness.ready, "A resolved onboarding destination must become actionable")
    }
}

@MainActor @Observable private final class RoleReadinessObservation { var ready = false }

private struct RoleReadinessProbe: View {
    let entry: AuthenticatedEntryView
    let observation: RoleReadinessObservation
    var body: some View {
        LaunchGate(isReady: observation.ready) {
            entry.onPreferenceChange(LaunchReadyKey.self) { observation.ready = $0 }
        }
    }
}

@MainActor private final class WaitingRoleProfileRepository: ProfileRepository {
    let boundary = GroomerSandboxBoundary(isHeld: true)
    private(set) var readStarted = false
    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        readStarted = true
        try await boundary.check()
        return nil
    }
    func createProfile(role: UserRole, displayName: String) async throws -> MarketplaceProfile {
        throw ProfileRepositoryError.unavailable
    }
}
