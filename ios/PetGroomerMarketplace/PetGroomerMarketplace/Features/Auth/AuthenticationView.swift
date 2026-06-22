import SwiftUI

struct AuthenticationView: View {
    @Bindable var store: AuthenticationStore

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
            .navigationTitle(store.mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("auth.form")
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "pawprint.circle.fill")
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
                Text("Groomly")
                    .font(DesignTokens.Typography.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text("Find trusted independent groomers for your pet.")
                    .font(DesignTokens.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            GroomlyCard {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Picker("Authentication mode", selection: $store.mode) {
                        ForEach(AuthenticationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DesignTokens.Colors.customerPrimaryDark)
                    .disabled(store.isSubmitting)

                    VStack(spacing: DesignTokens.Spacing.md) {
                        TextField("Email", text: $store.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .groomlyFormField()
                            .accessibilityIdentifier("auth.email")

                        SecureField("Password", text: $store.password)
                            .textContentType(
                                store.mode == .signUp ? .newPassword : .password
                            )
                            .submitLabel(store.mode == .signUp ? .next : .go)
                            .groomlyFormField()
                            .accessibilityIdentifier("auth.password")

                        if store.mode == .signUp {
                            SecureField(
                                "Confirm password",
                                text: $store.passwordConfirmation
                            )
                            .textContentType(.newPassword)
                            .submitLabel(.go)
                            .groomlyFormField()
                            .accessibilityIdentifier("auth.password-confirmation")
                        }
                    }

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
                            Text(store.isSubmitting ? "Please wait…" : store.mode.rawValue)
                        }
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle())
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier("auth.submit")
                }
            }

            feedback
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let noticeMessage = store.noticeMessage {
            Label(noticeMessage, systemImage: "envelope.badge")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                )
                .accessibilityIdentifier("auth.notice")
        }

        if let errorMessage = store.errorMessage {
            GroomlyErrorBanner(
                title: "Authentication error",
                message: errorMessage
            )
            .accessibilityIdentifier("auth.error")
        }
    }
}
