// Loading, as the shape of the page (design). A page that waits for its data shows its own layout with grey bars where the data will
// be, a light sweeping across them, and then each bar turns into what it stood for in the same place: nothing is added above
// something already read, nothing is dealt in a second time. The pieces:
//   `DesignSkeletonLine / Block / Disc / Heading`   the bars (a line takes the height of a real line at the current text size)
//   `.designSkeleton(label:)`              marks a region as a placeholder: the sweep, and one VoiceOver label
//   `DesignReveal`                          placeholder or content, with the timing rules (no flash, no jump)
// All text and pictures in a page's body are bars while it waits (a mix of real words and bars reads as noise); what stays real is
// the page's frame (its title, the bell, the tab bar).
import SwiftUI


/// What a bar sits on: a card's white face (the default), or the page itself, whose mint wash is as light as the bars of a card.
enum DesignSkeletonSurface {
    case card
    case page

    var fill: Color {
        switch self {
        case .card: DesignTokens.Colors.skeleton
        case .page: DesignTokens.Colors.skeletonOnPage
        }
    }
}


private struct DesignSkeletonSurfaceKey: EnvironmentKey {
    static let defaultValue = DesignSkeletonSurface.card
}


extension EnvironmentValues {
    var designSkeletonSurface: DesignSkeletonSurface {
        get { self[DesignSkeletonSurfaceKey.self] }
        set { self[DesignSkeletonSurfaceKey.self] = newValue }
    }
}


extension View {
    /// The bars inside sit on the page itself, not on a card (a heading, a line of a section, a button).
    func designSkeletonOnPage() -> some View {
        environment(\.designSkeletonSurface, .page)
    }
}


/// One line of text as a bar. The bar is as wide as `width` of the room there is and as tall as the real line's type allows, so the
/// skeleton and the page it stands for line up at every Dynamic Type size.
struct DesignSkeletonLine: View {
    var width: CGFloat = 1
    var font: Font = DesignTokens.Typography.Expressive.supporting
    @Environment(\.designSkeletonSurface) private var surface

    var body: some View {
        Text("Ag")
            .font(font)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(surface.fill)
                        .frame(width: proxy.size.width * width, height: proxy.size.height * 0.6)
                        .frame(maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
    }
}


/// A rectangle where an image, a tile or a button will be. Its size is the caller's.
struct DesignSkeletonBlock: View {
    var cornerRadius: CGFloat = DesignTokens.CornerRadius.inset
    @Environment(\.designSkeletonSurface) private var surface

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface.fill)
            .accessibilityHidden(true)
    }
}


/// A circle where an avatar will be. Its size is the caller's.
struct DesignSkeletonDisc: View {
    @Environment(\.designSkeletonSurface) private var surface

    var body: some View {
        Circle()
            .fill(surface.fill)
            .accessibilityHidden(true)
    }
}


/// A section heading as bars: the icon tile as a block and the title as a line, in the heading's own height.
struct DesignSkeletonHeading: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.pill)
                .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)
            DesignSkeletonLine(width: 0.32, font: DesignTokens.Typography.Expressive.section)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .designSkeletonOnPage()
        .designSkeleton(label: nil)
    }
}


private struct DesignSkeletonRegion: ViewModifier {
    let label: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.beckonEntranceActive) private var pageIsActive
    /// Where this region starts on the screen, so that regions side by side are lit by one band, not by one band each.
    @State private var screenFrame: CGRect = .zero

    private let bandWidth: CGFloat = 220
    private let travel: CGFloat = 1000

    func body(content: Content) -> some View {
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused || !pageIsActive
        content
            .overlay {
                if !paused {
                    TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame)) { context in
                        band(at: context.date)
                    }
                    // The light is only seen where there is a bar (and on the lip of a card), never on the page behind.
                    .mask { content }
                    .allowsHitTesting(false)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? "")
            .accessibilityHidden(label == nil)
    }

    private func band(at date: Date) -> some View {
        let period = DesignTokens.Motion.skeletonPeriod
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let globalX = -bandWidth + progress * (travel + bandWidth)
        return Rectangle()
            .fill(LinearGradient(colors: [.clear, DesignTokens.Colors.skeletonSweep, .clear],
                startPoint: .leading, endPoint: .trailing))
            .frame(width: bandWidth, height: 3000)
            .rotationEffect(.degrees(14))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .offset(x: globalX - screenFrame.minX - screenFrame.midY * tan(14 * .pi / 180))
    }
}


extension View {
    /// The bars of a skeleton: the light across them, and one VoiceOver label for all of it ("Loading your grooming"). Put it on the
    /// content inside a card, not on the card, so the light is seen on the bars and not on the card's edge; a skeleton of several
    /// parts labels one and passes `nil` for the others.
    func designSkeleton(label: String?) -> some View {
        modifier(DesignSkeletonRegion(label: label))
    }
}


/// A place that waits for data: the placeholder while it does, the content when it has, in the same place.
/// - Data that comes in less than `skeletonShowDelay` never shows the placeholder (no flash); the space is kept meanwhile.
/// - A placeholder that was shown stays at least `skeletonMinimum`, so it does not blink.
/// - The change is a plain cross-fade; when it replaces a wait, the content's own entrance is switched off inside
///   (`beckonRevealsInPlace`), and the block that holds the whole place carries the page's entrance.
/// - Once the content is there, a refresh never brings the placeholder back: pass `isLoading` for the first load only
///   (`store.isLoading && store.items.isEmpty`).
struct DesignReveal<Content: View, Placeholder: View>: View {
    let isLoading: Bool
    /// Called when the content has taken the placeholder's place (not when it was there from the start): the cue for what comes next.
    var onReveal: () -> Void = {}
    private let content: Content
    private let placeholder: Placeholder

    @State private var state: DesignRevealState
    @Environment(\.beckonEntranceActive) private var pageIsActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isLoading: Bool, onReveal: @escaping () -> Void = {}, @ViewBuilder content: () -> Content,
         @ViewBuilder placeholder: () -> Placeholder) {
        self.isLoading = isLoading
        self.onReveal = onReveal
        self.content = content()
        self.placeholder = placeholder()
        _state = State(initialValue: DesignRevealState(isLoading: isLoading))
    }

    var body: some View {
        ZStack(alignment: .top) {
            if state.phase == .content {
                content
                    .environment(\.beckonRevealsInPlace, state.startedWaiting)
                    .transition(.opacity)
            } else {
                placeholder
                    .opacity(state.phase == .waiting ? 0 : 1)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.reveal, value: state.phase)
        .task(id: [isLoading, pageIsActive]) { if pageIsActive { await settle() } }
    }

    private func settle() async {
        guard state.phase != .content else { return }
        if isLoading {
            try? await Task.sleep(for: .seconds(DesignTokens.Motion.skeletonShowDelay))
            guard !Task.isCancelled else { return }
            state.showPlaceholder(at: ProcessInfo.processInfo.systemUptime)
        } else {
            let rest = state.revealDelay(at: ProcessInfo.processInfo.systemUptime)
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled else { return }
            if state.reveal() { onReveal() }
        }
    }
}

struct DesignRevealState {
    enum Phase { case waiting, placeholder, content }
    private(set) var phase: Phase
    let startedWaiting: Bool
    private var shownAt: TimeInterval?

    init(isLoading: Bool) {
        phase = isLoading ? .waiting : .content
        startedWaiting = isLoading
    }

    mutating func showPlaceholder(at time: TimeInterval) {
        guard phase == .waiting else { return }
        phase = .placeholder
        shownAt = time
    }

    func revealDelay(at time: TimeInterval) -> TimeInterval {
        guard phase == .placeholder, let shownAt else { return 0 }
        return max(0, DesignTokens.Motion.skeletonMinimum - (time - shownAt))
    }

    mutating func reveal() -> Bool {
        guard phase != .content else { return false }
        phase = .content
        return true
    }
}
