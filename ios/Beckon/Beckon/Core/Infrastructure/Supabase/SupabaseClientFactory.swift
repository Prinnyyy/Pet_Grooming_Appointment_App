import Supabase

enum SupabaseClientFactory {
    static let options = SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )

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
