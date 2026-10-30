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
    /// The pup perks up while the primary button is held, as the Home hero's does.
    @State private var isGetStartedPressed = false

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
            .accessibilityIdentifier("auth.landing")
            // The page's mint wash is taller here than on the other pages, so the bubble sits on it and not on the cream below.
            .background(alignment: .top) {
                LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: proxy.size.height * 0.8)
                    .ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .beckonEntranceClock()
    }

    private var hero: some View {
        BeckonLockup(hasEntered: hasEntered, isExcited: isGetStartedPressed, dealsInWords: !isInsideLaunchGate)
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
