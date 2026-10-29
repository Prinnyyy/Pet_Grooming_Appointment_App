// The four tab icons as one family (S-057). They are drawn here, not taken from SF Symbols, so they share one language: the same
// round stroke, round corners, no realistic detail (the scissors were too literal). Home is a house with a door, Grooming a paw,
// Messages a bubble with three dots, Account a person. Outline when the tab is not chosen, solid with the details cut out when it is.
// Each is rendered once to a template image, so the tab bar tints it (grey, then the customer colour) and the glass panel behind
// it stays the system's own.
import SwiftUI
import UIKit


enum BeckonTabIcon: CaseIterable, Identifiable {
    case home, grooming, messages, account

    var id: Self { self }

    /// The shapes that are the icon's body (stroked as an outline, filled when chosen) and the small details on them (solid when not
    /// chosen, a hole when chosen). Drawn on a 24 by 24 grid.
    fileprivate var art: (shapes: [Path], details: [Path], lineWidth: CGFloat) {
        switch self {
        case .home:
            let house = Path { path in
                path.addLines([
                    CGPoint(x: 12, y: 3.8), CGPoint(x: 20.6, y: 11.2), CGPoint(x: 18.9, y: 11.2), CGPoint(x: 18.9, y: 19.6),
                    CGPoint(x: 5.1, y: 19.6), CGPoint(x: 5.1, y: 11.2), CGPoint(x: 3.4, y: 11.2),
                ])
                path.closeSubpath()
            }
            let door = Path(roundedRect: CGRect(x: 10.2, y: 13.4, width: 3.6, height: 5.2), cornerRadius: 1.8)
            return ([house], [door], 2.2)

        case .grooming:
            func toe(_ x: CGFloat, _ y: CGFloat, turn: Double) -> Path {
                let box = CGRect(x: x - 2.1, y: y - 2.7, width: 4.2, height: 5.4)
                return Path(ellipseIn: box).applying(
                    CGAffineTransform(translationX: x, y: y).rotated(by: turn * .pi / 180).translatedBy(x: -x, y: -y))
            }
            let pad = Path { path in
                path.move(to: CGPoint(x: 12, y: 11.3))
                path.addCurve(to: CGPoint(x: 18.4, y: 16.9), control1: CGPoint(x: 15.2, y: 11.3), control2: CGPoint(x: 18.4, y: 13.9))
                path.addCurve(to: CGPoint(x: 15, y: 20.6), control1: CGPoint(x: 18.4, y: 19.2), control2: CGPoint(x: 17, y: 20.6))
                path.addCurve(to: CGPoint(x: 12, y: 19.3), control1: CGPoint(x: 13.6, y: 20.6), control2: CGPoint(x: 12.9, y: 19.3))
                path.addCurve(to: CGPoint(x: 9, y: 20.6), control1: CGPoint(x: 11.1, y: 19.3), control2: CGPoint(x: 10.4, y: 20.6))
                path.addCurve(to: CGPoint(x: 5.6, y: 16.9), control1: CGPoint(x: 7, y: 20.6), control2: CGPoint(x: 5.6, y: 19.2))
                path.addCurve(to: CGPoint(x: 12, y: 11.3), control1: CGPoint(x: 5.6, y: 13.9), control2: CGPoint(x: 8.8, y: 11.3))
                path.closeSubpath()
            }
            return ([toe(4.7, 11.2, turn: -22), toe(9.1, 6.4, turn: -8), toe(14.9, 6.4, turn: 8), toe(19.3, 11.2, turn: 22), pad], [], 2)

        case .messages:
            let bubble = Path { path in
                let (left, right, top, bottom, radius): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (3.4, 20.6, 4.4, 16.8, 5.4)
                path.move(to: CGPoint(x: left + radius, y: top))
                path.addLine(to: CGPoint(x: right - radius, y: top))
                path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
                path.addLine(to: CGPoint(x: right, y: bottom - radius))
                path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom), control: CGPoint(x: right, y: bottom))
                path.addLine(to: CGPoint(x: 12.2, y: bottom))
                path.addLine(to: CGPoint(x: 7.6, y: 20.9))
                path.addLine(to: CGPoint(x: 7.6, y: bottom))
                path.addLine(to: CGPoint(x: left + radius, y: bottom))
                path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius), control: CGPoint(x: left, y: bottom))
                path.addLine(to: CGPoint(x: left, y: top + radius))
                path.addQuadCurve(to: CGPoint(x: left + radius, y: top), control: CGPoint(x: left, y: top))
                path.closeSubpath()
            }
            let dots = [8.3, 12, 15.7].map { Path(ellipseIn: CGRect(x: $0 - 1.2, y: 10.6 - 1.2, width: 2.4, height: 2.4)) }
            return ([bubble], dots, 2.2)

        case .account:
            let head = Path(ellipseIn: CGRect(x: 8.2, y: 3.8, width: 7.6, height: 7.6))
            let shoulders = Path { path in
                path.move(to: CGPoint(x: 5.2, y: 20.2))
                path.addCurve(to: CGPoint(x: 12, y: 14.4), control1: CGPoint(x: 5.2, y: 16.4), control2: CGPoint(x: 8, y: 14.4))
                path.addCurve(to: CGPoint(x: 18.8, y: 20.2), control1: CGPoint(x: 16, y: 14.4), control2: CGPoint(x: 18.8, y: 16.4))
                path.closeSubpath()
            }
            return ([head, shoulders], [], 2.2)
        }
    }

    var accessibilityName: String {
        switch self {
        case .home: "Home"
        case .grooming: "Grooming"
        case .messages: "Messages"
        case .account: "Account"
        }
    }
}


/// One icon drawn at any size on its 24 point grid, in the colour it is given.
struct BeckonTabIconArt: View {
    let icon: BeckonTabIcon
    let isSelected: Bool
    var color: Color = .black

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let art = icon.art
            let shapes = art.shapes.map { $0.applying(transform) }
            let details = art.details.map { $0.applying(transform) }
            let style = StrokeStyle(lineWidth: art.lineWidth * scale, lineCap: .round, lineJoin: .round)

            if isSelected {
                // Solid body with the details as holes (the even-odd rule turns a shape drawn inside another into a hole).
                var solid = Path()
                shapes.forEach { solid.addPath($0) }
                details.forEach { solid.addPath($0) }
                context.fill(solid, with: .color(color), style: FillStyle(eoFill: true))
                shapes.forEach { context.stroke($0, with: .color(color), style: style) }
            } else {
                shapes.forEach { context.stroke($0, with: .color(color), style: style) }
                details.forEach { context.fill($0, with: .color(color)) }
            }
        }
        .frame(width: 25, height: 25)
        .accessibilityHidden(true)
    }
}


/// The icons as template images for the tab bar, drawn once each.
@MainActor
enum BeckonTabIcons {
    private static var cache: [String: UIImage] = [:]

    static func image(_ icon: BeckonTabIcon, isSelected: Bool) -> Image {
        let key = "\(icon)-\(isSelected)"
        if let cached = cache[key] { return Image(uiImage: cached) }
        let renderer = ImageRenderer(content: BeckonTabIconArt(icon: icon, isSelected: isSelected))
        renderer.scale = 3
        renderer.isOpaque = false
        guard let drawn = renderer.uiImage else { return Image(systemName: "circle") }
        let template = drawn.withRenderingMode(.alwaysTemplate)
        cache[key] = template
        return Image(uiImage: template)
    }
}
