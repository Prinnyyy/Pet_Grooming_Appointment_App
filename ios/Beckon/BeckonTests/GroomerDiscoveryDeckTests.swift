import CoreGraphics
import Foundation
import Testing
@testable import Beckon

@MainActor
struct GroomerDiscoveryDeckTests {
    @Test(arguments: [1, 3, 8])
    func browsingIsReversibleAndBounded(_ count: Int) {
        let ids = (0..<count).map { _ in UUID() }
        var selection = GroomerDiscoveryDeckSelection.groomer(ids[0])
        #expect(GroomerDiscoveryDeckPolicy.destination(from: selection, direction: .previous, groomerIDs: ids) == selection)
        for index in 1..<count {
            selection = GroomerDiscoveryDeckPolicy.destination(from: selection, direction: .next, groomerIDs: ids)
            #expect(selection == .groomer(ids[index]))
        }
        selection = GroomerDiscoveryDeckPolicy.destination(from: selection, direction: .next, groomerIDs: ids)
        #expect(selection == .more)
        #expect(GroomerDiscoveryDeckPolicy.destination(from: selection, direction: .next, groomerIDs: ids) == .more)
        for id in ids.reversed() {
            selection = GroomerDiscoveryDeckPolicy.destination(from: selection, direction: .previous, groomerIDs: ids)
            #expect(selection == .groomer(id))
        }
    }

    @Test func gestureRequiresHorizontalIntentAndSufficientTravel() {
        func direction(_ x: CGFloat, _ y: CGFloat, _ predicted: CGFloat) -> GroomerDiscoveryDeckDirection? {
            GroomerDiscoveryDeckPolicy.committedDirection(translation: .init(width: x, height: y),
                predictedEnd: .init(width: predicted, height: y), cardWidth: 320)
        }
        #expect(direction(8, 100, 200) == nil)
        #expect(direction(3, 0, 200) == nil)
        #expect(direction(40, 0, 45) == nil)
        #expect(direction(-75, 8, -80) == .next)
        #expect(direction(75, 8, 80) == .previous)
        #expect(direction(-20, 2, -120) == .next)
        #expect(direction(-20, 2, 120) == nil)
        #expect(direction(80, 100, 180) == nil)
        #expect(GroomerDiscoveryDeckPolicy.committedDirection(translation: .init(width: 100, height: 0),
            predictedEnd: .zero, cardWidth: 0) == nil)
    }

    @Test func staleTransitionCannotCommitAfterCancellationOrReplacement() {
        let first = GroomerDiscoveryDeckSelection.groomer(UUID())
        let second = GroomerDiscoveryDeckSelection.groomer(UUID())
        var transition = GroomerDiscoveryDeckTransition()
        let old = transition.begin(from: first, to: second)
        transition.cancel()
        #expect(transition.complete(token: old, current: first) == nil)
        let current = transition.begin(from: first, to: second)
        #expect(transition.complete(token: old, current: first) == nil)
        #expect(transition.complete(token: current, current: .more) == nil)
        let valid = transition.begin(from: first, to: second)
        #expect(transition.complete(token: valid, current: first) == second)
        #expect(transition.complete(token: valid, current: first) == nil)
    }
}
