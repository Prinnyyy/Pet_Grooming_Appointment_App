// "Set up Beckon": the page a new account sees once it is signed in (design). Same job as RoleOnboardingView in
// Features/Auth/RoleOnboardingView.swift: a display name, a choice between pet owner and groomer (final), Continue, Sign out. The
// store (`AuthenticatedEntryStore`), its checks and its errors and every id are the real ones. What is new is that the page is the
// place where the two roles meet: choosing "I am a groomer" turns the whole page coral at once (the accent follows the role,
// `BeckonRole.swift`), so the person sees the app they are about to get before they commit to it.
import SwiftUI


struct RoleOnboardingView: View {
    let session: AuthSessionSnapshot
    @Bindable var store: AuthenticatedEntryStore
    let onSignOut: () -> Void
    @FocusState private var focusedField: RoleOnboardingFocusTarget?

    /// The page wears the colour of the role chosen so far (mint until a groomer is chosen).
    private var role: BeckonRole { store.selectedRole == .groomer ? .groomer : .customer }

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollViewReader { proxy in
                ScrollView {
                    BeckonCascade(alignment: .center, spacing: DesignTokens.Layout.sectionSpacing) {
                        header
                        form
                        if let message = store.errorMessage {
                            BeckonErrorBanner(title: "Profile setup error", message: message)
                                .accessibilityIdentifier("profile.error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
                .beckonKeyboardAvoidance(focusedTarget: focusedField?.rawValue, using: proxy)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .beckonEntranceRhythm(.detail)
        .environment(\.beckonRole, role)
        .accessibilityIdentifier("profile.onboarding")
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            DesignIconDisc(systemImage: "person.2.fill", size: .large, font: DesignTokens.Typography.Expressive.section)
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
                BeckonMetaChip(text: email, systemImage: "envelope.fill")
            }
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Display name")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                TextField("Display name", text: $store.displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .disabled(store.isSubmitting)
                    .focused($focusedField, equals: .displayName)
                    .beckonFormField()
                    .tint(DesignTokens.Colors.customerDeep)
                    .accessibilityIdentifier("profile.display-name")
            }
            .beckonKeyboardFocusTarget(RoleOnboardingFocusTarget.displayName.rawValue)

            VStack(spacing: DesignTokens.Spacing.md) {
                roleCard(.customer, title: "I am a pet owner", detail: "Ask for grooming and compare offers.", systemImage: "pawprint.fill",
                    identifier: "profile.role.customer")
                roleCard(.groomer, title: "I am a groomer", detail: "Answer requests and run your schedule.", systemImage: "scissors",
                    identifier: "profile.role.groomer")
            }

            DesignInfoLine(systemImage: "lock.fill", text: "Your role cannot be changed through the normal app.")

            Button {
                Task { await store.submit() }
            } label: {
                DesignActionLabel(title: store.isSubmitting ? "Creating profile…" : "Continue", systemImage: "arrow.right",
                    isBusy: store.isSubmitting)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("profile.submit")

            Button(action: onSignOut) {
                DesignQuietAction(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.sign-out")
        }
        .designCardBody()
    }

    /// A role as a card: white until it is chosen, then the page's own colour (which is this role's colour from that moment).
    private func roleCard(_ choice: UserRole, title: String, detail: String, systemImage: String, identifier: String) -> some View {
        let isSelected = store.selectedRole == choice
        return Button {
            store.selectedRole = choice
            store.errorMessage = nil
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.minimumTouchTarget)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
                    Text(detail)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BeckonTickCircle(isOn: isSelected)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .disabled(store.isSubmitting)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

nonisolated enum RoleOnboardingFocusTarget: String, Hashable {
    case displayName = "profile.display-name.container"
}
