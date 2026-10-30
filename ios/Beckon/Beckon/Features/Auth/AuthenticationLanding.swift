// The page a signed-out person lands on (S-084). The original's lockup, as the user knew it: the brand bubble with its drifting
// satellites, "Beckon", the line under it, and the two ways in. What changed is where it sits: the lockup is centered in the room
// above the buttons (hung from the top it left a hole over them), and the buttons are pinned, so a long text size scrolls the
// page and never the buttons. Sign-in and sign-up are the next surface; this one holds no store.
import SwiftUI


struct AuthenticationLanding: View {
    @Environment(\.isInsideLaunchGate) private var isInsideLaunchGate
    /// True once the bubble has dropped in; the owner keeps it, so coming back from the form does not drop it again.
    let hasEntered: Bool
    let isBusy: Bool
    let onGetStarted: () -> Void
    let onSignIn: () -> Void
    /// Launch reserves the exact same action layout, including Dynamic Type, without exposing the controls.
    var showsActions = true
    var showsWords = true
    var showsBackdrop = true
    var brandIsExcited = false
    var playsArrivalReaction = true
    var brandOffset: CGFloat = 0
    /// The pup perks up while the primary button is held, as the Home hero's does.
    @State private var isGetStartedPressed = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                // The lockup sits in the middle of the room above the buttons, a little high (the bottom padding), so the space
                // over it and under it is the same whatever the phone.
                VStack(spacing: 0) {
                    Spacer(minLength: DesignTokens.Spacing.xl)

                    hero

                    Spacer(minLength: DesignTokens.Spacing.xl)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.bottom, DesignTokens.Spacing.xl)
                .frame(minHeight: proxy.size.height)
            }
            .accessibilityIdentifier(showsActions ? "auth.landing" : "launch.brand.layout")
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                if isInsideLaunchGate && showsActions { scrollOffset = offset }
            }
            // The page's mint wash is taller here than on the other pages, so the bubble sits on it and not on the cream below.
            .background(alignment: .top) {
                LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: proxy.size.height * 0.8)
                    .ignoresSafeArea()
                    .opacity(showsBackdrop ? 1 : 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsActions { actions }
            else { actions.hidden().allowsHitTesting(false).accessibilityHidden(true) }
        }
        .beckonEntranceClock()
        .preference(key: AuthenticationLandingBrandKey.self,
            value: isInsideLaunchGate && showsActions
                ? AuthenticationLandingBrand(isExcited: isGetStartedPressed, scrollOffset: scrollOffset) : nil)
    }

    private var hero: some View {
        BeckonLockup(hasEntered: isInsideLaunchGate || hasEntered, isExcited: isGetStartedPressed || brandIsExcited,
            dealsInWords: showsActions && !isInsideLaunchGate, showsWords: showsWords,
            playsArrivalReaction: playsArrivalReaction && !isInsideLaunchGate)
            .offset(y: brandOffset)
            // Reserve identical geometry; the launch gate keeps the one visible animated lockup.
            .opacity(isInsideLaunchGate ? 0 : 1)
            .accessibilityHidden(false)
            .beckonEntranceActive(!isInsideLaunchGate)
    }

    private var actions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Button(action: onGetStarted) {
                DesignActionLabel(title: "Get started", systemImage: "arrow.right")
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill) { isGetStartedPressed = $0 })
            .disabled(isBusy)
            .accessibilityIdentifier("auth.get-started")

            Button(action: onSignIn) {
                Text("I already have an account")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
            .disabled(isBusy)
            .accessibilityIdentifier("auth.already-have-account")
        }
        .frame(maxWidth: 430)
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .beckonEntrance(1)
    }
}

struct AuthenticationLandingBrand: Equatable {
    let isExcited: Bool
    let scrollOffset: CGFloat
}

/// The real welcome page owns taps and scrolling; the shared decoration follows its state.
struct AuthenticationLandingBrandKey: PreferenceKey {
    static let defaultValue: AuthenticationLandingBrand? = nil
    static func reduce(value: inout AuthenticationLandingBrand?, nextValue: () -> AuthenticationLandingBrand?) {
        if let next = nextValue() { value = next }
    }
}
