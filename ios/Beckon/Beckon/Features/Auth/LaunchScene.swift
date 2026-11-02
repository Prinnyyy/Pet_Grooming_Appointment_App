// Startup reuses the landing layout, so its wordmark stays in place when the actions arrive.
// The system storyboard shows the initial wash; this scene owns the orb and text entrance.
import SwiftUI


struct LaunchScene: View {
    var playsIntro = false
    var isLanding = false
    var isExcited = false
    var scrollOffset: CGFloat = 0
    var onIntroFinished: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbEntered = false
    @State private var wordsEntered = false
    @State private var started = false
    @State private var completion = LaunchIntroCompletionState()

    var body: some View {
        AuthenticationLanding(hasEntered: !playsIntro || orbEntered, isBusy: true,
            onGetStarted: {}, onSignIn: {}, showsActions: false, showsWords: !playsIntro || wordsEntered,
            showsBackdrop: !isLanding, brandIsExcited: isExcited, playsArrivalReaction: playsIntro || started,
            onArrivalReactionFinished: { completion.arrivalFinished = true },
            brandOffset: -scrollOffset)
        .background {
            if !isLanding { DesignTokens.Colors.appBackground.ignoresSafeArea() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLanding ? "Beckon. Pet groomers at your beck and call." : "Beckon, loading")
        .accessibilityIdentifier(isLanding ? "auth.landing.brand" : "launch.scene")
        .onAppear {
            guard playsIntro, !started else { return }
            started = true
            if reduceMotion {
                orbEntered = true
                wordsEntered = true
                completion.wordsFinished = true
                completion.arrivalFinished = true
            } else {
                withAnimation(DesignTokens.Motion.brandArrival, completionCriteria: .logicallyComplete) {
                    orbEntered = true
                } completion: {
                    withAnimation(DesignTokens.Motion.brandWords, completionCriteria: .removed) {
                        wordsEntered = true
                    } completion: { completion.wordsFinished = true }
                }
            }
        }
        .onChange(of: completion.isFinished) { _, finished in
            if finished { onIntroFinished() }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced && started {
                orbEntered = true
                wordsEntered = true
                completion.wordsFinished = true
                completion.arrivalFinished = true
            }
        }
    }
}

struct LaunchIntroCompletionState {
    var wordsFinished = false
    var arrivalFinished = false
    var isFinished: Bool { wordsFinished && arrivalFinished }
}

/// Keep page construction and loading out of the intro. After the full intro, mount the page behind the same scene,
/// then reveal it when ready; a slow load or an authentication transition cannot restart the intro.
struct LaunchGate<Content: View>: View {
    let isReady: Bool
    private let content: () -> Content
    @State private var presentation = LaunchPresentationState()
    @State private var landingBrand: AuthenticationLandingBrand?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOver: Bool { presentation.hasDismissed }

    init(isReady: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isReady = isReady
        self.content = content
    }

    var body: some View {
        ZStack {
            if presentation.introFinished {
                content()
                .environment(\.isInsideLaunchGate, true)
                .environment(\.beckonEntranceActive, isOver)
                .accessibilityHidden(!isOver)
                .allowsHitTesting(isOver)
            }
            if !isOver || landingBrand != nil {
                // Keep this exact instance through the welcome handoff so the pup's reaction
                // and idle timeline finish continuously. Only its background leaves.
                LaunchScene(playsIntro: !isOver, isLanding: isOver,
                    isExcited: landingBrand?.isExcited == true, scrollOffset: landingBrand?.scrollOffset ?? 0) {
                    presentation.introFinished = true
                }
                    // Fade the finished scene as one layer. Fading its wash and artwork
                    // separately lets the pale wash show through the pup during handoff.
                    .compositingGroup()
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(isOver)
                    .zIndex(1)
            }
        }
        .preference(key: LaunchIntroFinishedKey.self, value: presentation.introFinished)
        .onPreferenceChange(AuthenticationLandingBrandKey.self) { value in
            if (landingBrand == nil) != (value == nil) {
                withAnimation(DesignTokens.Motion.reduced) { landingBrand = value }
            } else { landingBrand = value }
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.reveal, value: isOver)
        .task {
            try? await Task.sleep(for: .seconds(DesignTokens.Motion.launchMinimum))
            guard !Task.isCancelled else { return }
            presentation.minimumElapsed = true
        }
        .onChange(of: isReady && presentation.introFinished && presentation.minimumElapsed, initial: true) { _, ready in
            presentation.update(isReady: ready)
        }
    }
}

struct LaunchIntroFinishedKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}


/// A launch is one event. Signing in, recovery or a profile refresh cannot resurrect it.
struct LaunchPresentationState {
    var introFinished = false
    var minimumElapsed = false
    private(set) var hasDismissed = false
    mutating func update(isReady: Bool) {
        if isReady && introFinished && minimumElapsed { hasDismissed = true }
    }
}

/// Only the active routing leaf declares readiness. Failure/recovery pages are ready too,
/// so the launch scene cannot hide an actionable error.
struct LaunchReadyKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct InsideLaunchGateKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isInsideLaunchGate: Bool {
        get { self[InsideLaunchGateKey.self] }
        set { self[InsideLaunchGateKey.self] = newValue }
    }
}

struct LaunchWaitingView: View {
    @Environment(\.isInsideLaunchGate) private var hosted
    var body: some View {
        Group {
            if hosted { Color.clear } else { LaunchScene() }
        }
        .preference(key: LaunchReadyKey.self, value: false)
    }
}
