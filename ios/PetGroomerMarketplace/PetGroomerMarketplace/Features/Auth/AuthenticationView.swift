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
                    .padding(DesignTokens.Spacing.standard)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(store.mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("auth.form")
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.standard) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Pet Groomer Marketplace")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.Colors.primaryText)

            Text("Sign in to manage grooming requests, offers, and bookings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.top, DesignTokens.Spacing.large)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.standard) {
            Picker("Authentication mode", selection: $store.mode) {
                ForEach(AuthenticationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.isSubmitting)

            TextField("Email", text: $store.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .accessibilityIdentifier("auth.email")

            SecureField("Password", text: $store.password)
                .textContentType(
                    store.mode == .signUp ? .newPassword : .password
                )
                .submitLabel(store.mode == .signUp ? .next : .go)
                .accessibilityIdentifier("auth.password")

            if store.mode == .signUp {
                SecureField(
                    "Confirm password",
                    text: $store.passwordConfirmation
                )
                .textContentType(.newPassword)
                .submitLabel(.go)
                .accessibilityIdentifier("auth.password-confirmation")
            }

            if let noticeMessage = store.noticeMessage {
                Label(noticeMessage, systemImage: "envelope.badge")
                    .font(.footnote)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("auth.notice")
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("auth.error")
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
                    Text(store.isSubmitting ? "Please wait…" : store.mode.rawValue)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.submit")
        }
        .textFieldStyle(.roundedBorder)
        .padding(DesignTokens.Spacing.standard)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
        )
    }
}
