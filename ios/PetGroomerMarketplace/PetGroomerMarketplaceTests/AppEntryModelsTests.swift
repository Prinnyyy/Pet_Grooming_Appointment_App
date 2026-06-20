import Foundation
import Testing
@testable import PetGroomerMarketplace

struct AppEntryModelsTests {
    @Test
    func userRolesHaveExactOrderAndRoutes() {
        #expect(UserRole.allCases == [.customer, .groomer])
        #expect(UserRole.customer.entryRoute == .customer)
        #expect(UserRole.groomer.entryRoute == .groomer)
        #expect(UserRole.customer.id == .customer)
        #expect(UserRole.groomer.id == .groomer)
    }

    @Test
    func appEntryRoutesHaveExactOrderAndProductionDefault() {
        #expect(
            AppEntryRoute.allCases == [
                .authentication,
                .roleOnboarding,
                .customer,
                .groomer,
            ]
        )
        #expect(AppEntryRoute.productionDefault == .authentication)
        #expect(AppEntryRoute.authentication.id == .authentication)
    }
}

struct TabModelsTests {
    @Test
    func customerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(CustomerTab.allCases == [.home, .requests, .bookings, .messages, .account])
        #expect(CustomerTab.allCases.map(\.title) == ["Home", "Requests", "Bookings", "Messages", "Account"])
        #expect(CustomerTab.allCases.map(\.systemImage) == ["house", "list.bullet.clipboard", "calendar", "message", "person.crop.circle"])
        #expect(CustomerTab.allCases.allSatisfy { $0.id == $0 })
    }

    @Test
    func groomerTabsHaveExactOrderTitlesAndSymbols() {
        #expect(GroomerTab.allCases == [.requests, .offers, .bookings, .messages, .account])
        #expect(GroomerTab.allCases.map(\.title) == ["Requests", "Offers", "Bookings", "Messages", "Account"])
        #expect(GroomerTab.allCases.map(\.systemImage) == ["tray.full", "tag", "calendar", "message", "person.crop.circle"])
        #expect(GroomerTab.allCases.allSatisfy { $0.id == $0 })
    }
}

struct AuthenticationStoreTests {
    @Test @MainActor
    func restoresExistingSession() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        let store = AuthenticationStore(repository: repository)

        await store.start()

        #expect(store.rootState == .signedIn(session))
    }

    @Test @MainActor
    func startsSignedOutWithoutSession() async {
        let store = AuthenticationStore(
            repository: AuthSessionRepositoryFake()
        )

        await store.start()

        #expect(store.rootState == .signedOut)
    }

    @Test @MainActor
    func signUpConfirmationRemainsSignedOut() async {
        let repository = AuthSessionRepositoryFake()
        repository.signUpResult = .success(
            .confirmationRequired(email: "new@example.com")
        )
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.mode = .signUp
        store.email = " NEW@EXAMPLE.COM "
        store.password = "password"
        store.passwordConfirmation = "password"

        await store.submit()

        #expect(store.rootState == .signedOut)
        #expect(
            store.noticeMessage
                == "Check your email to confirm your account, then sign in."
        )
        #expect(repository.lastEmail == "new@example.com")
        #expect(store.password.isEmpty)
        #expect(store.passwordConfirmation.isEmpty)
    }

    @Test @MainActor
    func invalidCredentialsRemainRecoverable() async {
        let repository = AuthSessionRepositoryFake()
        repository.signInResult = .failure(.invalidCredentials)
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "user@example.com"
        store.password = "password"

        await store.submit()

        #expect(store.rootState == .signedOut)
        #expect(store.email == "user@example.com")
        #expect(store.password == "password")
        #expect(store.errorMessage == "The email or password is incorrect.")
        #expect(store.isSubmitting == false)
    }

    @Test @MainActor
    func invalidEmailDoesNotCallRepository() async {
        let repository = AuthSessionRepositoryFake()
        let store = AuthenticationStore(repository: repository)
        await store.start()
        store.email = "not-an-email"
        store.password = "password"

        await store.submit()

        #expect(repository.signInCallCount == 0)
        #expect(store.errorMessage == "Enter a valid email address.")
    }

    @Test @MainActor
    func signOutReturnsToSignedOutState() async {
        let session = AuthSessionSnapshot(
            userID: UUID(),
            email: "user@example.com"
        )
        let repository = AuthSessionRepositoryFake(currentSession: session)
        let store = AuthenticationStore(repository: repository)
        await store.start()

        await store.signOut()

        #expect(repository.signOutCallCount == 1)
        #expect(store.rootState == .signedOut)
    }
}

struct AuthenticatedEntryStoreTests {
    @Test @MainActor
    func missingProfileEntersOnboarding() async {
        let repository = ProfileRepositoryFake(
            profileResults: [.success(nil)]
        )
        let store = AuthenticatedEntryStore(repository: repository)

        await store.load(userID: UUID())

        #expect(store.state == .onboarding)
        #expect(repository.profileCallCount == 1)
    }

    @Test @MainActor
    func existingProfilesEnterTheirAuthoritativeRoutes() async {
        let customer = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Customer"
        )
        let groomer = MarketplaceProfile(
            userID: UUID(),
            role: .groomer,
            displayName: "Groomer"
        )
        let customerStore = AuthenticatedEntryStore(
            repository: ProfileRepositoryFake(
                profileResults: [.success(customer)]
            )
        )
        let groomerStore = AuthenticatedEntryStore(
            repository: ProfileRepositoryFake(
                profileResults: [.success(groomer)]
            )
        )

        await customerStore.load(userID: customer.userID)
        await groomerStore.load(userID: groomer.userID)

        #expect(customerStore.state == .customer(customer))
        #expect(groomerStore.state == .groomer(groomer))
    }

    @Test @MainActor
    func lookupFailureIsRetryableAndNeverBecomesMissing() async {
        let repository = ProfileRepositoryFake(
            profileResults: [
                .failure(.networkUnavailable),
                .success(nil),
            ]
        )
        let store = AuthenticatedEntryStore(repository: repository)

        await store.load(userID: UUID())
        #expect(
            store.state
                == .failure(
                    message: "We could not load your profile. Please try again."
                )
        )

        await store.retry()

        #expect(store.state == .onboarding)
        #expect(repository.profileCallCount == 2)
    }

    @Test @MainActor
    func invalidOnboardingInputDoesNotCallRepository() async {
        let repository = ProfileRepositoryFake()
        let store = AuthenticatedEntryStore(repository: repository)

        store.displayName = "   "
        store.selectedRole = .customer
        await store.submit()
        #expect(
            store.errorMessage
                == "Enter a display name between 1 and 80 characters."
        )

        store.displayName = "Valid name"
        store.selectedRole = nil
        await store.submit()
        #expect(
            store.errorMessage == "Choose Customer or Groomer to continue."
        )

        store.displayName = String(repeating: "a", count: 81)
        store.selectedRole = .groomer
        await store.submit()

        #expect(repository.createCallCount == 0)
    }

    @Test @MainActor
    func successfulCreationRoutesFromReturnedProfile() async {
        let authoritativeProfile = MarketplaceProfile(
            userID: UUID(),
            role: .groomer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake(
            createResult: .success(authoritativeProfile)
        )
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = " Alex "
        store.selectedRole = .customer

        await store.submit()

        #expect(store.state == .groomer(authoritativeProfile))
        #expect(repository.lastCreatedRole == .customer)
        #expect(repository.lastCreatedDisplayName == "Alex")
    }

    @Test @MainActor
    func failedCreationPreservesFormAndAllowsRetry() async {
        let profile = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake(
            createResult: .failure(.networkUnavailable)
        )
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = " Alex "
        store.selectedRole = .customer

        await store.submit()

        #expect(store.displayName == "Alex")
        #expect(store.selectedRole == .customer)
        #expect(store.isSubmitting == false)
        #expect(store.errorMessage == "Check your connection and try again.")

        repository.createResult = .success(profile)
        await store.submit()

        #expect(repository.createCallCount == 2)
        #expect(store.state == .customer(profile))
    }

    @Test @MainActor
    func duplicateSubmissionIsIgnored() async {
        let profile = MarketplaceProfile(
            userID: UUID(),
            role: .customer,
            displayName: "Alex"
        )
        let repository = ProfileRepositoryFake()
        repository.suspendCreate = true
        let store = AuthenticatedEntryStore(repository: repository)
        store.displayName = "Alex"
        store.selectedRole = .customer

        let firstSubmission = Task {
            await store.submit()
        }
        while repository.createCallCount == 0 {
            await Task.yield()
        }

        await store.submit()

        #expect(repository.createCallCount == 1)
        repository.resumeCreate(with: .success(profile))
        await firstSubmission.value
        #expect(store.state == .customer(profile))
    }
}

@MainActor
private final class ProfileRepositoryFake: ProfileRepository {
    var profileResults: [Result<MarketplaceProfile?, ProfileRepositoryError>]
    var createResult: Result<MarketplaceProfile, ProfileRepositoryError>
    var suspendCreate = false

    private(set) var profileCallCount = 0
    private(set) var createCallCount = 0
    private(set) var lastCreatedRole: UserRole?
    private(set) var lastCreatedDisplayName: String?

    private var createContinuation:
        CheckedContinuation<MarketplaceProfile, any Error>?

    init(
        profileResults: [Result<MarketplaceProfile?, ProfileRepositoryError>] = [],
        createResult: Result<MarketplaceProfile, ProfileRepositoryError> =
            .failure(.unavailable)
    ) {
        self.profileResults = profileResults
        self.createResult = createResult
    }

    func profile(userID: UUID) async throws -> MarketplaceProfile? {
        profileCallCount += 1
        guard !profileResults.isEmpty else { return nil }
        return try profileResults.removeFirst().get()
    }

    func createProfile(
        role: UserRole,
        displayName: String
    ) async throws -> MarketplaceProfile {
        createCallCount += 1
        lastCreatedRole = role
        lastCreatedDisplayName = displayName

        if suspendCreate {
            return try await withCheckedThrowingContinuation { continuation in
                createContinuation = continuation
            }
        }

        return try createResult.get()
    }

    func resumeCreate(
        with result: Result<MarketplaceProfile, ProfileRepositoryError>
    ) {
        createContinuation?.resume(with: result.mapError { $0 as any Error })
        createContinuation = nil
    }
}

@MainActor
private final class AuthSessionRepositoryFake: AuthSessionRepository {
    private let initialSession: AuthSessionSnapshot?
    private let stateStream: AsyncStream<AuthSessionSnapshot?>

    var signUpResult: Result<AuthSignUpOutcome, AuthSessionError> =
        .failure(.unavailable)
    var signInResult: Result<AuthSessionSnapshot, AuthSessionError> =
        .failure(.unavailable)
    var signOutResult: Result<Void, AuthSessionError> = .success(())

    private(set) var lastEmail: String?
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0

    init(
        currentSession: AuthSessionSnapshot? = nil,
        stateChanges: [AuthSessionSnapshot?] = []
    ) {
        initialSession = currentSession
        stateStream = AsyncStream { continuation in
            for state in stateChanges {
                continuation.yield(state)
            }
            continuation.finish()
        }
    }

    func currentSession() -> AuthSessionSnapshot? {
        initialSession
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        stateStream
    }

    func signUp(
        email: String,
        password: String
    ) async throws -> AuthSignUpOutcome {
        lastEmail = email
        return try signUpResult.get()
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSessionSnapshot {
        signInCallCount += 1
        lastEmail = email
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        try signOutResult.get()
    }
}
