import SwiftUI

nonisolated enum AuthenticationFocusTarget: String, CaseIterable, Hashable {
    case email = "auth.email.container"
    case password = "auth.password.container"
    case passwordConfirmation = "auth.password-confirmation.container"
}

struct AuthenticationView: View {
    @Bindable var store: AuthenticationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var surface: AuthenticationSurface = .landing
    @State private var heroHasEntered = false
    /// Which way the next surface's blocks come from: up when the app opens, from the right going into the form, from the left
    /// going back, like the steps of the request wizard.
    @State private var travel = BeckonEntranceTravel.rise
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
            landingBackground

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

    private var landingBackground: some View {
        BeckonExpressiveBackdrop()
    }

    private var landingSurface: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(
                            height: max(
                                proxy.size.height * 0.16,
                                DesignTokens.Spacing.xl * 2
                            )
                        )
                        .accessibilityHidden(true)

                    landingHero

                    Spacer(minLength: DesignTokens.Spacing.xl)

                    landingActions
                        .padding(
                            .bottom,
                            max(
                                proxy.safeAreaInsets.bottom + DesignTokens.Spacing.lg,
                                DesignTokens.Spacing.xl
                            )
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .beckonEntranceClock()
            }
        }
        .accessibilityIdentifier("auth.landing")
    }

    private var landingHero: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            BeckonBrandBubble(isMotionEnabled: !reduceMotion && scenePhase == .active,
                hasEntered: heroHasEntered || reduceMotion)

            // The bubble lands with its own spring (heroHasEntered); the words follow it as the first block.
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Beckon")
                    .font(DesignTokens.Typography.Expressive.display)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Pet groomers at your beck and call.")
                    .font(DesignTokens.Typography.Expressive.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 310)
            }
            .beckonEntrance(0)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .accessibilityElement(children: .combine)
    }

    private var landingActions: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Button {
                openForm(.signUp)
            } label: {
                Text("Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.get-started")

            Button {
                openForm(.signIn)
            } label: {
                Text("I already have an account")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.already-have-account")
        }
        .frame(maxWidth: 430)
        .beckonEntrance(1)
    }

    private var authFormSurface: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                    formTopBar

                    Spacer(
                        minLength: max(
                            proxy.size.height * 0.1,
                            DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                        )
                    )

                    formHeader
                        .beckonEntrance(0)

                    #if DEBUG
                    if store.mode == .signIn {
                        Spacer(minLength: DesignTokens.Spacing.lg)

                        debugQuickLoginActions
                            .beckonEntrance(1)

                        Spacer(minLength: DesignTokens.Spacing.xl)
                    } else {
                        Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
                    }
                    #else
                    Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
                    #endif

                    authFields
                        .beckonEntrance(1)

                    Spacer(minLength: fieldsToActionsSpacing)

                    authActions
                        .beckonEntrance(2)

                    feedback
                        .padding(.top, DesignTokens.Spacing.lg)

                    Spacer(
                        minLength: max(
                            proxy.safeAreaInsets.bottom + DesignTokens.Spacing.lg,
                            DesignTokens.Spacing.xl
                        )
                    )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.md)
                    .beckonEntranceClock()
                }
                .beckonKeyboardAvoidance(
                    focusedTarget: focusedField?.rawValue,
                    using: scrollProxy
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("auth.form")
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

    private var formHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(formTitle)
                .font(DesignTokens.Typography.Expressive.display)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(formSubtitle)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authFields: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            labeledField("Email") {
                TextField("lian@example.com", text: $store.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .beckonFormField()
                    .accessibilityIdentifier("auth.email")
            }
            .beckonKeyboardFocusTarget(AuthenticationFocusTarget.email.rawValue)

            labeledField("Password") {
                passwordInput
                    .accessibilityIdentifier("auth.password")
            }
            .beckonKeyboardFocusTarget(AuthenticationFocusTarget.password.rawValue)

            if store.mode == .signIn {
                Button {
                    Task { await store.beginPasswordRecovery() }
                } label: {
                    DesignQuietAction(title: "Forgot password?", systemImage: "key.fill")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(store.isSubmitting || store.isRecovering)
                .accessibilityIdentifier("auth.forgot-password")
            }

            if store.mode == .signUp {
                labeledField("Confirm password") {
                    SecureField("••••••••", text: $store.passwordConfirmation)
                        .textContentType(.newPassword)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .passwordConfirmation)
                        .beckonFormField()
                        .accessibilityIdentifier("auth.password-confirmation")
                }
                .beckonKeyboardFocusTarget(
                    AuthenticationFocusTarget.passwordConfirmation.rawValue
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var passwordInput: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
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

            Button {
                withAnimation(DesignTokens.Motion.reduced) {
                    isPasswordVisible.toggle()
                }
            } label: {
                Text(isPasswordVisible ? "Hide" : "Show")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityIdentifier("auth.password-visibility")
        }
        .beckonFormField()
    }

    private var authActions: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
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
                    Text(store.isSubmitting ? "Please wait…" : store.mode.rawValue)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.submit")

            Button {
                switchAuthMode()
            } label: {
                Text(secondaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.mode-secondary")
        }
        .frame(maxWidth: .infinity)
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
        .padding(.top, DesignTokens.Spacing.sm)
    }
    #endif

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
        }

        if let errorMessage = store.errorMessage {
            BeckonErrorBanner(
                title: "Authentication error",
                message: errorMessage
            )
            .accessibilityIdentifier("auth.error")
        }
    }

    private var formTitle: String {
        switch store.mode {
        case .signIn:
            "Welcome back"
        case .signUp:
            "Create Account"
        }
    }

    private var formSubtitle: String {
        switch store.mode {
        case .signIn:
            "Sign in to manage grooming requests and bookings."
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

    private var fieldsToActionsSpacing: CGFloat {
        switch store.mode {
        case .signIn:
            DesignTokens.Spacing.lg
        case .signUp:
            DesignTokens.Spacing.xl + DesignTokens.Spacing.md
        }
    }

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
