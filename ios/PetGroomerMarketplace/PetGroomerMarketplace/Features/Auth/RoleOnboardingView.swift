import SwiftUI

struct RoleOnboardingView: View {
    let session: AuthSessionSnapshot
    @Bindable var store: AuthenticatedEntryStore
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.large) {
                        header
                        form
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Set up your profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("profile.onboarding")
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "person.2.circle.fill")
                .font(DesignTokens.Typography.largeTitle.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(
                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg,
                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                )
                .background(DesignTokens.Colors.customerPrimary.opacity(0.16))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Set up Groomly")
                    .font(DesignTokens.Typography.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text("Choose the role that matches how you will use the app.")
                    .font(DesignTokens.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if let email = session.email {
                Text(email)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.chip)
            }
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            GroomlyCard {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    TextField("Display name", text: $store.displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .disabled(store.isSubmitting)
                        .groomlyFormField()
                        .accessibilityIdentifier("profile.display-name")

                    VStack(spacing: DesignTokens.Spacing.md) {
                        roleButton(
                            role: .customer,
                            title: "I am a pet owner",
                            systemImage: "pawprint"
                        )

                        roleButton(
                            role: .groomer,
                            title: "I am a groomer",
                            systemImage: "scissors"
                        )
                    }

                    Label(
                        "Your role cannot be changed through the normal app.",
                        systemImage: "lock"
                    )
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task {
                            await store.submit()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if store.isSubmitting {
                                ProgressView()
                                    .tint(DesignTokens.Colors.surface)
                            }
                            Text(store.isSubmitting ? "Creating profile…" : "Continue")
                        }
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle())
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("profile.submit")

                    Button(role: .destructive, action: onSignOut) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
            }

            if let errorMessage = store.errorMessage {
                GroomlyErrorBanner(
                    title: "Profile setup error",
                    message: errorMessage
                )
                .accessibilityIdentifier("profile.error")
            }
        }
    }

    private func roleButton(
        role: UserRole,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            store.selectedRole = role
            store.errorMessage = nil
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Label(title, systemImage: systemImage)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(roleForeground(role))
                Spacer()
                if store.selectedRole == role {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(roleForeground(role))
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(roleBackground(role))
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .stroke(
                        roleBorder(role),
                        lineWidth: store.selectedRole == role ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(store.isSubmitting)
        .accessibilityIdentifier("profile.role.\(role.rawValue)")
    }

    private func roleForeground(_ role: UserRole) -> Color {
        switch role {
        case .customer:
            store.selectedRole == role ? DesignTokens.Colors.customerPrimaryDark : DesignTokens.Colors.textPrimary
        case .groomer:
            store.selectedRole == role ? DesignTokens.Colors.groomerAccentDark : DesignTokens.Colors.textPrimary
        }
    }

    private func roleBackground(_ role: UserRole) -> Color {
        switch role {
        case .customer:
            store.selectedRole == role ? DesignTokens.Colors.customerPrimary.opacity(0.14) : DesignTokens.Colors.appBackground
        case .groomer:
            store.selectedRole == role ? DesignTokens.Colors.groomerAccent.opacity(0.14) : DesignTokens.Colors.appBackground
        }
    }

    private func roleBorder(_ role: UserRole) -> Color {
        guard store.selectedRole == role else {
            return DesignTokens.Colors.borderSoft
        }

        switch role {
        case .customer:
            return DesignTokens.Colors.customerPrimary
        case .groomer:
            return DesignTokens.Colors.groomerAccent
        }
    }
}
