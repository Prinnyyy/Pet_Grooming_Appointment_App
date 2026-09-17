import Foundation

struct DebugDiagnostics: Equatable, Sendable {
    let buildConfiguration: String
    let bundleIdentifier: String
    let role: String
    let userReference: String
    let emailDomain: String?
    let supabaseScheme: String
    let supabaseHost: String
    let publishableKeyStatus: String
    let sensitiveDataNotice: String

    static func current(
        session: AuthSessionSnapshot,
        profile: MarketplaceProfile,
        bundle: Bundle = .main
    ) -> Self {
        let configuration = try? SupabaseConfiguration.load(from: bundle)

        return make(
            session: session,
            profile: profile,
            configuration: configuration,
            bundleIdentifier: bundle.bundleIdentifier,
            buildConfiguration: buildConfigurationName
        )
    }

    static func make(
        session: AuthSessionSnapshot,
        profile: MarketplaceProfile,
        configuration: SupabaseConfiguration?,
        bundleIdentifier: String?,
        buildConfiguration: String
    ) -> Self {
        Self(
            buildConfiguration: buildConfiguration,
            bundleIdentifier: bundleIdentifier ?? "Unavailable",
            role: profile.role.title,
            userReference: supportReference(for: profile.userID),
            emailDomain: domain(from: session.email),
            supabaseScheme: configuration?.url.scheme ?? "Unavailable",
            supabaseHost: configuration?.url.host ?? "Unavailable",
            publishableKeyStatus: configuration == nil
                ? "Missing or invalid"
                : "Configured; value hidden",
            sensitiveDataNotice:
                "No tokens, passwords, refresh tokens, or full API keys are displayed."
        )
    }

    private static var buildConfigurationName: String {
        #if DEBUG
        "Debug"
        #else
        "Release"
        #endif
    }

    private static func supportReference(for id: UUID) -> String {
        String(id.uuidString.prefix(8)).uppercased()
    }

    private static func domain(from email: String?) -> String? {
        guard let email else { return nil }
        let pieces = email.split(separator: "@", maxSplits: 1)
        guard pieces.count == 2 else { return nil }
        return String(pieces[1]).lowercased()
    }
}
