import Foundation
import Testing
@testable import Beckon

struct ForegroundRefreshGateTests {
    @Test @MainActor func periodicAndDeadlineReadsShareTheGateWithoutReloadingMedia() async {
        let gate = ForegroundRefreshGate()
        var full = 0, light = 0
        for (reason, time): (ForegroundRefreshReason, TimeInterval) in [
            (.initialLoad, 100), (.realtimeFallback, 144), (.realtimeFallback, 145),
            (.deadlineReached, 146), (.sceneBecameActive, 152)
        ] {
            await gate.refresh(reason: reason, now: Date(timeIntervalSince1970: time),
                fallbackOperation: { light += 1 }) { full += 1 }
        }
        #expect(full == 2)
        #expect(light == 2)
    }

    @Test @MainActor func deadlineDoesNotWaitForTheFallbackOrForegroundThrottle() async {
        let gate = ForegroundRefreshGate()
        var count = 0
        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) { count += 1 }
        await gate.refresh(reason: .deadlineReached, now: Date(timeIntervalSince1970: 101)) { count += 1 }
        #expect(count == 2)
        await gate.refresh(reason: .realtimeFallback, now: Date(timeIntervalSince1970: 102)) { count += 1 }
        #expect(count == 2)
    }
    @Test @MainActor
    func initialRefreshRunsAndRecordsTimestamp() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        let now = Date(timeIntervalSince1970: 100)
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: now) {
            refreshCount += 1
        }

        #expect(refreshCount == 1)
        #expect(gate.lastRefreshAt == now)
    }

    @Test @MainActor
    func foregroundRefreshIsSuppressedWhenRecent() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .sceneBecameActive, now: Date(timeIntervalSince1970: 103)) {
            refreshCount += 1
        }

        #expect(refreshCount == 1)
        #expect(gate.lastSuppressedReason == .sceneBecameActive)
    }

    @Test @MainActor
    func foregroundRefreshRunsAfterMinimumInterval() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .sceneBecameActive, now: Date(timeIntervalSince1970: 106)) {
            refreshCount += 1
        }

        #expect(refreshCount == 2)
        #expect(gate.lastRefreshAt == Date(timeIntervalSince1970: 106))
    }

    @Test @MainActor
    func realtimeFallbackUsesLongerInterval() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .realtimeFallback, now: Date(timeIntervalSince1970: 120)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .realtimeFallback, now: Date(timeIntervalSince1970: 131)) {
            refreshCount += 1
        }

        #expect(refreshCount == 2)
        #expect(gate.lastRefreshAt == Date(timeIntervalSince1970: 131))
    }

    @Test @MainActor
    func concurrentRefreshesAreDeduplicated() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 0,
            realtimeFallbackInterval: 0
        )
        let probe = ForegroundRefreshProbe()

        let first = Task { @MainActor in
            await gate.refresh(
                reason: .sceneBecameActive,
                now: Date(timeIntervalSince1970: 100)
            ) {
                probe.increment()
                await probe.holdUntilReleased()
            }
        }

        await probe.waitUntilHolding()

        await gate.refresh(
            reason: .realtimeFallback,
            now: Date(timeIntervalSince1970: 101)
        ) {
            probe.increment()
        }
        probe.release()
        await first.value

        #expect(probe.refreshCount == 1)
        #expect(gate.lastSuppressedReason == .realtimeFallback)
    }
}

@MainActor
private final class ForegroundRefreshProbe {
    private(set) var refreshCount = 0
    private(set) var isHolding = false
    private var holdingContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func increment() {
        refreshCount += 1
    }

    func waitUntilHolding() async {
        guard !isHolding else { return }
        await withCheckedContinuation { continuation in
            holdingContinuation = continuation
        }
    }

    func holdUntilReleased() async {
        isHolding = true
        holdingContinuation?.resume()
        holdingContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        isHolding = false
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
