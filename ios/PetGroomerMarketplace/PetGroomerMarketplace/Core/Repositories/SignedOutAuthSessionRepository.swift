import Foundation

@MainActor
final class SignedOutAuthSessionRepository: AuthSessionRepository {
    func currentSession() -> AuthSessionSnapshot? {
        nil
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func signUp(
        email: String,
        password: String
    ) async throws -> AuthSignUpOutcome {
        throw AuthSessionError.unavailable
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSessionSnapshot {
        throw AuthSessionError.unavailable
    }

    func signOut() async throws {}
}
