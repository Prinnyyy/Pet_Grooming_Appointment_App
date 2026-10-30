import SwiftUI


private struct BeckonEntranceReplayKey: EnvironmentKey {
    static let defaultValue = 0
}


extension EnvironmentValues {
    /// Bumping this value replays entrances. Previews and sandboxes use it; production never changes it.
    var beckonEntranceReplay: Int {
        get { self[BeckonEntranceReplayKey.self] }
        set { self[BeckonEntranceReplayKey.self] = newValue }
    }
}


/// How a page arrives. A rhythm is a family of pages that keep one tempo (see `Motion.Entrance`): the steps of a journey, a
/// detail page, a tab root or list. A page picks one with `.beckonEntranceRhythm(_:)`; its blocks then call
/// `.beckonEntrance(_:)` (or sit in a `BeckonCascade`) and never choose a speed themselves.
enum BeckonEntranceRhythm: Sendable {
    case step, detail, list

    var profile: DesignTokens.Motion.Entrance {
        switch self {
        case .step: DesignTokens.Motion.stepEntrance
        case .detail: DesignTokens.Motion.detailEntrance
        case .list: DesignTokens.Motion.listEntrance
        }
    }
}


/// Which way blocks come from. `rise` is up from below (a page opening); `forward` and `back` slide along a journey, in from
/// the side the person is heading to (Continue) or coming back from (Back).
enum BeckonEntranceTravel: Sendable {
    case rise, forward, back

    func start(distance: CGFloat, layoutDirection: LayoutDirection) -> CGSize {
        let side: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        switch self {
        case .rise: return CGSize(width: 0, height: distance)
        case .forward: return CGSize(width: distance * side, height: distance * 0.2)
        case .back: return CGSize(width: -distance * side, height: distance * 0.2)
        }
    }
}


private struct BeckonEntranceRhythmKey: EnvironmentKey {
    static let defaultValue = BeckonEntranceRhythm.list
}


private struct BeckonEntranceTravelKey: EnvironmentKey {
    static let defaultValue = BeckonEntranceTravel.rise
}


private struct BeckonEntranceSettledKey: EnvironmentKey {
    static let defaultValue = false
}


private struct BeckonEntranceActiveKey: EnvironmentKey {
    static let defaultValue = true
}


private struct BeckonRevealsInPlaceKey: EnvironmentKey {
    static let defaultValue = false
}


extension EnvironmentValues {
    /// False while the page a block sits in is not the one on screen (the other tabs). Its blocks wait hidden and arrive again
    /// the moment it becomes true, so a tab root is dealt in every time it is selected, not only the first time.
    var beckonEntranceActive: Bool {
        get { self[BeckonEntranceActiveKey.self] }
        set { self[BeckonEntranceActiveKey.self] = newValue }
    }

    /// True once the page a block sits in has been open for a second: blocks that show up now (a row coming back, data that
    /// arrived late) land at once instead of waiting for a beat that has long passed.
    var beckonEntranceSettled: Bool {
        get { self[BeckonEntranceSettledKey.self] }
        set { self[BeckonEntranceSettledKey.self] = newValue }
    }

    /// True inside a revealed placeholder (`DesignReveal`): the content takes the place the placeholder held, so its blocks
    /// are simply there (the reveal cross-fades them) instead of springing in a second time from below (design).
    var beckonRevealsInPlace: Bool {
        get { self[BeckonRevealsInPlaceKey.self] }
        set { self[BeckonRevealsInPlaceKey.self] = newValue }
    }

    var beckonEntranceRhythm: BeckonEntranceRhythm {
        get { self[BeckonEntranceRhythmKey.self] }
        set { self[BeckonEntranceRhythmKey.self] = newValue }
    }

    var beckonEntranceTravel: BeckonEntranceTravel {
        get { self[BeckonEntranceTravelKey.self] }
        set { self[BeckonEntranceTravelKey.self] = newValue }
    }
}


/// A block arriving: it starts small, a little turned and away from its place, then springs in with overshoot, one beat after
/// the block above it. Order 0 is the leader (more bounce); a negative order is a late arrival that lands at once. Plays once
/// per view identity, again when the replay counter changes, and again each time its page becomes the active one after being
/// away (the tab roots): it hides while its page is inactive, so the return is a fresh arrival with no flash of the old state.
/// Reduce Motion becomes a short fade.
private struct BeckonEntranceModifier: ViewModifier {
    let order: Int
    @Environment(\.beckonEntranceReplay) private var replay
    @Environment(\.beckonEntranceRhythm) private var rhythm
    @Environment(\.beckonEntranceTravel) private var travel
    @Environment(\.beckonEntranceSettled) private var pageIsSettled
    @Environment(\.beckonEntranceActive) private var pageIsActive
    @Environment(\.beckonRevealsInPlace) private var revealsInPlace
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var playedReplay: Int?
    /// SwiftUI does not animate a change made while the page is not on screen (it jumps to the end), so an arrival waits until
    /// the page is both active and showing.
    @State private var isOnScreen = false
    @State private var wantsArrival = true

    func body(content: Content) -> some View {
        let profile = rhythm.profile
        let isLate = order < 0 || pageIsSettled
        let isLeader = order == 0 && !isLate
        let settled = arrived || reduceMotion
        let lean = abs(order) % 2 == 0 ? profile.tilt : -profile.tilt
        let away = travel.start(distance: profile.travel, layoutDirection: layoutDirection)
        content
            .opacity(arrived ? 1 : 0)
            .scaleEffect(settled ? 1 : (isLeader ? profile.leaderScale : profile.scale), anchor: .top)
            .rotationEffect(.degrees(settled ? 0 : lean), anchor: .top)
            .offset(x: settled ? 0 : away.width, y: settled ? 0 : away.height)
            // The play starts the moment the block is on screen, with its beat as the animation's own delay, so a busy main
            // actor (a page loading its data) cannot hold the arrival back. Only a replay resets first.
            .onDisappear { isOnScreen = false }
            .onAppear {
                isOnScreen = true
                if playedReplay == nil { playedReplay = replay }
                arriveIfReady(profile: profile, isLeader: isLeader, isLate: isLate)
            }
            .onChange(of: pageIsActive) { _, isActive in
                guard playedReplay != nil else { return }
                wantsArrival = true
                if isActive {
                    arriveIfReady(profile: profile, isLeader: isLeader, isLate: isLate)
                } else {
                    hide()
                }
            }
            .task(id: replay) {
                guard let played = playedReplay, played != replay else { return }
                playedReplay = replay
                hide()
                wantsArrival = true
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                arriveIfReady(profile: profile, isLeader: isLeader, isLate: isLate)
            }
    }

    /// Plays the arrival once the page is active and on screen: a page built, or returned to, while another tab shows waits
    /// hidden for its turn (the onChange above) and lands when it appears (the onAppear above), whichever comes second.
    private func arriveIfReady(profile: DesignTokens.Motion.Entrance, isLeader: Bool, isLate: Bool) {
        guard wantsArrival, isOnScreen, pageIsActive else { return }
        wantsArrival = false
        play(profile: profile, isLeader: isLeader, isLate: isLate)
    }

    /// Back to the hidden start with no animation: used while the page is away or just before a replay.
    private func hide() {
        var reset = Transaction(animation: nil)
        reset.disablesAnimations = true
        withTransaction(reset) { arrived = false }
    }

    private func play(profile: DesignTokens.Motion.Entrance, isLeader: Bool, isLate: Bool) {
        if revealsInPlace {
            var inPlace = Transaction(animation: nil)
            inPlace.disablesAnimations = true
            withTransaction(inPlace) { arrived = true }
            return
        }
        let beats = isLate ? 0 : Double(min(max(order, 0), profile.maxBeats))
        withAnimation(reduceMotion
            ? DesignTokens.Motion.reduced
            : (isLeader ? profile.leaderSpring : profile.spring).delay(beats * profile.beat)) {
            arrived = true
        }
    }
}


private struct BeckonCascadeOwnsArrivalKey: ContainerValueKey {
    static let defaultValue = false
}


extension ContainerValues {
    /// Set by a cascade on itself: its blocks arrive one by one, so an outer cascade must not also animate it as one block.
    fileprivate var beckonCascadeOwnsArrival: Bool {
        get { self[BeckonCascadeOwnsArrivalKey.self] }
        set { self[BeckonCascadeOwnsArrivalKey.self] = newValue }
    }
}


/// Marks the moment a page opened. A second later its descendants are told the page has settled, so blocks that appear after
/// that land at once. Cascades and `DesignPage` carry one; a page numbering its blocks by hand adds it to its root.
/// A page that goes inactive (another tab) starts the second again when it returns, so its blocks are dealt in beat by beat.
private struct BeckonEntranceClockModifier: ViewModifier {
    @Environment(\.beckonEntranceActive) private var pageIsActive
    @State private var isSettled = false

    func body(content: Content) -> some View {
        content
            .environment(\.beckonEntranceSettled, isSettled)
            .task(id: pageIsActive) {
                isSettled = false
                guard pageIsActive else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                isSettled = true
            }
    }
}


/// A stack whose blocks arrive one beat after another, numbered for you: the first lands at `start`, the next one beat later.
/// Use it for a flat run of blocks (a step of a flow, a detail page) so the tempo cannot drift between pages. A cascade inside
/// a cascade gives itself the `start` it should carry on from (the outer one does not animate it as a block, so its blocks
/// land one by one). Blocks that show up after the page has settled land at once. Do not also give its direct children
/// `.beckonEntrance`.
struct BeckonCascade<Content: View>: View {
    var start = 0
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    if subview.containerValues.beckonCascadeOwnsArrival {
                        subview
                    } else {
                        subview.beckonEntrance(start + index)
                    }
                }
            }
        }
        .containerValue(\.beckonCascadeOwnsArrival, true)
        .beckonEntranceClock()
    }
}


/// The primary action leans in a moment after its page has landed, then springs back. Plays when the view appears and again
/// whenever `trigger` changes (the step). Reduce Motion: none.
private struct BeckonBumpModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let beats: Int
    @Environment(\.beckonEntranceRhythm) private var rhythm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLeaning = true
    @State private var hasPlayed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isLeaning && !reduceMotion ? DesignTokens.Motion.bumpScale : 1)
            .onAppear {
                guard !hasPlayed else { return }
                hasPlayed = true
                lean(after: 0)
            }
            .task(id: trigger) {
                guard hasPlayed else { return }
                var reset = Transaction(animation: nil)
                reset.disablesAnimations = true
                withTransaction(reset) { isLeaning = true }
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                lean(after: 0)
            }
    }

    private func lean(after extra: Double) {
        withAnimation(DesignTokens.Motion.bounce.delay(Double(beats) * rhythm.profile.beat + extra)) { isLeaning = false }
    }
}


/// `.animation(_:value:)` that collapses to the reduced animation under Reduce Motion.
private struct BeckonAnimatedModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? DesignTokens.Motion.reduced : animation, value: value)
    }
}


/// Scroll-linked ease: a block grows to full size as it settles into view. No-op under Reduce Motion.
private struct BeckonScrollEaseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition { effect, phase in
                effect.scaleEffect(phase.isIdentity ? 1 : 0.95)
            }
        }
    }
}


/// Horizontal carousel tilt: cards lean slightly as they leave the center. No-op under Reduce Motion, and when the
/// carousel has reflowed into a vertical stack (`isEnabled == false`).
private struct BeckonCarouselTiltModifier: ViewModifier {
    let isEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion || !isEnabled {
            content
        } else {
            content.scrollTransition(axis: .horizontal) { effect, phase in
                effect
                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                    .rotationEffect(.degrees(phase.value * 4))
            }
        }
    }
}


extension View {
    /// Lands this block `order` beats into its page (0 leads). The rhythm and direction come from the page.
    func beckonEntrance(_ order: Int) -> some View { modifier(BeckonEntranceModifier(order: order)) }

    /// Tells the blocks below that the page has settled a second after it opened (see `BeckonEntranceClockModifier`).
    func beckonEntranceClock() -> some View { modifier(BeckonEntranceClockModifier()) }

    /// Marks whether this page is the one on screen. Only the tab view sets it, once per tab: the blocks of an inactive tab wait
    /// hidden and are dealt in again, in order, each time the tab is selected.
    func beckonEntranceActive(_ isActive: Bool) -> some View { environment(\.beckonEntranceActive, isActive) }

    /// Sets how this page arrives: the family's tempo and, when given, which way its blocks come from (otherwise the page keeps
    /// the direction it inherited, so a step embedded in a flow follows the flow).
    func beckonEntranceRhythm(_ rhythm: BeckonEntranceRhythm,
        travel: BeckonEntranceTravel? = nil) -> some View {
        environment(\.beckonEntranceRhythm, rhythm)
            .transformEnvironment(\.beckonEntranceTravel) { if let travel { $0 = travel } }
    }

    /// The primary action leans in `beats` after the page starts landing and again when `trigger` changes.
    func beckonBump<Trigger: Equatable>(trigger: Trigger, beats: Int = 3) -> some View {
        modifier(BeckonBumpModifier(trigger: trigger, beats: beats))
    }

    func beckonAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(BeckonAnimatedModifier(animation: animation, value: value))
    }

    func beckonScrollEase() -> some View { modifier(BeckonScrollEaseModifier()) }
    func beckonCarouselTilt(isEnabled: Bool = true) -> some View { modifier(BeckonCarouselTiltModifier(isEnabled: isEnabled)) }
}


/// A press that waits to be sure it is a tap. A finger that lands on a button and then drags to scroll cancels the press within
/// a few hundredths of a second; reacting at touch-down made every scroll that began on a card or a pill sink it and fire a
/// haptic, which felt like touching things by accident. `content` gets `false` until the touch has stayed down for
/// `Motion.pressSettleMilliseconds`, and `false` again the moment it lifts or is cancelled.
struct BeckonSettledPress<Content: View>: View {
    let isPressed: Bool
    let content: (_ settled: Bool) -> Content
    @State private var settled = false
    @State private var wait: Task<Void, Never>?

    init(isPressed: Bool, @ViewBuilder content: @escaping (_ settled: Bool) -> Content) {
        self.isPressed = isPressed
        self.content = content
    }

    var body: some View {
        content(settled)
            .onChange(of: isPressed) { _, now in
                wait?.cancel()
                guard now else { settled = false; return }
                wait = Task {
                    try? await Task.sleep(for: .milliseconds(DesignTokens.Motion.pressSettleMilliseconds))
                    if !Task.isCancelled { settled = true }
                }
            }
            .onDisappear {
                wait?.cancel()
                wait = nil
                settled = false
            }
    }
}


/// True while decorative loops must stand still: Reduce Motion, or the scene is not active.
struct BeckonMotionGate {
    let reduceMotion: Bool
    let scenePhase: ScenePhase
    var isPaused: Bool { reduceMotion || scenePhase != .active }
}
