// The scene behind Home's greeting (design, design): a sky with white clouds that drift, two ranges of mountains and a lawn, in the
// mint of the page. It fills the room the title row and the pup's band leave empty without adding anything to read. When the page is
// pulled down the lawn and both ranges go down together with the page, the clouds stay where they are, and more sky shows; the
// title and the bell stay put. Scrolled up, the layers part only a little, which is the depth. Decorative: hidden from
// accessibility, never takes a touch, and the clouds stand still under Reduce Motion or an inactive scene (`BeckonMotionGate`).
import SwiftUI


/// The room the hero keeps above its card for the pup (and for the mountains and the lawn to show in).
enum BeckonHeroBand {
    static let height: CGFloat = 54
}


/// Where the page's scroll is, shared between the page (which writes it) and the scene and the header (which read it), so a scroll
/// redraws only them and not the whole page.
@MainActor @Observable
final class BeckonScrollDepth {
    /// 0 at rest, positive while the page is scrolled up, negative while it is pulled down past its top.
    var offset: CGFloat = 0
    /// A pull-to-refresh is running (only so that a second pull does not start another).
    var isRefreshing = false

    /// How far the page is pulled down, in points.
    var pull: CGFloat { max(0, -offset) }

    /// A pull this far, let go of, starts a refresh.
    static let armedPull: CGFloat = 72
}


extension View {
    /// Keeps this block where it is while the page is pulled down (the content under it goes down, it does not). Scrolling up moves
    /// it with the page as usual.
    func beckonStaysWhilePulled(_ depth: BeckonScrollDepth) -> some View {
        modifier(BeckonStaysWhilePulledModifier(depth: depth))
    }
}


private struct BeckonStaysWhilePulledModifier: ViewModifier {
    let depth: BeckonScrollDepth

    func body(content: Content) -> some View {
        content.offset(y: min(0, depth.offset))
    }
}


/// The scene. As wide as the screen; `headroom` above the hero's band (so it also fills the status bar and the room a pull opens),
/// and a little below the card's top edge, where it fades out. Its base line, where the lawn meets the card, is the band's bottom.
/// Put it behind the hero, `headroom` up: see `CustomerHomeTop`.
struct BeckonHomeScene: View {
    let depth: BeckonScrollDepth

    static let headroom: CGFloat = 380
    private static let overlap: CGFloat = 30
    private static var baseY: CGFloat { headroom + BeckonHeroBand.height }
    private static var total: CGFloat { baseY + overlap }

    /// Ridge points, from the left edge past the right one: x as a fraction of the width, height above the base line in points.
    private static let farRange: [(CGFloat, CGFloat)] = [
        (-0.1, 44), (0.08, 128), (0.22, 66), (0.38, 142), (0.52, 74), (0.68, 122), (0.84, 62), (1.0, 106), (1.12, 54)]
    private static let nearRange: [(CGFloat, CGFloat)] = [
        (-0.1, 34), (0.02, 80), (0.16, 40), (0.30, 92), (0.46, 44), (0.60, 84), (0.76, 38), (0.92, 80), (1.12, 42)]

    var body: some View {
        let offset = depth.offset
        ZStack(alignment: .top) {
            sky.mask(fade)
            // The clouds are the only thing that moves by itself, so they are outside the masks (a mask would redraw what it covers
            // at every tick); they never reach the bottom of the scene.
            BeckonSceneClouds(baseY: Self.baseY)
                .offset(y: Self.shift(offset, pull: 0, scroll: 0.5))
            ZStack(alignment: .top) {
                // Pulled down, both ranges go with the page exactly as the lawn does; scrolled up they part from it by a little.
                BeckonRangeShape(ridge: Self.farRange, baseY: Self.baseY)
                    .fill(DesignTokens.Colors.sceneMountainFar)
                    .offset(y: Self.shift(offset, pull: 1, scroll: 0.88))
                BeckonRangeShape(ridge: Self.nearRange, baseY: Self.baseY)
                    .fill(DesignTokens.Colors.sceneMountainNear)
                    .offset(y: Self.shift(offset, pull: 1, scroll: 0.95))
                lawn
            }
            .mask(fade)
        }
        .frame(height: Self.total)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How far a layer moves against the page: it follows a pull by `pull` of the finger's distance and a scroll up by `scroll` of
    /// the page's (1 is the page itself, 0 stands still on the screen).
    private static func shift(_ offset: CGFloat, pull: CGFloat, scroll: CGFloat) -> CGFloat {
        offset < 0 ? (1 - pull) * offset : (1 - scroll) * offset
    }

    /// Everything fades out together under the card's top edge, so there is no edge beside the card.
    private var fade: some View {
        LinearGradient(stops: [
            .init(color: .black, location: 0), .init(color: .black, location: (Self.baseY + 4) / Self.total),
            .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
    }

    private var sky: some View {
        Rectangle().fill(LinearGradient(stops: [
            .init(color: DesignTokens.Colors.sceneSkyTop, location: 0),
            .init(color: DesignTokens.Colors.sceneSkyTop, location: (Self.baseY - 110) / Self.total),
            .init(color: DesignTokens.Colors.sceneSkyHorizon, location: (Self.baseY - 14) / Self.total),
            .init(color: DesignTokens.Colors.sceneSkyHorizon, location: 1)], startPoint: .top, endPoint: .bottom))
    }

    private var lawn: some View {
        BeckonLawnShape(baseY: Self.baseY)
            .fill(DesignTokens.Colors.sceneLawn)
    }
}


/// A mountain range: a rolling ridge, the peaks rounded, filled down past the bottom of the scene (the layers part a little when the
/// page is scrolled up, and no gap may open between a range and the lawn in front of it).
private struct BeckonRangeShape: Shape {
    let ridge: [(CGFloat, CGFloat)]
    let baseY: CGFloat

    func path(in rect: CGRect) -> Path {
        let points = ridge.map { CGPoint(x: rect.minX + $0.0 * rect.width, y: baseY - $0.1) }
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        let bottom = baseY + 260
        path.move(to: CGPoint(x: first.x, y: bottom))
        path.addLine(to: first)
        // Each point is a control point between the middles of its two sides: the ridge is smooth and the peaks are soft.
        for index in 1..<(points.count - 1) {
            let next = points[index + 1]
            let middle = CGPoint(x: (points[index].x + next.x) / 2, y: (points[index].y + next.y) / 2)
            path.addQuadCurve(to: middle, control: points[index])
        }
        path.addLine(to: last)
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.closeSubpath()
        return path
    }
}


/// The lawn: a low rolling crest across the width, filled below.
private struct BeckonLawnShape: Shape {
    let baseY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        var x = rect.minX
        while x <= rect.maxX + 4 {
            path.addLine(to: CGPoint(x: x, y: BeckonLawnCrest.height(at: x - rect.minX, baseY: baseY)))
            x += 3
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}


private nonisolated enum BeckonLawnCrest {
    static func height(at x: CGFloat, baseY: CGFloat) -> CGFloat {
        baseY - 20 + 6 * sin(x / 41 + 0.6) + 3 * sin(x / 17 + 2)
    }
}


/// Three white clouds drifting to the right, one behind the mountains, each at its own height and pace, so slowly that the eye
/// only notices that they have moved. They leave on the right and come back on the left.
private struct BeckonSceneClouds: View {
    let baseY: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.beckonEntranceActive) private var pageIsActive

    /// x at rest as a fraction of the width, height above the base line, width, points per second.
    private let clouds: [(x: CGFloat, above: CGFloat, width: CGFloat, speed: CGFloat)] = [
        (0.12, 138, 92, 6.5), (0.62, 40, 64, 4.5), (0.84, 98, 56, 5.5)]

    var body: some View {
        // Slow enough (5 points a second) to need few frames, and not drawn at all while another tab is on screen.
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused || !pageIsActive
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: paused)) { context in
            let time = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for cloud in clouds {
                    let margin = cloud.width
                    let span = size.width + 2 * margin
                    let travelled = cloud.x * span + CGFloat(time) * cloud.speed
                    let x = travelled.truncatingRemainder(dividingBy: span) - margin
                    draw(&gc, centre: CGPoint(x: x + cloud.width / 2, y: baseY - cloud.above), width: cloud.width)
                }
            }
        }
    }

    /// Two puffs on a flat base, composed as one layer so that the cloud is one soft white (a translucent shape drawn three times
    /// would show its seams).
    private func draw(_ gc: inout GraphicsContext, centre: CGPoint, width: CGFloat) {
        let height = width * 0.34
        gc.drawLayer { layer in
            layer.opacity = 0.92
            let white = DesignTokens.Colors.surface
            layer.fill(Path(roundedRect: CGRect(x: centre.x - width / 2, y: centre.y - height * 0.35, width: width, height: height * 0.7),
                cornerRadius: height * 0.35), with: .color(white))
            layer.fill(Path(ellipseIn: CGRect(x: centre.x - width * 0.30, y: centre.y - height * 0.85, width: height * 0.95, height: height * 0.95)),
                with: .color(white))
            layer.fill(Path(ellipseIn: CGRect(x: centre.x - width * 0.04, y: centre.y - height * 1.1, width: height * 1.2, height: height * 1.2)),
                with: .color(white))
        }
    }
}
