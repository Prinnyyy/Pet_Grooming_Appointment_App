import SwiftUI
import Testing
@testable import Beckon

@MainActor
struct CustomerUIFoundationTests {
    @Test func journeyDirectionRespectsReadingDirection() {
        #expect(BeckonEntranceTravel.forward.start(distance: 36, layoutDirection: .leftToRight).width == 36)
        #expect(BeckonEntranceTravel.back.start(distance: 36, layoutDirection: .leftToRight).width == -36)
        #expect(BeckonEntranceTravel.forward.start(distance: 36, layoutDirection: .rightToLeft).width == -36)
        #expect(BeckonEntranceTravel.rise.start(distance: 30, layoutDirection: .rightToLeft) == CGSize(width: 0, height: 30))
    }

    @Test func aNestedCarouselCannotActivateWhileThePageScrolls() async throws {
        let page = BeckonScrollActivity()
        let carousel = BeckonScrollActivity()
        carousel.parent = page
        let guardState = BeckonTapGuard()
        guardState.observe(.zero)
        #expect(guardState.allowsTap(activity: carousel))
        page.update(isScrolling: true)
        #expect(!guardState.allowsTap(activity: carousel))
        page.update(isScrolling: false)
        #expect(!guardState.allowsTap(activity: carousel))
        try await Task.sleep(for: .milliseconds(400))
        #expect(guardState.allowsTap(activity: carousel))
    }

    @Test func layoutMovementRejectsTheScrollReleaseButNotTheNextTap() async throws {
        let guardState = BeckonTapGuard()
        guardState.observe(.zero)
        guardState.observe(CGPoint(x: 0, y: 50))
        #expect(!guardState.allowsTap(activity: nil))
        try await Task.sleep(for: .milliseconds(400))
        #expect(guardState.allowsTap(activity: nil))
    }
}
