import SwiftUI

struct DebugPanelView: View {
    let diagnostics: DebugDiagnostics

    var body: some View {
        List {
            Section("Runtime") {
                row("Build", diagnostics.buildConfiguration)
                row("Bundle", diagnostics.bundleIdentifier)
                row("Role", diagnostics.role)
                row("User ref", diagnostics.userReference)

                if let emailDomain = diagnostics.emailDomain {
                    row("Email domain", emailDomain)
                }
            }

            Section("Supabase") {
                row("URL scheme", diagnostics.supabaseScheme)
                row("Host", diagnostics.supabaseHost)
                row("Publishable key", diagnostics.publishableKeyStatus)
            }

            Section("Safety") {
                Label(
                    diagnostics.sensitiveDataNotice,
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
        }
        .navigationTitle("Debug Panel")
        .accessibilityIdentifier("debug.panel")
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugPanelView(
            diagnostics: DebugDiagnostics.make(
                session: AuthSessionSnapshot(
                    userID: UUID(),
                    email: "owner@example.com"
                ),
                profile: MarketplaceProfile(
                    userID: UUID(),
                    role: .customer,
                    displayName: "Owner"
                ),
                configuration: nil,
                bundleIdentifier: "com.prinnyyy.PetGroomerMarketplace",
                buildConfiguration: "Debug"
            )
        )
    }
}
#endif
