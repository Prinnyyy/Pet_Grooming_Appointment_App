// The logic of a press, apart from any view. A button used to show nothing until its touch had stayed down for 80 ms, so a
// tap, which lifts after 50 to 120 ms, often showed nothing at all and the page simply changed. This is the rule that replaces it:
//
//   touch down      the button answers at once, quietly (`touched`: a share of the full press, no travel to speak of, no buzz), so a
//                   finger that lands to scroll is hardly seen to have touched anything;
//   still down      after the settle time the full press (`pressed`): the face sinks, the buzz comes;
//   a tap fires     if the full press never showed (the finger lifted too soon), it is played now as a pulse: the full press for a
//                   short hold, then the release. Every tap that opens something is seen, however quick;
//   lifted          the release springs back; a touch that turned into a scroll fades back to rest without any bounce.
//
// The machine knows nothing about SwiftUI: events go in (`down`, `up`, `settled`, `tap`, `pulseEnded`, `reset`), effects come out (move to
// a level at a pace, start or cancel a timer, buzz). `BeckonPressEngine` runs the timers and the animations; the checks in the
// pure event tests run the machine alone.
import Foundation


nonisolated struct BeckonPressMachine: Equatable {
    /// How far the press has gone. `touched` is the first answer, `pressed` the full one.
    enum Level: Hashable {
        case rest, touched, pressed
    }

    /// The speed of a move, because the same level is reached in different ways: a touch landing, the full press settling, a tap's
    /// pulse, a release that bounces, and a cancel that does not.
    enum Pace: Equatable {
        case acknowledge, press, pulseDown, release, cancel
    }

    enum Event: Equatable {
        /// The touch landed on the button (`isPressed` became true).
        case down
        /// The touch lifted or was taken away by a scroll (`isPressed` became false).
        case up
        /// The settle timer ran out while the touch was still down.
        case settled
        /// The button's action fired: a tap that the scroll guard accepted.
        case tap
        /// The pulse's hold ran out.
        case pulseEnded
        /// The button left the screen, or was disabled.
        case reset
    }

    enum Effect: Equatable {
        case move(Level, Pace)
        case startSettleTimer, cancelSettleTimer
        case startPulseTimer, cancelPulseTimer
        case haptic
    }

    private(set) var level = Level.rest
    private(set) var isHeld = false
    /// The full press has been shown in this touch by settling: the buzz has been given and a tap needs no pulse.
    private(set) var reachedPressed = false
    private(set) var isPulsing = false
    private var activatedThisTouch = false

    mutating func send(_ event: Event) -> [Effect] {
        switch event {
        case .down:
            isHeld = true
            reachedPressed = false
            activatedThisTouch = false
            // A second touch while the first tap's pulse is still holding: the pulse keeps the face down and this touch settles on its own.
            if isPulsing { return [.startSettleTimer] }
            level = .touched
            return [.move(.touched, .acknowledge), .startSettleTimer]

        case .settled:
            guard isHeld, !reachedPressed, !activatedThisTouch else { return [] }
            level = .pressed
            reachedPressed = true
            return [.move(.pressed, .press), .haptic]

        case .up:
            guard isHeld else { return [] }
            isHeld = false
            if isPulsing { return [.cancelSettleTimer] }
            switch level {
            case .pressed:
                level = .rest
                return [.cancelSettleTimer, .move(.rest, .release)]
            case .touched:
                level = .rest
                return [.cancelSettleTimer, .move(.rest, .cancel)]
            case .rest:
                return [.cancelSettleTimer]
            }

        case .tap:
            // Whether the full press was shown in this touch is used up here. The lift (`up`) and the tap arrive in one update, `up`
            // first; the flag stays set between them, and a tap that comes from somewhere else (VoiceOver) finds it clear.
            let shown = reachedPressed
            reachedPressed = false
            activatedThisTouch = true
            // The press was shown: the lift releases it, there is nothing to add.
            guard !shown else { return [] }
            isPulsing = true
            level = .pressed
            return [.cancelSettleTimer, .move(.pressed, .pulseDown), .haptic, .startPulseTimer]

        case .pulseEnded:
            guard isPulsing else { return [] }
            isPulsing = false
            guard !isHeld else { return [] }
            level = .rest
            return [.move(.rest, .release)]

        case .reset:
            let wasMoved = level != .rest
            self = BeckonPressMachine()
            return [.cancelSettleTimer, .cancelPulseTimer] + (wasMoved ? [.move(.rest, .cancel)] : [])
        }
    }
}
