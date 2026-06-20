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
