import SwiftUI

struct DebugPanelView: View {
    let diagnostics: DebugDiagnostics

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    DebugPanelSection(title: "Runtime") {
                        row("Build", diagnostics.buildConfiguration)
                        row("Bundle", diagnostics.bundleIdentifier)
                        row("Role", diagnostics.role)
                        row("User ref", diagnostics.userReference)

                        if let emailDomain = diagnostics.emailDomain {
                            row("Email domain", emailDomain)
                        }
                    }

                    DebugPanelSection(title: "Supabase") {
                        row("URL scheme", diagnostics.supabaseScheme)
                        row("Host", diagnostics.supabaseHost)
                        row("Publishable key", diagnostics.publishableKeyStatus)
                    }

                    DebugPanelSection(title: "Safety") {
                        Label(
                            diagnostics.sensitiveDataNotice,
                            systemImage: "lock.shield"
                        )
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("Debug Panel")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("debug.panel")
    }

    private func row(_ title: String, _ value: String) -> some View {
        DebugPanelRow(title: title, value: value)
    }
}

private struct DebugPanelSection<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GroomlySectionHeader(title)

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    content
                }
            }
        }
    }
}

private struct DebugPanelRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Text(value)
                .font(DesignTokens.Typography.body.monospaced())
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
