import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class ChatComposerAppearanceTests: XCTestCase {
    func testReadyButtonIsCircularAndItsFaceCentersOnSingleAndMultilineInput() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 360, height: 320)
        window.overrideUserInterfaceStyle = .light
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for text in ["Hello", String(repeating: "Please use the side entrance. ", count: 12)] {
            let host = UIHostingController(rootView: Composer(text: text)
                .frame(width: 360).frame(maxHeight: .infinity, alignment: .top).background(Color.white))
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(40))
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let image = try XCTUnwrap(rendered.cgImage)
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            func rgb(_ color: Color) -> [Int] {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
                return [r, g, b].map { Int(($0 * 255).rounded()) }
            }
            func matches(_ x: Int, _ y: Int, _ color: [Int]) -> Bool {
                let base = (y * image.width + x) * 4
                return (0..<3).allSatisfy { abs(Int(bytes[base + $0]) - color[$0]) <= 1 }
            }
            func bounds(_ color: [Int], xRange: Range<Int>) throws -> CGRect {
                var xs: [Int] = [], ys: [Int] = []
                for y in 0..<image.height {
                    for x in xRange where matches(x, y, color) { xs.append(x); ys.append(y) }
                }
                return CGRect(x: try XCTUnwrap(xs.min()), y: try XCTUnwrap(ys.min()),
                    width: try XCTUnwrap(xs.max()) - (xs.min() ?? 0) + 1,
                    height: try XCTUnwrap(ys.max()) - (ys.min() ?? 0) + 1)
            }
            let faceColor = rgb(DesignTokens.Colors.customerFill)
            let field = try bounds(rgb(DesignTokens.Colors.iconTileFill), xRange: 25..<270)
            let face = try bounds(faceColor, xRange: 280..<350)
            // Exact-color masks exclude antialiased edge pixels; allow the 1x raster fringe.
            XCTAssertEqual(face.width, face.height, accuracy: 2)
            XCTAssertEqual(face.midY, field.midY, accuracy: 1, "Align visible face, excluding the lower ledge")
            XCTAssertFalse(matches(Int(face.minX) + 12, Int(face.minY) + 3, faceColor),
                "The active face must retain circular corners")
        }
    }

    private struct Composer: View {
        let text: String
        @FocusState private var focused: Bool
        var body: some View {
            ChatComposerBar(draft: .constant(text), isFocused: $focused, isSending: false,
                isReadOnly: false, readOnlyMessage: "", accent: .customer, placeholder: "Message…", send: {})
        }
    }
}
