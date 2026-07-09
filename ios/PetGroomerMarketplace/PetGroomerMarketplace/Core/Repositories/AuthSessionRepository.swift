import Foundation

struct AuthSessionSnapshot: Equatable, Sendable {
    let userID: UUID
    let email: String?
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
