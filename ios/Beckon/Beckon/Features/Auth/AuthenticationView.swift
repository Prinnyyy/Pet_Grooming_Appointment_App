// S-084: the pages before sign-in. The landing is `AuthenticationLanding` (the original's lockup, centered, buttons pinned).
// Form: the mint banner of the app's pages with the pup, the fields with their symbol, the one decision pinned above the keyboard,
// and the other mode as a quiet line instead of a second big button.
import SwiftUI


nonisolated enum AuthenticationFocusTarget: String, CaseIterable, Hashable {
    case email = "auth.email.container"
    case password = "auth.password.container"
    case passwordConfirmation = "auth.password-confirmation.container"
}


struct AuthenticationView: View {
    @Bindable var store: AuthenticationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var surface: AuthenticationSurface = .landing
    /// Which way the next surface's blocks come from: up when the app opens, from the right going into the form, from the left
    /// going back, like the steps of the request wizard.
    @State private var travel = BeckonEntranceTravel.rise
    @State private var heroHasEntered = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: AuthenticationFocusTarget?

    #if DEBUG
    init(store: AuthenticationStore) { self.store = store }

    init(sandboxStore: AuthenticationStore, showsForm: Bool) {
        store = sandboxStore
        _surface = State(initialValue: showsForm ? .form : .landing)
    }
    #endif

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            // Between the two surfaces only the page fades; the blocks of each surface bring the motion (the wizard's rule).
            switch surface {
            case .landing:
                landingSurface
                    .id(surface)
                    .transition(.opacity)

            case .form:
                authFormSurface
                    .id(surface)
                    .transition(.opacity)
            }
        }
        .environment(\.beckonCustomerDesign, true)
        .beckonEntranceRhythm(.step, travel: travel)
        .beckonAnimation(DesignTokens.Motion.reduced, value: surface)
        .onAppear {
            guard !heroHasEntered else { return }
            withAnimation(reduceMotion ? nil : .interpolatingSpring(stiffness: 92, damping: 14).delay(0.08)) {
                heroHasEntered = true
            }
        }
    }

    // MARK: Landing

    private var landingSurface: some View {
        AuthenticationLanding(hasEntered: heroHasEntered, isBusy: store.isSubmitting,
            onGetStarted: { openForm(.signUp) }, onSignIn: { openForm(.signIn) })
    }

    // MARK: Form

    private var authFormSurface: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    formTopBar

                    formHeader
                        .beckonEntrance(0)

                    feedback

                    authFields
                        .beckonEntrance(1)

                    modeSwitch
                        .beckonEntrance(2)

                    #if DEBUG
                    if store.mode == .signIn {
                        debugQuickLoginActions
                            .beckonEntrance(3)
                    }
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.xl)
                .beckonEntranceClock()
            }
            .accessibilityIdentifier("auth.form")
            .beckonKeyboardAvoidance(
                focusedTarget: focusedField?.rawValue,
                using: scrollProxy
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { submitBar }
    }

    private var formTopBar: some View {
        HStack {
            Button {
                travel = .back
                surface = .landing
            } label: {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.round))
            .accessibilityIdentifier("auth.back-to-landing")
            .accessibilityLabel("Home")

            Spacer()
        }
    }

    /// The mint banner of the app's pages with the pup resting on it: the same welcome as Home, so the first page after the
    /// landing already looks like the app.
    private var formHeader: some View {
        DesignPupPeek {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(formTitle)
                    .font(DesignTokens.Typography.Expressive.hero)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(formSubtitle)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The pup's paws rest on the banner; the title starts below them, however long it is.
            .padding(.top, DesignTokens.Spacing.md)
            .designBanner()
        }
    }

    private var authFields: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            labeledField("Email") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    fieldSymbol("envelope.fill")
                    TextField("lian@example.com", text: $store.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { advance(from: .email) }
                        .accessibilityIdentifier("auth.email")
                }
                .beckonFormField()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .email }
            }
            .beckonKeyboardFocusTarget(AuthenticationFocusTarget.email.rawValue)

            labeledField("Password") {
                passwordInput
                    .accessibilityIdentifier("auth.password")
            }
            .beckonKeyboardFocusTarget(AuthenticationFocusTarget.password.rawValue)

            if store.mode == .signIn {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        Task { await store.beginPasswordRecovery() }
                    } label: {
                        Text("Forgot password?")
                            .font(DesignTokens.Typography.Expressive.emphasis)
                            .foregroundStyle(DesignTokens.Colors.customerDeep)
                            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .disabled(store.isSubmitting || store.isRecovering)
                    .accessibilityIdentifier("auth.forgot-password")
                }
                .transition(.opacity)
            }

            if store.mode == .signUp {
                labeledField("Confirm password") {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        fieldSymbol("lock.fill")
                        SecureField("••••••••", text: $store.passwordConfirmation)
                            .textContentType(.newPassword)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .passwordConfirmation)
                            .onSubmit { advance(from: .passwordConfirmation) }
                            .accessibilityIdentifier("auth.password-confirmation")
                    }
                    .beckonFormField()
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .passwordConfirmation }
                }
                .beckonKeyboardFocusTarget(
                    AuthenticationFocusTarget.passwordConfirmation.rawValue
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(store.isSubmitting)
    }

    private var passwordInput: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            fieldSymbol("lock.fill")

            Group {
                if isPasswordVisible {
                    TextField("••••••••", text: $store.password)
                } else {
                    SecureField("••••••••", text: $store.password)
                }
            }
            .textContentType(store.mode == .signUp ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(store.mode == .signUp ? .next : .go)
            .focused($focusedField, equals: .password)
            .onSubmit { advance(from: .password) }

            Button {
                withAnimation(DesignTokens.Motion.reduced) {
                    isPasswordVisible.toggle()
                }
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: 28)
                    .contentShape(Rectangle().inset(by: -DesignTokens.Spacing.sm))
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            .accessibilityIdentifier("auth.password-visibility")
        }
        .padding(.trailing, -DesignTokens.Spacing.sm)
        .beckonFormField()
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .password }
    }

    /// The one decision of the page, above the keyboard instead of below the fields.
    private var submitBar: some View {
        BeckonPinnedBar {
            Button {
                Task {
                    await store.submit()
                }
            } label: {
                DesignActionLabel(
                    title: store.isSubmitting ? "Please wait…" : store.mode.rawValue,
                    systemImage: store.mode == .signIn ? "arrow.right" : "person.crop.circle.badge.plus",
                    isBusy: store.isSubmitting
                )
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.submit")
        }
    }

    /// The other mode, said as a question and answered by a tap, where someone who picked the wrong door looks for it.
    private var modeSwitch: some View {
        Button {
            switchAuthMode()
        } label: {
            Text("\(Text(modeSwitchQuestion).foregroundStyle(DesignTokens.Colors.textSecondary)) \(Text(secondaryActionTitle).foregroundStyle(DesignTokens.Colors.customerDeep))")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .disabled(store.isSubmitting)
        .accessibilityIdentifier("auth.mode-secondary")
    }

    #if DEBUG
    private var debugQuickLoginActions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Quick login")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .textCase(.uppercase)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(DebugQuickLoginAccount.allCases) { account in
                    Button {
                        Task {
                            await store.signInWithDebugAccount(account)
                        }
                    } label: {
                        Label(account.title, systemImage: account.systemImage)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                    .disabled(store.isSubmitting)
                    .accessibilityIdentifier(account.accessibilityIdentifier)
                }
            }
        }
    }
    #endif

    /// What the last try said, right under the welcome where the eye is, not under the button.
    @ViewBuilder
    private var feedback: some View {
        if let noticeMessage = store.noticeMessage {
            Label(noticeMessage, systemImage: "envelope.badge")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.customerTint)
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                )
                .accessibilityIdentifier("auth.notice")
                .transition(.opacity)
        }

        if let errorMessage = store.errorMessage {
            BeckonErrorBanner(
                title: "Authentication error",
                message: errorMessage
            )
            .accessibilityIdentifier("auth.error")
            .transition(.opacity)
        }
    }

    // MARK: Copy

    private var formTitle: String {
        switch store.mode {
        case .signIn:
            "Welcome back"
        case .signUp:
            "Create your account"
        }
    }

    private var formSubtitle: String {
        switch store.mode {
        case .signIn:
            "Sign in to manage your grooming."
        case .signUp:
            "Start with email and password. Profile setup continues after sign-in."
        }
    }

    private var secondaryActionTitle: String {
        switch store.mode {
        case .signIn:
            "Create Account"
        case .signUp:
            "Sign In"
        }
    }

    private var modeSwitchQuestion: String {
        switch store.mode {
        case .signIn:
            "New to Beckon?"
        case .signUp:
            "Already have an account?"
        }
    }

    // MARK: Pieces and actions

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The small symbol that opens a field, so the three fields tell apart at a glance.
    private func fieldSymbol(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(DesignTokens.Typography.Expressive.emphasis)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .frame(width: DesignTokens.Spacing.xl)
            .accessibilityHidden(true)
    }

    /// Return moves to the next field, and on the last one it sends.
    private func advance(from field: AuthenticationFocusTarget) {
        switch (field, store.mode) {
        case (.email, _):
            focusedField = .password
        case (.password, .signUp):
            focusedField = .passwordConfirmation
        default:
            focusedField = nil
            Task { await store.submit() }
        }
    }

    private func openForm(_ mode: AuthenticationMode) {
        store.mode = mode
        isPasswordVisible = false
        travel = .forward
        surface = .form
    }

    private func switchAuthMode() {
        isPasswordVisible = false
        withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) {
            store.mode = store.mode == .signIn ? .signUp : .signIn
        }
    }
}


private enum AuthenticationSurface {
    case landing
    case form
}
