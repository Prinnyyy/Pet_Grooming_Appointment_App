import Foundation

struct AuthSessionSnapshot: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let isExpired: Bool

    init(
        userID: UUID,
        email: String?,
        isExpired: Bool = false
    ) {
        self.userID = userID
        self.email = email
        self.isExpired = isExpired
    }
}

enum AuthSignUpOutcome: Equatable, Sendable {
    case signedIn(AuthSessionSnapshot)
    case confirmationRequired(email: String)
}

enum AuthSessionError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailNotConfirmed
    case weakPassword
    case rateLimited
    case networkUnavailable
    case accountDeletionFailed
    case invalidCallback
    case unavailable
}

@MainActor
protocol AuthSessionRepository: AnyObject {
    func requestPasswordRecovery(email: String, redirectTo: URL) async throws
    func recoverySession() -> AuthSessionSnapshot?
    func handleRecoveryCallback(_ url: URL) async throws -> AuthSessionSnapshot
    func updateRecoveredPassword(_ password: String, userID: UUID) async throws
    func endPasswordRecovery() async throws
    func currentSession() -> AuthSessionSnapshot?
    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?>
    func signUp(
        email: String,
        password: String,
        redirectTo: URL?
    ) async throws -> AuthSignUpOutcome
    func handleAuthCallback(_ url: URL) async throws -> AuthSessionSnapshot
    func signIn(email: String, password: String) async throws -> AuthSessionSnapshot
    func signOut() async throws
    func deleteAccount() async throws
}

extension AuthSessionRepository {
    func requestPasswordRecovery(email: String, redirectTo: URL) async throws { throw AuthSessionError.unavailable }
    func recoverySession() -> AuthSessionSnapshot? { nil }
    func handleRecoveryCallback(_ url: URL) async throws -> AuthSessionSnapshot { throw AuthSessionError.invalidCallback }
    func updateRecoveredPassword(_ password: String, userID: UUID) async throws { throw AuthSessionError.invalidCallback }
    func endPasswordRecovery() async throws {}
}
