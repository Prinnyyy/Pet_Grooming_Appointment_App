import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class LaunchLoadingIsolationTests: XCTestCase {
    func testConstructingTheLaunchGateDoesNotConstructThePageUnderItsIntro() {
        var pageConstructions = 0
        let gate = LaunchGate(isReady: false) {
            pageConstructions += 1
            return Color.clear
        }
        _ = gate
        XCTAssertEqual(pageConstructions, 0, "Page construction must wait until the opening animation finishes")
    }

    func testIntroRequiresBothThePupReactionAndTheWordsInEitherOrder() {
        var wordsFirst = LaunchIntroCompletionState()
        wordsFirst.wordsFinished = true
        XCTAssertFalse(wordsFirst.isFinished)
        wordsFirst.arrivalFinished = true
        XCTAssertTrue(wordsFirst.isFinished)
        var pupFirst = LaunchIntroCompletionState()
        pupFirst.arrivalFinished = true
        XCTAssertFalse(pupFirst.isFinished)
        pupFirst.wordsFinished = true
        XCTAssertTrue(pupFirst.isFinished)
    }

    func testReadyDataCannotDismissAnUnfinishedIntroOrRestartAFinishedLaunch() {
        var state = LaunchPresentationState()
        state.minimumElapsed = true
        state.update(isReady: true)
        XCTAssertFalse(state.hasDismissed)
        state.introFinished = true
        state.update(isReady: false)
        XCTAssertFalse(state.hasDismissed)
        state.update(isReady: true)
        XCTAssertTrue(state.hasDismissed)
        state.update(isReady: false)
        XCTAssertTrue(state.hasDismissed)
    }

    func testPageMountsOnlyAfterTheLiveIntroFinishes() async throws {
        try await checkMount()
    }

    private func checkMount() async throws {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        var mounted = false
        let host = UIHostingController(rootView: LaunchGate(isReady: true) {
            Color.white.onAppear { mounted = true }
        }.environment(\.scenePhase, .active))
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        let started = Date()
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        if !reduceMotion {
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertFalse(mounted, "Loading began while the landing reaction was still playing")
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(6))
        while !mounted, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(mounted, "Intro completion must release the page, including Reduce Motion")
        if !reduceMotion { XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 1.2) }
    }
}
