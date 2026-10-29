import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class AuthenticationBrandRenderingTests: XCTestCase {
    func testAdoptedOrbUsesAnOpaqueMintLipBelowItsFace() throws {
        let image = try XCTUnwrap(ImageRenderer(content:
            BeckonBrandBubble(isMotionEnabled: false).padding(40).background(Color.white)).cgImage)
        let pixels = try rgba(image)
        // Handoff 2 uses a 176pt orb and an 8pt opaque lip, replacing the earlier blurred shadow.
        let center = image.width / 2
        let lip = (220 * image.width + center) * 4
        let expected = UIColor(DesignTokens.Colors.customerFillPressed)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        for (channel, component) in [red, green, blue].enumerated() {
            XCTAssertEqual(Double(pixels[lip + channel]), Double(component * 255), accuracy: 2)
        }
        // No control outline around the sides of the decorative orb.
        let edge = (128 * image.width + 42) * 4
        XCTAssertGreaterThan(pixels[edge + 1], 170)
    }

    func testBubbleFloatsThenStopsAndResumesWithoutRemounting() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let host = UIHostingController(rootView: BeckonBrandBubble(isMotionEnabled: true))
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        func frames() async throws -> [Data] {
            var result: [Data] = []
            for _ in 0..<3 {
                try await Task.sleep(for: .milliseconds(1_100))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                // Exclude the satellites so they cannot mask a stationary main bubble.
                let region = CGRect(x: (window.bounds.midX - 70) * image.scale,
                    y: (window.bounds.midY - 88) * image.scale,
                    width: 140 * image.scale, height: 156 * image.scale)
                let crop = try XCTUnwrap(image.cgImage?.cropping(to: region))
                result.append(try XCTUnwrap(crop.dataProvider?.data) as Data)
            }
            return result
        }
        let moving = try await frames()
        XCTAssertGreaterThan(Set(moving).count, 1, "Brand artwork is not floating")
        // The owning screen gates motion for Reduce Motion and inactive scenes.
        host.rootView = BeckonBrandBubble(isMotionEnabled: false)
        let still = try await frames()
        XCTAssertEqual(Set(still).count, 1, "Disabled motion must stay completely still")
        host.rootView = BeckonBrandBubble(isMotionEnabled: true)
        let resumed = try await frames()
        XCTAssertGreaterThan(Set(resumed).count, 1, "Motion did not resume when re-enabled")
    }

    func testEntranceStartsHiddenAndRevealsTheAdoptedArtwork() throws {
        func render(entered: Bool) throws -> CGImage {
            try XCTUnwrap(ImageRenderer(content: BeckonBrandBubble(isMotionEnabled: false, hasEntered: entered)
                .padding(40).background(Color.white)).cgImage)
        }
        let hidden = try render(entered: false)
        let visible = try render(entered: true)
        let before = try rgba(hidden), after = try rgba(visible)
        // Sample the main disc, excluding satellites; changing the entrance state must reveal real artwork.
        var changed = 0
        for y in 50..<205 {
            for x in 50..<205 {
                let i = (y * visible.width + x) * 4
                if before[i..<i+3] != after[i..<i+3] { changed += 1 }
            }
        }
        XCTAssertGreaterThan(changed, 15_000)
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }
}
