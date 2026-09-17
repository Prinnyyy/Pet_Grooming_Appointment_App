import Foundation
import Supabase

enum SupabaseClientFactory {
    static let options = SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true),
        global: .init(session: session)
    )

    private static var session: URLSession {
        #if DEBUG && targetEnvironment(simulator)
        if let metrics = TestOpsHTTPMetrics(arguments: ProcessInfo.processInfo.arguments) {
            return URLSession(configuration: .default, delegate: metrics, delegateQueue: nil)
        }
        #endif
        return .shared
    }

    static func make(configuration: SupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: options
        )
    }

    static func makeRecovery(configuration: SupabaseConfiguration) -> SupabaseClient {
        SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(auth: .init(
                redirectToURL: AuthCallbackConfiguration.recoveryURL,
                storageKey: "beckon.password-recovery.v1", flowType: .pkce,
                autoRefreshToken: false, emitLocalSessionAsInitialSession: true)))
    }
}
