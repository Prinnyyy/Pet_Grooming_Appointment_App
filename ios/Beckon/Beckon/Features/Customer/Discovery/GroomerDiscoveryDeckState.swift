import Foundation
import CoreGraphics

enum GroomerDiscoveryDeckSelection: Equatable, Hashable {
    case groomer(UUID)
    case more
}

enum GroomerDiscoveryDeckDirection: Equatable { case previous, next }

enum GroomerDiscoveryDeckPolicy {
    static func destination(from selection: GroomerDiscoveryDeckSelection,
                            direction: GroomerDiscoveryDeckDirection,
                            groomerIDs: [UUID]) -> GroomerDiscoveryDeckSelection {
        guard let first = groomerIDs.first, let last = groomerIDs.last else { return selection }
        switch selection {
        case .more:
            return direction == .previous ? .groomer(last) : .more
        case .groomer(let id):
            guard let index = groomerIDs.firstIndex(of: id) else { return .groomer(first) }
            switch direction {
            case .previous: return .groomer(groomerIDs[max(0, index - 1)])
            case .next: return index + 1 < groomerIDs.count ? .groomer(groomerIDs[index + 1]) : .more
            }
        }
    }

    static func committedDirection(translation: CGSize, predictedEnd: CGSize,
                                   cardWidth: CGFloat) -> GroomerDiscoveryDeckDirection? {
        let x = translation.width
        guard cardWidth.isFinite, cardWidth > 0, x.isFinite, translation.height.isFinite,
              abs(x) >= 12, abs(x) > abs(translation.height) * 1.25 else { return nil }
        let predictedCommits = predictedEnd.width.isFinite
            && x * predictedEnd.width > 0 && abs(predictedEnd.width) >= cardWidth * 0.35
        guard abs(x) >= cardWidth * 0.22 || predictedCommits else { return nil }
        return x < 0 ? .next : .previous
    }
}

struct GroomerDiscoveryDeckTransition {
    private var token: UUID?
    private var source: GroomerDiscoveryDeckSelection?
    private var target: GroomerDiscoveryDeckSelection?
    var isActive: Bool { token != nil }

    mutating func begin(from: GroomerDiscoveryDeckSelection, to: GroomerDiscoveryDeckSelection) -> UUID {
        let value = UUID()
        token = value
        source = from
        target = to
        return value
    }

    mutating func cancel() { token = nil; source = nil; target = nil }

    mutating func complete(token: UUID, current: GroomerDiscoveryDeckSelection?) -> GroomerDiscoveryDeckSelection? {
        guard self.token == token else { return nil }
        defer { cancel() }
        return current == source ? target : nil
    }
}
