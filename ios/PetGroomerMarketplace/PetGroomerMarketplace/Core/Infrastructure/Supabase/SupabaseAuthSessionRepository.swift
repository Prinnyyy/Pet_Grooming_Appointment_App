import Supabase

@MainActor
final class SupabaseAuthSessionRepository: AuthSessionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentSession() -> AuthSessionSnapshot? {
        client.auth.currentSession.map {
            AuthSessionSnapshot(userID: $0.user.id)
        }
    }

    func sessionStateChanges() async -> AsyncStream<AuthSessionSnapshot?> {
        let authStateChanges = await client.auth.authStateChanges

        return AsyncStream { continuation in
            let task = Task { @MainActor in
                for await (_, session) in authStateChanges {
                    continuation.yield(
                        session.map { AuthSessionSnapshot(userID: $0.user.id) }
                    )
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
