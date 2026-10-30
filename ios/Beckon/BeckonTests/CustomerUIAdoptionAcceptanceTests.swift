import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerUIAdoptionAcceptanceTests: XCTestCase {
    func testLaunchArtworkRendersFromSharedBrand() throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let lockup = ImageRenderer(content: BeckonLockup().padding(.vertical, 64).frame(width: 345)
            .environment(\.scenePhase, .inactive).environment(\.dynamicTypeSize, .large))
        lockup.scale = 3
        let image = try XCTUnwrap(lockup.uiImage)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("LaunchLockup.png"))
        let wash = ImageRenderer(content: VStack(spacing: 0) {
            LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
                startPoint: .top, endPoint: .bottom).frame(height: 800)
            DesignTokens.Colors.appBackground.frame(height: 200)
        }.frame(width: 8, height: 1000))
        try XCTUnwrap(wash.uiImage?.pngData()).write(to: directory.appendingPathComponent("LaunchWash.png"))
        print("T422 launch artwork: \(image.size.width) × \(image.size.height) pt, 3x; \(directory.path)")
    }

    func testDeclaredScreenStatesRenderAtDefaultAndAccessibilitySizes() async throws {
        let (window, previous) = try testWindow()
        defer { window.rootViewController = previous; window.makeKeyAndVisible() }
        var rendered = 0
        for size: DynamicTypeSize in [.large, .accessibility3] {
            for screen in CustomerSandboxScreen.allCases {
                for state in screen.states {
                    let measuresArrival = size == .large && state == .loaded && [.wizardReview, .groomerPicker].contains(screen)
                    let pulse = measuresArrival ? Task { @MainActor in
                        var longest = 0.0
                        while !Task.isCancelled {
                            let start = ProcessInfo.processInfo.systemUptime
                            try? await Task.sleep(for: .milliseconds(16))
                            longest = max(longest, ProcessInfo.processInfo.systemUptime - start)
                        }
                        return longest
                    } : nil
                    if pulse != nil { await Task.yield() }
                    let host = UIHostingController(rootView:
                        CustomerSandboxScreenHost(screen: screen, state: state)
                            .environment(\.scenePhase, .active).environment(\.dynamicTypeSize, size))
                    host.view.accessibilityViewIsModal = true
                    window.rootViewController = host
                    window.makeKeyAndVisible()
                    try await Task.sleep(for: .milliseconds(650))
                    host.view.layoutIfNeeded()
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 0.25
                    var didRender = false
                    _ = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                        didRender = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    XCTAssertTrue(didRender, "\(screen.rawValue)/\(state.rawValue)/\(size)")
                    rendered += 1
                    if let pulse {
                        pulse.cancel()
                        print("T420 \(screen.rawValue) first-650ms longest main-actor scheduling interval: \(await pulse.value) seconds (Debug Simulator, includes rendering).")
                    }
                    // Dismiss presentations and cancel this fixture's work before the next state.
                    window.rootViewController = nil
                    await Task.yield()
                }
            }
        }
        print("T420 rendered \(rendered) declared screen/state/size combinations; rendering smoke, not visual-equivalence proof.")
    }

    // Reuses the same real-view host and local repositories for semantic Simulator taps.
    // A marker changes only the host's screen/fixture/size, never a product action.
    func testLocalCustomerJourney() async throws {
        let marker = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("t420-ui-adoption.json")
        let environment = ProcessInfo.processInfo.environment
        if environment["BECKON_UI_ADOPTION"] == "1" || environment["TEST_RUNNER_BECKON_UI_ADOPTION"] == "1" {
            try JSONEncoder().encode(Configuration()).write(to: marker)
        }
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw XCTSkip("Opt-in local customer UI acceptance not configured")
        }
        defer { try? FileManager.default.removeItem(at: marker) }
        XCTAssertTrue(AppLaunchConfiguration().usesSignedOutAuthSessionRepository, "Launch local acceptance with --beckon-ui-test-signed-out-auth to isolate authentication")
        guard AppLaunchConfiguration().usesSignedOutAuthSessionRepository else { return }
        let probe = Probe(configuration: try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: marker)))
        let (window, previous) = try testWindow()
        let host = UIHostingController(rootView: InteractionHost(probe: probe))
        host.view.accessibilityViewIsModal = true
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.rootViewController = previous; window.makeKeyAndVisible() }
        for _ in 0..<2400 where !probe.finished {
            try await Task.sleep(for: .milliseconds(500))
            if let data = try? Data(contentsOf: marker),
               let updated = try? JSONDecoder().decode(Configuration.self, from: data), updated != probe.configuration {
                probe.configuration = updated
            }
        }
        XCTAssertTrue(probe.finished, "Finish the local UI acceptance before timeout")
    }

    private func testWindow() throws -> (UIWindow, UIViewController?) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first)
        let previous = window.rootViewController
        window.overrideUserInterfaceStyle = .light
        return (window, previous)
    }

    struct Configuration: Codable, Equatable, Hashable {
        var screen = "tabs"
        var state = "loaded"
        var largeText = false
    }

    @Observable final class Probe {
        var configuration: Configuration
        var finished = false
        init(configuration: Configuration) { self.configuration = configuration }
    }

    struct InteractionHost: View {
        let probe: Probe
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var phase: ScenePhase = .active
        var body: some View {
            VStack(spacing: 0) {
                Button("Finish local acceptance") { probe.finished = true }
                    .accessibilityIdentifier("adoption.finish")
                    .accessibilityValue(reduceMotion ? "reduced motion" : "normal motion")
                    .font(.caption).dynamicTypeSize(.large).frame(height: 32)
                CustomerSandboxScreenHost(screen: CustomerSandboxScreen(rawValue: probe.configuration.screen) ?? .tabs,
                    state: CustomerSandboxState(rawValue: probe.configuration.state) ?? .loaded)
                    .environment(\.scenePhase, phase)
                    .environment(\.dynamicTypeSize, probe.configuration.largeText ? .accessibility3 : .large)
                    .id(probe.configuration)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in phase = .background }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in phase = .active }
        }
    }
}
