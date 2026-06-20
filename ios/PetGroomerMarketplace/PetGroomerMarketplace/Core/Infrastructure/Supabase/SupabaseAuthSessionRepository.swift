import Foundation
import Supabase

@MainActor
final class SupabaseAuthSessionRepository: AuthSessionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentSession() -> AuthSessionSnapshot? {
        client.auth.currentSession.map(Self.snapshot)
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        let authStateChanges = await client.auth.authStateChanges

        return AsyncStream { continuation in
            let task = Task { @MainActor in
                for await (_, session) in authStateChanges {
                    continuation.yield(
                        session.map(Self.snapshot)
                    )
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func signUp(
        email: String,
        password: String
    ) async throws -> AuthSignUpOutcome {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )

            if let session = response.session {
                return .signedIn(Self.snapshot(from: session))
            }

            return .confirmationRequired(
                email: response.user.email?.lowercased() ?? email
            )
        } catch {
            throw Self.map(error)
        }
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSessionSnapshot {
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            return Self.snapshot(from: session)
        } catch {
            throw Self.map(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            throw Self.map(error)
        }
    }

    private static func snapshot(from session: Session) -> AuthSessionSnapshot {
        AuthSessionSnapshot(
            userID: session.user.id,
            email: session.user.email?.lowercased()
        )
    }

    private static func map(_ error: any Error) -> AuthSessionError {
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .invalidCredentials:
                return .invalidCredentials
            case .emailNotConfirmed:
                return .emailNotConfirmed
            case .weakPassword:
                return .weakPassword
            case .overRequestRateLimit, .overEmailSendRateLimit:
                return .rateLimited
            case .requestTimeout:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }
}
