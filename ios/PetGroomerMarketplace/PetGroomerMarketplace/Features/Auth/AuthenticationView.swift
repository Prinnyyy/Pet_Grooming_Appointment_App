import SwiftUI

struct AuthenticationView: View {
    @Bindable var store: AuthenticationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var surface: AuthenticationSurface = .landing
    @State private var heroHasEntered = false
    @State private var bubblesAreFloating = false
    @State private var didStartLandingMotion = false

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
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.large) {
                formTopBar
                header
                form
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.xl)
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
                Label("Home", systemImage: "chevron.left")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.back-to-landing")

            Spacer()
        }
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("🐶")
                .font(.system(size: 42))
                .frame(
                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg,
                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                )
                .background(DesignTokens.Colors.customerPrimary.opacity(0.78))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(store.mode == .signUp ? "Create your Groomly account" : "Welcome back")
                    .font(DesignTokens.Typography.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text(formSubtitle)
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
                    .buttonStyle(GroomlyPrimaryButtonStyle(accent: .customer))
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

    private var formSubtitle: String {
        switch store.mode {
        case .signIn:
            "Sign in to continue to your Groomly profile."
        case .signUp:
            "Start with email and password. Profile setup continues after sign-in."
        }
    }

    private func openForm(_ mode: AuthenticationMode) {
        store.mode = mode
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            surface = .form
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
