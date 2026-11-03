import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class BeckonPressRenderingTests: XCTestCase {
    func testAutomaticKindsUseHeightForLinksAndPreserveNamedRows() {
        for (size, kind): (CGSize, BeckonPressKind) in [
            (.zero, .surface), (.init(width: 64, height: 64), .compact),
            (.init(width: 200, height: 44), .inline), (.init(width: 200, height: 49), .surface),
            (.init(width: 40, height: 200), .surface)
        ] { XCTAssertEqual(BeckonPressKind.automatic.resolved(for: size), kind) }
        XCTAssertEqual(BeckonPressKind.row.resolved(for: .init(width: 300, height: 44)), .row)
    }

    func testBasePrimaryKeepsItsDisabledFaceWithoutChangingItsHeight() throws {
        let enabled = try rgba(Button("Save") {}.buttonStyle(BeckonPrimaryButtonStyle()).frame(width: 240))
        let disabled = try rgba(Button("Save") {}.buttonStyle(BeckonPrimaryButtonStyle()).disabled(true).frame(width: 240))
        XCTAssertEqual(enabled.count, disabled.count)
        let index = (20 * 240 + 20) * 4
        for (offset, value) in [129, 208, 194].enumerated() {
            XCTAssertLessThanOrEqual(abs(Int(enabled[index + offset]) - value), 1)
        }
        for (offset, value) in [243, 238, 231].enumerated() {
            XCTAssertLessThanOrEqual(abs(Int(disabled[index + offset]) - value), 1)
        }
    }

    func testLedgePressedFacesFollowTheRoleAndKeepStaticHeight() {
        for role in [BeckonRole.customer, .groomer] {
            let traits = UITraitCollection { $0.beckonRole = role }
            let actual = UIColor(BeckonLedgeSurface.card.pressedFace).resolvedColor(with: traits)
            let expected = UIColor(DesignTokens.Colors.customerTint).resolvedColor(with: traits)
            XCTAssertEqual(actual, expected)
            for size: DynamicTypeSize in [.large, .accessibility3] {
                let host = UIHostingController(rootView: Button {} label: { Color.clear.frame(width: 150, height: 60) }
                    .buttonStyle(BeckonLedgeButtonStyle(.card)).environment(\.beckonRole, role)
                    .environment(\.dynamicTypeSize, size))
                XCTAssertEqual(host.sizeThatFits(in: .init(width: 350, height: 1000)).height, 66, accuracy: 0.5)
            }
        }
    }

    func testPlainCardTintPreservesPhotoPixelsAndTintsItsSurroundings() throws {
        let photo = UIGraphicsImageRenderer(size: .init(width: 30, height: 30)).image { context in
            UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1).setFill()
            context.fill(.init(x: 0, y: 0, width: 30, height: 30))
        }
        let data = try XCTUnwrap(photo.pngData())
        func pixels(share: CGFloat) throws -> [UInt8] {
            let content = HStack(spacing: 0) {
                Color.white.frame(width: 100, height: 100)
                BeckonModuleImage(data: data) { Color.black }.frame(width: 100, height: 100)
            }.modifier(BeckonPressSurfaceTint(share: share))
            return try rgba(content)
        }
        let rest = try pixels(share: 0), pressed = try pixels(share: 1)
        let photoPoint = (50 * 200 + 150) * 4
        let cardPoint = (50 * 200 + 50) * 4
        XCTAssertEqual(Array(rest[photoPoint..<photoPoint + 4]), Array(pressed[photoPoint..<photoPoint + 4]))
        XCTAssertNotEqual(Array(rest[cardPoint..<cardPoint + 3]), Array(pressed[cardPoint..<cardPoint + 3]))
        XCTAssertEqual(Array(rest[0..<4]), Array(pressed[0..<4]), "The tint must not flash square card corners")
    }

    func testReduceMotionDoesNotMoveRenderedPlainControls() throws {
        guard UIAccessibility.isReduceMotionEnabled else { throw XCTSkip("Requires Simulator Reduce Motion") }
        for kind: BeckonPressKind in [.surface, .compact, .inline, .row] {
            func inkBounds(_ amount: CGFloat) throws -> CGRect {
                // ImageRenderer has no window to supply the system accessibility environment.
                let pixels = try hostedRGBA(Color.black.frame(width: 180, height: 60)
                    .modifier(BeckonPlainPressLook(kind: kind, amount: amount, size: .init(width: 180, height: 60)))
                    .padding(20).background(Color.white))
                var xMin = 220, xMax = -1, yMin = 100, yMax = -1
                for y in 0..<100 {
                    for x in 0..<220 {
                        let index = (y * 220 + x) * 4
                        if pixels[index] < 200 && pixels[index + 1] < 200 && pixels[index + 2] < 200 {
                            xMin = min(xMin, x); xMax = max(xMax, x)
                            yMin = min(yMin, y); yMax = max(yMax, y)
                        }
                    }
                }
                return .init(x: xMin, y: yMin, width: xMax - xMin + 1, height: yMax - yMin + 1)
            }
            XCTAssertEqual(try inkBounds(0), .init(x: 20, y: 20, width: 180, height: 60))
            XCTAssertEqual(try inkBounds(1), try inkBounds(0), "\(kind)")
        }
    }

    func testPlainCardTintAlsoPreservesTheBrandMascot() throws {
        func pixels(_ share: CGFloat) throws -> [UInt8] {
            try rgba(HStack(spacing: 0) {
                Color.white.frame(width: 80, height: 92)
                BeckonPup(time: 0, excited: false)
            }.modifier(BeckonPressSurfaceTint(share: share)))
        }
        let rest = try pixels(0), pressed = try pixels(1)
        var changed = 0
        for y in 0..<92 {
            for x in 80..<200 {
                let index = (y * 200 + x) * 4
                if rest[index..<index + 4] != pressed[index..<index + 4] { changed += 1 }
            }
        }
        XCTAssertEqual(changed, 0)
    }

    private func hostedRGBA<V: View>(_ view: V) throws -> [UInt8] {
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        let scene = try XCTUnwrap(previous?.windowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 220, height: 100)
        window.rootViewController = UIHostingController(rootView: view.ignoresSafeArea())
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        let hostedView = try XCTUnwrap(window.rootViewController?.view)
        hostedView.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            hostedView.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return try bytes(XCTUnwrap(image.cgImage))
    }

    private func rgba<V: View>(_ view: V) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view.environment(\.beckonRole, .customer))
        renderer.scale = 1
        return try bytes(XCTUnwrap(renderer.cgImage))
    }

    private func bytes(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: .init(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }
}
