import SwiftUI

nonisolated enum RoleOnboardingFocusTarget: String, Hashable {
    case displayName = "profile.display-name.container"
}

struct RoleOnboardingView: View {
    let session: AuthSessionSnapshot
    @Bindable var store: AuthenticatedEntryStore
    let onSignOut: () -> Void
    @FocusState private var focusedField: RoleOnboardingFocusTarget?

    var body: some View {
        NavigationStack {
            ZStack {
                BeckonExpressiveBackdrop()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        BeckonCascade(alignment: .center, spacing: DesignTokens.Spacing.large) {
                            header
                            form
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.vertical, DesignTokens.Spacing.xl)
                    }
                    .beckonKeyboardAvoidance(
                        focusedTarget: focusedField?.rawValue,
                        using: scrollProxy
                    )
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .beckonEntranceRhythm(.detail)
        .environment(\.beckonCustomerDesign, true)
            .navigationTitle("Set up your profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("profile.onboarding")
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "person.2.circle.fill")
                .font(DesignTokens.Typography.largeTitle.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(
                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg,
                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                )
                .background(DesignTokens.Colors.customerTint)
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Set up Beckon")
                    .font(DesignTokens.Typography.Expressive.display)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Choose the role that matches how you will use the app.")
                    .font(DesignTokens.Typography.Expressive.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            if let email = session.email {
                Text(email)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.customerTint)
                    .clipShape(DesignTokens.Shapes.chip)
            }
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            BeckonCard {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    TextField("Display name", text: $store.displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .disabled(store.isSubmitting)
                        .focused($focusedField, equals: .displayName)
                        .beckonFormField()
                        .accessibilityIdentifier("profile.display-name")
                        .beckonKeyboardFocusTarget(
                            RoleOnboardingFocusTarget.displayName.rawValue
                        )

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
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task {
                            await store.submit()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if store.isSubmitting {
                                ProgressView()
                                    .tint(DesignTokens.Colors.customerInk)
                            }
                            Text(store.isSubmitting ? "Creating profile…" : "Continue")
                        }
                    }
                    .buttonStyle(BeckonPrimaryButtonStyle())
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("profile.submit")

                    Button(role: .destructive, action: onSignOut) {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
            }

            if let errorMessage = store.errorMessage {
                BeckonErrorBanner(
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
                    .font(DesignTokens.Typography.Expressive.headline)
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
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .strokeBorder(
                        roleBorder(role),
                        lineWidth: store.selectedRole == role ? DesignTokens.Ledge.edgeWidth + 1 : DesignTokens.Ledge.edgeWidth
                    )
            }
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .disabled(store.isSubmitting)
        .accessibilityIdentifier("profile.role.\(role.rawValue)")
    }

    private func roleForeground(_ role: UserRole) -> Color {
        switch role {
        case .customer:
            store.selectedRole == role ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.textPrimary
        case .groomer:
            store.selectedRole == role ? DesignTokens.Colors.groomerDeep : DesignTokens.Colors.textPrimary
        }
    }

    private func roleBackground(_ role: UserRole) -> Color {
        switch role {
        case .customer:
            store.selectedRole == role ? DesignTokens.Colors.customerTint : DesignTokens.Colors.appBackground
        case .groomer:
            store.selectedRole == role ? DesignTokens.Colors.groomerTint : DesignTokens.Colors.appBackground
        }
    }

    private func roleBorder(_ role: UserRole) -> Color {
        guard store.selectedRole == role else {
            return DesignTokens.Colors.borderSoft
        }

        switch role {
        case .customer:
            return DesignTokens.Colors.customerDeep
        case .groomer:
            return DesignTokens.Colors.groomerDeep
        }
    }
}
