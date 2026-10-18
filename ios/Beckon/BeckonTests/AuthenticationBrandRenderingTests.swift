import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class AuthenticationBrandRenderingTests: XCTestCase {
    func testShadowSeparatesTheIconLayerFromItsBackground() throws {
        let image = try XCTUnwrap(ImageRenderer(content:
            BeckonBrandBubble(isMotionEnabled: false).padding(40).background(Color.white)).cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        // Sample just outside both sides of the 156pt icon, not the space below it.
        for x in [33, 203] {
            let i = (118 * image.width + x) * 4
            XCTAssertLessThan(pixels[i], 249, "A detached ground ellipse does not lift the icon layer")
            XCTAssertLessThan(abs(Int(pixels[i]) - Int(pixels[i + 1])), 8, "Shadow should be neutral, not a colored outline")
        }
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

    func testLandingEntranceRevealsMintBodyWithoutAControlOutline() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView:
            AuthenticationView(store: AuthenticationStore(repository: AuthSessionRepositoryFake())))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        try await Task.sleep(for: .milliseconds(50))
        let early = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let earlyBody = try artworkPixels(early).body
        try await Task.sleep(for: .seconds(2))
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "auth-brand-material"
        attachment.lifetime = .keepAlways
        add(attachment)

        let settled = try artworkPixels(image)
        XCTAssertLessThan(earlyBody, settled.body / 2, "The one-time entrance was removed; artwork appeared instantly")
        XCTAssertGreaterThan(settled.body, 1_200, "Brand body was washed out into a selected-control Tint")
        XCTAssertLessThan(settled.outline, 20, "The decorative brand bubble has a dark control outline")
    }

    private func artworkPixels(_ image: UIImage) throws -> (body: Int, outline: Int) {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var mintBodyPixels = 0
        var darkTealOutlinePixels = 0
        // Exclude the action area: only the illustration above the wordmark is under test.
        for y in 100..<Int(Double(height) * 0.55) {
            for x in (width / 2 - 85)..<(width / 2 + 85) {
                let i = (y * width + x) * 4
                let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
                if abs(r - 129) < 18 && abs(g - 208) < 18 && abs(b - 194) < 18 { mintBodyPixels += 1 }
                if r < 80 && g > r + 45 && b > r + 30 && g < 160 { darkTealOutlinePixels += 1 }
            }
        }
        return (mintBodyPixels, darkTealOutlinePixels)
    }
}
