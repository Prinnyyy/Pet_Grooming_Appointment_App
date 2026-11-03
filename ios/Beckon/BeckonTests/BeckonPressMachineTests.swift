import Testing
@testable import Beckon

struct BeckonPressMachineTests {
    @Test(arguments: PressScenario.cases)
    func acceptedTapsAndCancelledTouchesHaveDistinctEffects(_ scenario: PressScenario) {
        var machine = BeckonPressMachine()
        let effects = scenario.events.flatMap { machine.send($0) }
        #expect(effects.filter { $0 == .haptic }.count == scenario.buzzes, "\(scenario.name)")
        #expect(effects.filter { $0 == .startPulseTimer }.count == scenario.pulses, "\(scenario.name)")
        #expect(machine.level == .rest, "\(scenario.name)")
        #expect(!machine.isHeld && !machine.isPulsing, "\(scenario.name)")
    }

    @Test func touchAcknowledgesBeforeSettlingAndResetCancelsTimers() {
        var machine = BeckonPressMachine()
        #expect(machine.send(.down) == [.move(.touched, .acknowledge), .startSettleTimer])
        #expect(machine.level == .touched)
        #expect(machine.send(.up) == [.cancelSettleTimer, .move(.rest, .cancel)])
        #expect(machine.send(.settled).isEmpty)
        _ = machine.send(.tap)
        let reset = machine.send(.reset)
        #expect(reset.contains(.cancelSettleTimer) && reset.contains(.cancelPulseTimer))
        #expect(machine.send(.pulseEnded).isEmpty)
        #expect(machine == BeckonPressMachine())
    }
}

nonisolated struct PressScenario: Sendable {
    let name: String
    let events: [BeckonPressMachine.Event]
    let buzzes: Int
    let pulses: Int

    static let cases: [Self] = [
        .init(name: "lift before tap", events: [.down, .up, .tap, .pulseEnded], buzzes: 1, pulses: 1),
        .init(name: "tap before lift", events: [.down, .tap, .up, .pulseEnded], buzzes: 1, pulses: 1),
        .init(name: "held press", events: [.down, .settled, .up, .tap], buzzes: 1, pulses: 0),
        .init(name: "held press tap before lift", events: [.down, .settled, .tap, .up], buzzes: 1, pulses: 0),
        .init(name: "scroll takes touch", events: [.down, .up], buzzes: 0, pulses: 0),
        .init(name: "accessibility activation", events: [.tap, .pulseEnded], buzzes: 1, pulses: 1),
        .init(name: "two sequential taps", events: [.down, .up, .tap, .pulseEnded, .down, .up, .tap, .pulseEnded], buzzes: 2, pulses: 2),
        .init(name: "leave mid press", events: [.down, .settled, .reset], buzzes: 1, pulses: 0),
        .init(name: "settle arrives during pulse", events: [.down, .tap, .settled, .up, .pulseEnded], buzzes: 1, pulses: 1),
        .init(name: "accepted taps overlap pulse", events: [.down, .up, .tap, .down, .up, .tap, .pulseEnded], buzzes: 2, pulses: 2),
        .init(name: "held touch starts during previous pulse", events: [.down, .up, .tap, .down, .pulseEnded, .settled, .up, .tap], buzzes: 2, pulses: 1),
    ]
}
