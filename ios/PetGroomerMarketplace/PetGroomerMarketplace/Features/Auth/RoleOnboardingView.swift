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
                    .padding(DesignTokens.Spacing.standard)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Set up your profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("profile.onboarding")
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.standard) {
            Image(systemName: "person.2.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("How will you use the marketplace?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if let email = session.email {
                Text(email)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
        }
        .padding(.top, DesignTokens.Spacing.standard)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.standard) {
            TextField("Display name", text: $store.displayName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .disabled(store.isSubmitting)
                .accessibilityIdentifier("profile.display-name")

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

            Label(
                "Your role cannot be changed through the normal app.",
                systemImage: "lock"
            )
            .font(.footnote)
            .foregroundStyle(DesignTokens.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("profile.error")
            }

            Button {
                Task {
                    await store.submit()
                }
            } label: {
                HStack {
                    if store.isSubmitting {
                        ProgressView()
                    }
                    Text(store.isSubmitting ? "Creating profile…" : "Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("profile.submit")

            Button("Sign Out", role: .destructive, action: onSignOut)
                .disabled(store.isSubmitting)
                .accessibilityIdentifier("auth.sign-out")
        }
        .textFieldStyle(.roundedBorder)
        .padding(DesignTokens.Spacing.standard)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
        )
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
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if store.selectedRole == role {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(DesignTokens.Spacing.standard)
            .background(DesignTokens.Colors.background)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                    .stroke(
                        store.selectedRole == role ? Color.accentColor : .clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(store.isSubmitting)
        .accessibilityIdentifier("profile.role.\(role.rawValue)")
    }
}
