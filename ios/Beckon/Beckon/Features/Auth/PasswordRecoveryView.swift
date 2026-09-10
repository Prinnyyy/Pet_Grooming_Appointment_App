import SwiftUI

struct PasswordRecoveryView: View {
    @Bindable var store: AuthenticationStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    switch store.recoveryState {
                    case let .newPassword(session):
                        Text("New Password").font(DesignTokens.Typography.featureTitle)
                        if let email = session.email { Text(email).foregroundStyle(.secondary) }
                        SecureField("New password", text: $store.recoveryPassword)
                            .textContentType(.newPassword).beckonFormField()
                            .accessibilityIdentifier("auth.recovery.password")
                        SecureField("Confirm password", text: $store.recoveryPasswordConfirmation)
                            .textContentType(.newPassword).beckonFormField()
                            .accessibilityIdentifier("auth.recovery.confirmation")
                        Button("Save Password", systemImage: "checkmark") {
                            Task { await store.saveRecoveredPassword() }
                        }.buttonStyle(BeckonPrimaryButtonStyle())
                    case .complete:
                        Label("Password Changed", systemImage: "checkmark.circle").font(DesignTokens.Typography.sectionTitle)
                        Text("Use your new password the next time you sign in.")
                        Button("Done", systemImage: "checkmark") { Task { await store.closePasswordRecovery() } }
                            .buttonStyle(BeckonPrimaryButtonStyle())
                    default:
                        Text(store.recoveryState == .emailSent ? "Check Your Email" : "Reset Password").font(DesignTokens.Typography.featureTitle)
                        if store.recoveryState == .emailSent {
                            Text("If an account exists for this email, a reset link will arrive shortly. Open it on this device.")
                        }
                        TextField("Email", text: $store.recoveryEmail)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .beckonFormField().accessibilityIdentifier("auth.recovery.email")
                        Button(store.recoveryState == .emailSent ? "Resend Email" : "Send Reset Email", systemImage: "envelope") {
                            Task { await store.requestPasswordRecovery() }
                        }.buttonStyle(BeckonPrimaryButtonStyle())
                        if store.canRetryRecoveryLink {
                            Button("Retry Link", systemImage: "arrow.clockwise") { Task { await store.retryRecoveryLink() } }
                        }
                    }
                    if let error = store.recoveryError { Text(error).foregroundStyle(DesignTokens.Colors.errorText).accessibilityIdentifier("auth.recovery.error") }
                    if store.isRecovering { ProgressView().accessibilityLabel("Processing password recovery") }
                }
                .padding(DesignTokens.Spacing.screenHorizontal)
                .disabled(store.isRecovering)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Password Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { Task { await store.closePasswordRecovery() } }
                        .disabled(store.isRecovering)
                }
            }
        }
    }
}
