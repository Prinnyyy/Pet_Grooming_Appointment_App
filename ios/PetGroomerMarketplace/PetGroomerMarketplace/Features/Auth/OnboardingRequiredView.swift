import SwiftUI

struct OnboardingRequiredView: View {
    let session: AuthSessionSnapshot
    @Bindable var store: AuthenticationStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.large) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text("Account confirmed")
                        .font(.title.bold())
                        .foregroundStyle(DesignTokens.Colors.primaryText)

                    Text("Choose your Customer or Groomer role in the next setup step.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)

                    if let email = session.email {
                        Text(email)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }

                    if let errorMessage = store.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("auth.error")
                    }

                    Button(role: .destructive) {
                        Task {
                            await store.signOut()
                        }
                    } label: {
                        HStack {
                            if store.isSubmitting {
                                ProgressView()
                            }
                            Text(store.isSubmitting ? "Signing out…" : "Sign Out")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
                .padding(DesignTokens.Spacing.large)
                .background(DesignTokens.Colors.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                )
                .padding(DesignTokens.Spacing.standard)
            }
            .navigationTitle("Role setup required")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("auth.onboarding-required")
    }
}
