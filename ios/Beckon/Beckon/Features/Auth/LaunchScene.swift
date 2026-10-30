// The scene that holds the screen from the first frame of the app until the person's own page can be shown (design). Today the app
// walks through four unrelated waiting screens (the brand page, "Restoring session", "Loading profile", then the page), each cut in
// hard over the one before. Here there is one: the landing's lockup on the landing's mint wash, so a signed-out person sees the landing
// arrive as these two buttons rise under it, and a signed-in one sees this scene fade into their page, which is already laid out
// in bars. The system's own launch screen is this scene's first frame (the same wash and orb), so nothing flashes before it.
import SwiftUI


struct LaunchScene: View {
    var body: some View {
        ZStack {
            DesignTokens.Colors.appBackground.ignoresSafeArea()
            GeometryReader { proxy in
                LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: proxy.size.height * 0.8)
                    .ignoresSafeArea()
            }
            // The room the landing keeps for its two buttons, so the lockup stands where the landing puts it.
            BeckonLockup()
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.bottom, DesignTokens.Metrics.launchBottomReserve)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Beckon, loading")
        .accessibilityIdentifier("launch.scene")
    }
}


/// The page under the scene is built at once (so its own loading starts and its bars are ready), and the scene leaves with a fade
/// when the app is ready and has been up for at least a moment (a quick start never shows a scene that blinks).
struct LaunchGate<Content: View>: View {
    let isReady: Bool
    @ViewBuilder let content: Content
    @State private var hasBeenUpAMoment = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOver: Bool { isReady && hasBeenUpAMoment }

    var body: some View {
        ZStack {
            content
                .environment(\.isInsideLaunchGate, true)
                .environment(\.beckonEntranceActive, isOver)
                .accessibilityHidden(!isOver)
                .allowsHitTesting(isOver)
            if !isOver {
                LaunchScene()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.reveal, value: isOver)
        .task {
            try? await Task.sleep(for: .seconds(DesignTokens.Motion.launchMinimum))
            guard !Task.isCancelled else { return }
            hasBeenUpAMoment = true
        }
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
