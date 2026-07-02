import SwiftUI

struct AuthenticationView: View {
    @Bindable var store: AuthenticationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var surface: AuthenticationSurface = .landing
    @State private var heroHasEntered = false
    @State private var bubblesAreFloating = false
    @State private var didStartLandingMotion = false
    @State private var isPasswordVisible = false

    var body: some View {
        ZStack {
            landingBackground

            switch surface {
            case .landing:
                landingSurface
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        )
                    )

            case .form:
                authFormSurface
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: surface)
        .onAppear(perform: startLandingMotion)
        .onChange(of: reduceMotion) { _, newValue in
            if newValue {
                heroHasEntered = true
                bubblesAreFloating = false
            }
        }
    }

    private var landingBackground: some View {
        LinearGradient(
            colors: [
                DesignTokens.Colors.appBackground,
                DesignTokens.Colors.surface.opacity(0.92),
                DesignTokens.Colors.borderSoft.opacity(0.56)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var landingSurface: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(
                        minLength: max(
                            proxy.size.height * 0.16,
                            DesignTokens.Spacing.xl * 2
                        )
                    )

                    landingHero

                    Spacer(
                        minLength: max(
                            proxy.size.height * 0.11,
                            DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                        )
                    )

                    landingActions

                    Spacer(
                        minLength: max(
                            proxy.safeAreaInsets.bottom + DesignTokens.Spacing.lg,
                            DesignTokens.Spacing.xl
                        )
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
        }
        .accessibilityIdentifier("auth.landing")
    }

    private var landingHero: some View {
        ZStack {
            FloatingBubbleLayer(
                isFloating: !reduceMotion && bubblesAreFloating,
                color: DesignTokens.Colors.customerPrimary
            )

            VStack(spacing: DesignTokens.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.customerPrimary.opacity(0.78))

                    Circle()
                        .fill(DesignTokens.Colors.surface.opacity(0.22))
                        .frame(width: 68, height: 68)
                        .offset(x: -34, y: -34)

                    Circle()
                        .stroke(DesignTokens.Colors.customerPrimaryDark.opacity(0.3), lineWidth: 1)

                    Text("🐶")
                        .font(.system(size: 62))
                        .offset(y: 3)
                        .accessibilityHidden(true)
                }
                .frame(width: 156, height: 156)
                .groomlyShadow(DesignTokens.Shadows.softCard)
                .scaleEffect(heroHasEntered ? 1 : 0.82)
                .offset(y: heroHasEntered ? 0 : -420)
                .opacity(heroHasEntered ? 1 : 0)
                .animation(
                    reduceMotion
                        ? nil
                        : .interpolatingSpring(stiffness: 92, damping: 11)
                            .delay(0.08),
                    value: heroHasEntered
                )

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Groomly")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(DesignTokens.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("Find trusted independent groomers\nfor your pet.")
                        .font(DesignTokens.Typography.body.weight(.medium))
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 310)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var landingActions: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Button {
                openForm(.signUp)
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.get-started")

            Button {
                openForm(.signIn)
            } label: {
                Text("I already have an account")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.plain)
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.already-have-account")
        }
        .frame(maxWidth: 430)
    }

    private var authFormSurface: some View {
        GeometryReader { proxy in
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

                    #if DEBUG
                    if store.mode == .signIn {
                        Spacer(minLength: DesignTokens.Spacing.lg)

                        debugQuickLoginActions

                        Spacer(minLength: DesignTokens.Spacing.xl)
                    } else {
                        Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
                    }
                    #else
                    Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
                    #endif

                    authFields

                    Spacer(minLength: fieldsToActionsSpacing)

                    authActions

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
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("auth.form")
    }

    private var formTopBar: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                    surface = .landing
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(DesignTokens.Colors.surface.opacity(0.82))
                    .clipShape(DesignTokens.Shapes.circular)
                    .overlay {
                        Circle()
                            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.back-to-landing")
            .accessibilityLabel("Home")

            Spacer()
        }
    }

    private var formHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(formTitle)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(DesignTokens.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(formSubtitle)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(DesignTokens.Colors.secondaryText)
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
                    .groomlyFormField()
                    .accessibilityIdentifier("auth.email")
            }

            labeledField("Password") {
                passwordInput
                    .accessibilityIdentifier("auth.password")
            }

            if store.mode == .signUp {
                labeledField("Confirm password") {
                    SecureField("••••••••", text: $store.passwordConfirmation)
                        .textContentType(.newPassword)
                        .submitLabel(.go)
                        .groomlyFormField()
                        .accessibilityIdentifier("auth.password-confirmation")
                }
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

            Button {
                withAnimation(.easeOut(duration: 0.14)) {
                    isPasswordVisible.toggle()
                }
            } label: {
                Text(isPasswordVisible ? "Hide" : "Show")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.password-visibility")
        }
        .groomlyFormField()
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
                            .tint(DesignTokens.Colors.surface)
                    }
                    Text(store.isSubmitting ? "Please wait…" : store.mode.rawValue)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.submit")

            Button {
                switchAuthMode()
            } label: {
                Text(secondaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
            .disabled(store.isSubmitting)
            .accessibilityIdentifier("auth.mode-secondary")
        }
        .frame(maxWidth: .infinity)
    }

    #if DEBUG
    private var debugQuickLoginActions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Quick Login")
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
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
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
                title: "Authentication Error",
                message: errorMessage
            )
            .accessibilityIdentifier("auth.error")
        }
    }

    private var formTitle: String {
        switch store.mode {
        case .signIn:
            "Welcome Back"
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
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.secondaryText)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openForm(_ mode: AuthenticationMode) {
        store.mode = mode
        isPasswordVisible = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            surface = .form
        }
    }

    private func switchAuthMode() {
        isPasswordVisible = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            store.mode = store.mode == .signIn ? .signUp : .signIn
        }
    }

    private func startLandingMotion() {
        guard !didStartLandingMotion else { return }
        didStartLandingMotion = true

        guard !reduceMotion else {
            heroHasEntered = true
            bubblesAreFloating = false
            return
        }

        heroHasEntered = false
        bubblesAreFloating = false

        withAnimation(.interpolatingSpring(stiffness: 92, damping: 11).delay(0.08)) {
            heroHasEntered = true
        }

        withAnimation(.easeInOut(duration: 0.2).delay(0.62)) {
            bubblesAreFloating = true
        }
    }
}

private enum AuthenticationSurface {
    case landing
    case form
}

private struct FloatingBubbleLayer: View {
    let isFloating: Bool
    let color: Color

    var body: some View {
        ZStack {
            bubble(
                size: 16,
                x: -118,
                y: -54,
                travel: -30,
                xTravel: -10,
                opacity: 0.34,
                delay: 0.08,
                duration: 3.0
            )
            bubble(
                size: 22,
                x: 118,
                y: -34,
                travel: 34,
                xTravel: 12,
                opacity: 0.24,
                delay: 0.24,
                duration: 3.4
            )
            bubble(
                size: 12,
                x: -138,
                y: 68,
                travel: 26,
                xTravel: 9,
                opacity: 0.28,
                delay: 0.44,
                duration: 3.2
            )
            bubble(
                size: 18,
                x: 140,
                y: 82,
                travel: -32,
                xTravel: -12,
                opacity: 0.22,
                delay: 0.14,
                duration: 3.6
            )
            bubble(
                size: 10,
                x: 60,
                y: -112,
                travel: 24,
                xTravel: -8,
                opacity: 0.3,
                delay: 0.34,
                duration: 2.8
            )
            bubble(
                size: 26,
                x: -20,
                y: 104,
                travel: -22,
                xTravel: 14,
                opacity: 0.16,
                delay: 0.56,
                duration: 4.0
            )
            bubble(
                size: 9,
                x: 10,
                y: -136,
                travel: 18,
                xTravel: 7,
                opacity: 0.24,
                delay: 0.18,
                duration: 3.1
            )
        }
        .frame(width: 360, height: 320)
        .accessibilityHidden(true)
    }

    private func bubble(
        size: CGFloat,
        x: CGFloat,
        y: CGFloat,
        travel: CGFloat,
        xTravel: CGFloat,
        opacity: Double,
        delay: Double,
        duration: Double
    ) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(DesignTokens.Colors.surface.opacity(opacity * 0.9), lineWidth: 1)
            }
            .offset(
                x: x + (isFloating ? xTravel : -xTravel * 0.35),
                y: y + (isFloating ? travel : -travel * 0.35)
            )
            .scaleEffect(isFloating ? 1.16 : 0.86)
            .animation(
                .easeInOut(duration: duration)
                    .delay(delay)
                    .repeatForever(autoreverses: true),
                value: isFloating
            )
    }
}
