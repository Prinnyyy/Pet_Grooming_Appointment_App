import Testing
@testable import Beckon

struct BeckonBadgeLabelTests {
    @Test func countBoundaries() {
        #expect(BeckonBadgeLabel.text(for: -1) == nil)
        #expect(BeckonBadgeLabel.text(for: 0) == nil)
        #expect(BeckonBadgeLabel.text(for: 1) == "1")
        #expect(BeckonBadgeLabel.text(for: 99) == "99")
        #expect(BeckonBadgeLabel.text(for: 100) == "99+")
        #expect(BeckonBadgeLabel.text(for: Int.max) == "99+")
    }
}
