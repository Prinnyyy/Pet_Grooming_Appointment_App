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
}
