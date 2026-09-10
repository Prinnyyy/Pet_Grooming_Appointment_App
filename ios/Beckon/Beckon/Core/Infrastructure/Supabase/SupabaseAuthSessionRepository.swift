import Foundation
import Supabase

@MainActor
final class SupabaseAuthSessionRepository: AuthSessionRepository {
    private let client: SupabaseClient
    private let recoveryClient: SupabaseClient?

    init(client: SupabaseClient, recoveryClient: SupabaseClient? = nil) {
        self.client = client
        self.recoveryClient = recoveryClient
    }

    func requestPasswordRecovery(email: String, redirectTo: URL) async throws {
        guard let recoveryClient, redirectTo == AuthCallbackConfiguration.recoveryURL else { throw AuthSessionError.unavailable }
        do { try await recoveryClient.auth.resetPasswordForEmail(email, redirectTo: redirectTo) }
        catch let error as AuthError where error.errorCode == .userNotFound { return }
        catch { throw Self.map(error) }
    }

    func recoverySession() -> AuthSessionSnapshot? { recoveryClient?.auth.currentSession.map(Self.snapshot) }

    func handleRecoveryCallback(_ url: URL) async throws -> AuthSessionSnapshot {
        guard let recoveryClient, AuthCallbackConfiguration.isRecoveryCallback(url),
              AuthCallbackConfiguration.callbackErrorParameters(from: url).isEmpty else { throw AuthSessionError.invalidCallback }
        do {
            let session = try await recoveryClient.auth.session(from: url)
            guard !session.isExpired else { throw AuthSessionError.invalidCallback }
            return Self.snapshot(from: session)
        } catch { throw Self.mapCallback(error) }
    }

    func updateRecoveredPassword(_ password: String, userID: UUID) async throws {
        guard let recoveryClient, let session = recoveryClient.auth.currentSession,
              !session.isExpired, session.user.id == userID else { throw AuthSessionError.invalidCallback }
        do {
            let user = try await recoveryClient.auth.update(user: UserAttributes(password: password))
            guard user.id == userID else { throw AuthSessionError.invalidCallback }
        } catch let error as AuthSessionError { throw error }
        catch { throw Self.map(error) }
    }

    func endPasswordRecovery() async throws {
        guard let recoveryClient else { return }
        do { try await recoveryClient.auth.signOut(scope: .local) }
        catch { throw Self.map(error) }
    }

    func currentSession() -> AuthSessionSnapshot? {
        client.auth.currentSession.map(Self.snapshot)
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        let authStateChanges = client.auth.authStateChanges

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
        password: String,
        redirectTo: URL?
    ) async throws -> AuthSignUpOutcome {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirectTo
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

    func handleAuthCallback(_ url: URL) async throws -> AuthSessionSnapshot {
        do {
            let session = try await client.auth.session(from: url)
            return Self.snapshot(from: session)
        } catch {
            throw Self.mapCallback(error)
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

    func deleteAccount() async throws {
        do {
            try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(method: .post)
            )
        } catch {
            throw Self.mapAccountDeletion(error)
        }
    }

    private static func snapshot(from session: Session) -> AuthSessionSnapshot {
        AuthSessionSnapshot(
            userID: session.user.id,
            email: session.user.email?.lowercased(),
            isExpired: session.isExpired
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

    private static func mapCallback(
        _ error: any Error
    ) -> AuthSessionError {
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
                return .invalidCallback
            }
        }

        return .invalidCallback
    }

    private static func mapAccountDeletion(
        _ error: any Error
    ) -> AuthSessionError {
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
                return .accountDeletionFailed
            }
        }

        return .accountDeletionFailed
    }
}
