#if DEBUG
// The whole app, from its first frame, in the Canvas (design): the launch scene, the landing, sign in or sign up (the prototype's own),
// "Set up Beckon" (the role), and then the customer's tabs or the groomer's, each in its own colour. It is the route
// `AuthenticatedEntryView` takes in the real app (`.onboarding` → `.customer` or `.groomer`), run on the sandbox's sign-in and local
// data. The customer's host (`CustomerFlowSandbox`) and the groomer's (`GroomerFlowSandbox`) start inside one
// role; this one starts before there is a role. Signing out from either role's Account returns to the landing.
import SwiftUI


struct AppFlowSandbox: View {
    /// Where the flow starts: `.landing`, `.signIn` or `.signUp` (signed out), or `.onboarding` (signed in with no role yet).
    let screen: CustomerSandboxScreen
    /// The role the onboarding has chosen when it opens (nothing chosen when nil), for a preview of that moment.
    var role: UserRole?
    /// The launch scene holds the first moments, as the real app opens.
    var showsLaunch = false
    @State private var session: CustomerSandboxSession
    @State private var groomer = GroomerSandboxSession(state: .loaded)
    @State private var ready = false
    @State private var launchIsReady = false
    @State private var preparationError: String?

    init(screen: CustomerSandboxScreen = .landing, role: UserRole? = nil, showsLaunch: Bool = false) {
        self.screen = screen
        self.role = role
        self.showsLaunch = showsLaunch
        _session = State(initialValue: CustomerSandboxSession(screen: screen, state: .loaded))
    }

    var body: some View {
        Group {
            if let preparationError {
                ContentUnavailableView("Fixture setup failed", systemImage: "exclamationmark.triangle", description: Text(preparationError))
            } else if ready {
                if showsLaunch {
                    LaunchGate(isReady: launchIsReady) { running }
                } else {
                    // The gate keeps its scene up for a moment even when the app is ready, so a page starts without it.
                    running
                }
            } else {
                ProgressView("Preparing local fixtures")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                try await session.prepare()
                session.onboarding.selectedRole = role
                ready = true
            } catch { preparationError = String(describing: error) }
        }
        .task(id: showsLaunch) {
            guard showsLaunch else { return }
            try? await Task.sleep(for: .seconds(1.6))
            launchIsReady = true
        }
        .environment(\.beckonFeedbackCenter, session.feedback)
        .environment(\.customerMarketplaceSession, session.marketplace)
        .environment(\.appDebugEventRecorder, nil)
        .environment(\.sandboxRequestAdvance, session.advanceRequest)
        .environment(\.openURL, OpenURLAction { _ in
            session.feedback.showNotice("External links stay closed in this sandbox.")
            return .handled
        })
        .overlay(alignment: .bottom) {
            // The tab views carry their own feedback overlay; the pages before them do not.
            if !isInsideTabs { BeckonGlobalFeedbackOverlay(center: session.feedback) }
        }
        .preferredColorScheme(.light)
        .tint(DesignTokens.Colors.customerDeep)
        .onDisappear { session.invalidate() }
    }

    private var isSignedIn: Bool {
        if case .signedIn = session.authentication.rootState { return true }
        return false
    }

    private var isInsideTabs: Bool {
        guard isSignedIn else { return false }
        switch session.onboarding.state {
        case .customer, .groomer: return true
        default: return false
        }
    }

    private var running: some View { flow.task { await session.activate() } }

    @ViewBuilder private var flow: some View {
        if isSignedIn {
            switch session.onboarding.state {
            case .customer:
                CustomerTabView(sandbox: session)
            case .groomer:
                GroomerTabView(sandbox: groomer, authenticationStore: session.authentication,
                    onSignOut: { Task { await session.authentication.signOut() } })
            default:
                RoleOnboardingView(session: session.authSession, store: session.onboarding,
                    onSignOut: { Task { await session.authentication.signOut() } })
            }
        } else {
            AuthenticationView(sandboxStore: session.authentication, showsForm: screen != .landing)
                .beckonSheet(isPresented: Binding(get: { session.authentication.recoveryState != nil },
                    set: { if !$0 { session.authentication.recoveryState = nil } })) {
                    PasswordRecoveryView(store: session.authentication)
                }
        }
    }
}


#Preview("The whole app - from the launch scene") { AppFlowSandbox(screen: .landing, showsLaunch: true).id("appLaunch") }
#Preview("The whole app - sign up") { AppFlowSandbox(screen: .signUp).id("appSignUp") }
#Preview("Set up Beckon: nothing chosen") { AppFlowSandbox(screen: .onboarding).id("onboardingNone") }
#Preview("Set up Beckon: a pet owner") { AppFlowSandbox(screen: .onboarding, role: .customer).id("onboardingOwner") }
#Preview("Set up Beckon: a groomer") { AppFlowSandbox(screen: .onboarding, role: .groomer).id("onboardingGroomer") }
#endif
